--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Theater class.
--]]

require("os")
require("io")
require("lfs")
local class       = require("libs.class")
local utils       = require("libs.utils")
local containers  = require("libs.containers")
local json        = require("libs.json")
local enum        = require("dct.utils.enum")
local dctutils    = require("dct.utils.utils")
local uicmds      = require("dct.ui.cmds")
local uiscratchpad= require("dct.ui.scratchpad")
local Observable  = require("dct.utils.Observable")
local STM         = require("dct.templates.STM")
local Template    = require("dct.templates.Template")
local Region      = require("dct.templates.Region")
local AssetFactory= require("dct.asset.AssetFactory")
local AssetManager= require("dct.asset.AssetManager")
local Commander   = require("dct.ai.Commander")
local Command     = require("dct.utils.Command")
local Logger      = require("dct.utils.Logger").getByName("Theater")
local Profiler    = require("dct.utils.Profiler").getProfiler()
local settings    = _G.dct.settings.server

--[[
--  Theater class
--    base class that reads in all region and template information
--    and provides a base interface for manipulating data at a theater
--    level.
--
--  Storage of theater:
--		goals = {
--			<goalname> = State(),
--		},
--		regions = {
--			<regionname> = Region(),
--		},
--]]
local Theater = class(Observable)
function Theater:__init()
	Observable.__init(self)
	Profiler:profileStart("Theater:init()")
	self.savestatefreq = 7*60 -- seconds
	self.cmdmindelay   = 2
	self.uicmddelay    = self.cmdmindelay
	self:setTimings(settings.schedfreq, settings.tgtfps,
		settings.percentTimeAllowed)
	self.complete  = false
	self.statef    = false
	self.regions   = {}
	self.cmdq      = containers.PriorityQueue()
	self.ctime     = timer.getTime()
	self.ltime     = 0
	self.assetmgr  = AssetManager(self)
	self.cmdrs     = {}
	self.scratchpad= {}
	self.startdate = os.date("*t")

	for _, val in pairs(coalition.side) do
		self.cmdrs[val] = Commander(self, val)
	end

	self:_loadGoals()
	self:_loadRegions()
	self:_loadOrGenerate()
	self:_CreateDefaultSquadrons()
	self:_loadPlayerSlots()
	uiscratchpad(self)
	self:queueCommand(100, Command(self.export, self))
	Profiler:profileStop("Theater:init()")
end

-- a description of the world state that signifies a particular side wins
-- TODO: create a common function that will read in a lua file like below
-- verify it was read correctly, contains the token expected, returns the
-- token on the stack and clears the global token space
function Theater:_loadGoals()
	local goalpath = settings.theaterpath..utils.sep.."theater.goals"
	local rc = pcall(dofile, goalpath)
	assert(rc, "failed to parse: theater goal file, '" ..
			goalpath .. "' path likely doesn't exist")
	assert(theatergoals ~= nil, "no theatergoals structure defined")

	self.goals = {}
	-- TODO: translate goal definitions written in the lua files to any
	-- needed internal state.
	-- Theater goals are goals written in a success format, meaning the
	-- first side to complete all their goals wins
	theatergoals = nil
end

function Theater:_loadRegions()
	for filename in lfs.dir(settings.theaterpath) do
		if filename ~= "." and filename ~= ".." and
			filename ~= ".git" then
			local fpath = settings.theaterpath..utils.sep..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				local r = Region(fpath)
				assert(self.regions[r.name] == nil, "duplicate regions " ..
					"defined for theater: " .. settings.theaterpath)
				self.regions[r.name] = r
			end
		end
	end
end

function Theater:setTimings(cmdfreq, tgtfps, percent)
	self._cmdqfreq    = cmdfreq
	self._targetfps   = tgtfps
	self._tallowed    = percent
	self.cmdqdelay    = 1/self._cmdqfreq
	self.quanta       = self._tallowed * ((1 / self._targetfps) *
		self.cmdqdelay)
end

local function isStateValid(state)
	if state == nil then
		Logger:info("isStateValid(); state object nil")
		return false
	end

	if state.complete == true then
		Logger:info("isStateValid(); theater goals were completed")
		return false
	end

	if state.theater ~= env.mission.theatre then
		Logger:warn(string.format("isStateValid(); wrong theater; "..
			"state: '%s'; mission: '%s'", state.theater, env.mission.theatre))
		return false
	end

	if state.sortie ~= env.getValueDictByKey(env.mission.sortie) then
		Logger:warn(string.format("isStateValid(); wrong sortie; "..
			"state: '%s'; mission: '%s'", state.sortie,
			env.getCalueDictByKey(env.mission.sortie)))
		return false
	end

	return true
end

function Theater:_initFromState()
	self.statef = true
	self.startdate = self.statetbl.startdate
	self:getAssetMgr():unmarshal(self.statetbl.assetmgr)
end

function Theater:_loadOrGenerate()
	local statefile = io.open(settings.statepath)

	if statefile ~= nil then
		self.statetbl = json:decode(statefile:read("*all"))
		statefile:close()
	end

	if isStateValid(self.statetbl) then
		Logger:info("restoring saved state")
		self:_initFromState()
	else
		Logger:info("saved state was invalid, generating new theater")
		self:generate()
	end
	self.statetbl = nil
end

local function isPlayerGroup(grp, _, _)
	local slotcnt = 0
	for _, unit in ipairs(grp.units) do
		if unit.skill == "Client" then
			slotcnt = slotcnt + 1
		end
	end
	if slotcnt > 0 then
		assert(slotcnt == 1,
			string.format("DCT requires 1 slot groups. Group '%s' "..
				" of type a/c (%s) has more than one player slot.",
				grp.name, grp.units[1].type))
		return true
	end
	return false
end

local function genAirbaseMap()
	local airbase_idx2name = {}
	for _, ab in pairs(coalition.getAirbases()) do
		airbase_idx2name[ab:getID()] = ab:getName()
	end
	return airbase_idx2name
end

local function getAirbaseId(grp)
	assert(grp, "value error: grp cannot be nil")
	local name = "airdromeId"
	if grp.category == Unit.Category.HELICOPTER then
		name = "helipadId"
	end
	return grp.data.route.points[1][name]
end

function Theater:_CreateDefaultSquadrons()
	for _, val in pairs(coalition.side) do
		local asset = Asset(Template({
				["objtype"] = "playersquadron",
				["name"] = enum.defaultsqdns[val],
				["regionname"] = "theater",
				["coalition"] = val,
			}), {["name"] = "theater", ["priority"] = 1000,})
			self:getAssetMgr():add(asset)
	end
end

function Theater:_loadPlayerSlots()
	local cnt = 0
	local idx2ab = genAirbaseMap()
	for _, coa_data in pairs(env.mission.coalition) do
		local grps = STM.processCoalition(coa_data,
			env.getValueDictByKey,
			isPlayerGroup,
			nil)
		for _, grp in ipairs(grps) do
			local asset = Asset(Template({
				["objtype"]   = "playergroup",
				["name"]      = grp.data.name,
				["regionname"]= "theater",
				["coalition"] = coalition.getCountryCoalition(grp.countryid),
				["desc"]      = "Player group",
				["tpldata"]   = grp.data,
				["airbase"]   = idx2ab[getAirbaseId(grp)]
			}), {["name"] = "theater", ["priority"] = 1000,})
			self:getAssetMgr():add(asset)
			local sqdn =
				self:getAssetMgr():getAsset(asset.name:match("(%w+)(.+)"))
			if sqdn == nil then
				sqdn =
					self:getAssetMgr():getAsset(enum.defaultsqdns[asset.owner])
			end
			-- TODO: register group with their squadron and airbase
			--sqdn:add(asset)
			cnt = cnt + 1
		end
	end
	Logger:info(string.format("_loadPlayerSlots(); found %d player groups",
		cnt))
end

function Theater:export(_)
	local statefile
	local msg

	statefile, msg = io.open(settings.statepath, "w+")

	if statefile == nil then
		Logger:error("export(); unable to open '"..
			settings.statepath.."'; msg: "..tostring(msg))
		return self.savestatefreq
	end

	local exporttbl = {
		["complete"] = self.complete,
		["date"]     = dctutils.date("*t", dctutils.time(timer.getAbsTime())),
		["theater"]  = env.mission.theatre,
		["sortie"]   = env.getValueDictByKey(env.mission.sortie),
		["assetmgr"] = self:getAssetMgr():marshal(),
		["startdate"] = self.startdate
	}

	statefile:write(json:encode(exporttbl))
	statefile:flush()
	statefile:close()
	return self.savestatefreq
end

function Theater:generate()
	for _, r in pairs(self.regions) do
		r:generate(self.assetmgr)
	end
end

function Theater:getAssetMgr()
	return self.assetmgr
end

function Theater:getCommander(side)
	return self.cmdrs[side]
end

function Theater:playerRequest(data)
	if data == nil then
		Logger:error("playerRequest(); value error: data must be "..
			"provided; "..debug.traceback())
		return
	end

	Logger:debug("playerRequest(); Received player request: "..
		json:encode_pretty(data))

	local playerasset = self:getAssetMgr():getAsset(data.name)

	if playerasset.cmdpending == true then
		Logger:debug("playerRequest(); request pending, ignoring")
		trigger.action.outTextForGroup(playerasset.groupId,
			"F10 request already pending, please wait.", 20, true)
		return
	end

	local cmd = uicmds[data.type](self, data)
	self:queueCommand(self.uicmddelay, cmd)
	playerasset.cmdpending = true
end

--[[
-- do not worry about command priority right now
-- command queue discussion,
--  * central Q
--  * priority ordered in both priority and time
--     priority = time * 128 + P
--     time = (priority - P) / 128
--
--    This allows things of higher priority to be executed first
--    but things that need to be executed at around the same time
--    to also occur.
--
-- delay - amount of delay in seconds before the command is run
-- cmd   - the command to be run
--]]
function Theater:queueCommand(delay, cmd)
	if delay < self.cmdmindelay then
		Logger:warn(string.format("queueCommand(); delay(%2.2f) less than "..
			"schedular minimum(%2.2f), setting to schedular minumum",
			delay, self.cmdmindelay))
		delay = self.cmdmindelay
	end
	self.cmdq:push(self.ctime + delay, cmd)
	Logger:debug("queueCommand(); cmdq size: "..self.cmdq:size())
end

function Theater:_exec(time)
	self.ltime = self.ctime
	self.ctime = time

	local tstart = os.clock()
	local tdiff = 0
	local cmdctr = 0
	while not self.cmdq:empty() do
		local _, prio = self.cmdq:peek()
		if time < prio then
			break
		end

		local cmd = self.cmdq:pop()
		local requeue = cmd:execute(time)
		if requeue ~= nil and type(requeue) == "number" then
			self:queueCommand(requeue, cmd)
		end
		cmdctr = cmdctr + 1

		tdiff = os.clock() - tstart
		if tdiff >= self.quanta then
			Logger:debug("exec(); quanta reached, quanta: "..
				tostring(self.quanta))
			break
		end
	end
	Logger:debug(string.format("exec(); time taken: %4.2fms;"..
		" cmds executed: %d", tdiff*1000, cmdctr))
end

function Theater:exec(time)
	local errhandler = function(err)
		Logger:error("protected call - "..tostring(err).."\n"..
			debug.traceback())
	end
	local pcallfunc = function()
		self:_exec(time)
	end

	xpcall(pcallfunc, errhandler)
	return time + self.cmdqdelay
end

return Theater
