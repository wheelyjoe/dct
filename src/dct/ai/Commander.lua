--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a side's strategic theater commander.
--]]

local class      = require("libs.class")
local utils      = require("libs.utils")
local containers = require("libs.containers")
local enum       = require("dct.enum")
local dctutils   = require("dct.utils.utils")
local Marshallable = require("dct.utils.Marshallable")
local Mission    = require("dct.ai.Mission")
local Stats      = require("dct.utils.Stats")
local Command    = require("dct.utils.Command")
local Logger     = require("dct.utils.Logger").getByName("Commander")

local function heapsort_tgtlist(assetmgr, owner, filterlist)
	local tgtlist = assetmgr:getTargets(owner, filterlist)
	local pq = containers.PriorityQueue()

	-- priority sort target list
	for tgtname, _ in pairs(tgtlist) do
		local tgt = assetmgr:getAsset(tgtname)
		if tgt ~= nil and not tgt:isDead() and not tgt:isTargeted(owner) then
			pq:push(tgt:getPriority(owner), tgt)
		end
	end

	return pq
end

local function genstatids()
	local tbl = {}

	for k,v in pairs(enum.missionType) do
		table.insert(tbl, {v, 0, k})
	end
	return tbl
end

--[[
--  Commander class
--    Responsible for managing a side's response via air, land, and sea.
--
--  Region Threat Analysis
--    Periodically reanalyze each region's threat matrix.
--    For calculating an airspace's 'air threat' simply find how
--      many aircraft are in the airspace and calculate the percentage
--      of the population, example:
--        blue = 5 a/c; threat = 5/7 * 100 = 71
--        red  = 2 a/c; threat = 2/7 * 100 = 29
--      To report the air threat to a human, simply reports their side's
--      threat value.
--
--  Mission Tracker
--    * track missions and update target list as missions
--      are completed
--    * could update the threat matrix as missions are
--      completed too
--
--  IADS Manager
--	  * manage fighters assigned to CAP/ALERT mission to handle
--	    the air war at the tactical level
--	  * handle SAM network as well
--	  * can only retask assets/missions currently available
--
--  ATO Manager
--    Handles the scheduling of AI flights from available squadrons.
--    Manages strategic analysis and issuing goals to friendly air
--    units. This is accomplished by having each squadron queue a
--    flight to be assigned. This allows flights spawned from the
--    squadron to signal back when they think they are almost done
--    so the squadron can schedule another flight based on its sortie
--    rate and available aircraft.
--
--    Stats:
--     * target fighter ratio(FR_t) - fixed value from configuration
--     * alert factor(AF) - fixed value from configuration
--     * fighter strength(FS)
--     * region.sam.threat
--     * region.shorad.threat
--     * region.ewrs
--     * downed pilot(P)
--
--    Decision Factors:
--     * region sam threat(R_st) =
--         clamp(sum(region.sams.threat_i),0,100)/100
--     * region shorad threat(R_sht) =
--         clamp(sum(region.shorad.threat_i),0,100)/100
--     * region ewr coverage (R_it) =
--         sum(region.ewrs)/region.ewr_original
--     * fighter ratio (FR) =
--         clamp(FR_t - (FS_friendly / FS_enemy),0,1)
--     * region airbase exists(AB) =
--         boolean(enemy airbase exists)
--
--    Actions:
--     * CAS    - Us = ?
--     * CAP    - Us = FR
--     * ALERT  - Us = avg(FR, AF)
--     * STRIKE - Us = 1 - avg(R_st, 1 - FR)
--     * SEAD   - Us = avg(R_st, 1 - FR)
--     * BAI    - Us = ?
--     * OCA    - Us = AB * avg(1-FR, 1-R_st)
--     * TRANS  - Us = ? (transport)
--     * RR     - Us = ? (route recon)
--     * CSAR   - Us = P
--     * TANKER - Us = ?
--     * AWACS  - Us = ?
--
--    Tie Breaker:
--     Each action will have an associated priority.
--]]
local Commander = class(Marshallable)
function Commander:__init(theater, side)
	Marshallable.__init(self)
	self.owner         = side
	self.theater       = theater
	self.missionstats  = Stats(genstatids())
	self.missions      = {}
	self.flights       = containers.Queue()
	self.stats         = Stats()
	self.regionthreats = {}  -- indexed by region name
	self.missionfreq   = 120 -- seconds
	self.theater:queueCommand(self.aifreq, Command(self.update, self))
end

function Commander:calcRegionThreats(time)
end

function Commander:missionTracker(time)
	for _, mission in pairs(self.missions) do
		mission:update(time)
	end
	return self.missionfreq
end

function Commander:IADSCommander(time)
end

function Commander:schedualFlight(flight)
	self.flights:pushhead(flight)
end

function Commander:ATOSchedular(time)
	if self.flights:empty() then
		return self.schedfreq
	end

	local flight = self.flights:poptail()
end

function Commander:getTheaterUpdate()
	--local enemystats = self.theater:getTargetStats(self.owner)
	local theaterUpdate = {}

	theaterUpdate.enemy = {}
	theaterUpdate.enemy.sea = 50
	theaterUpdate.enemy.air = 50
	theaterUpdate.enemy.elint = 50
	theaterUpdate.enemy.sam = 50
	theaterUpdate.missions = self.missionstats:getStats()
	for k,v in pairs(theaterUpdate.missions) do
		if v == 0 then
			theaterUpdate.missions[k] = nil
		end
	end
	return theaterUpdate
end

local MISSION_ID = math.random(1,63)
local invalidXpdrTbl = {
	["7700"] = true,
	["7600"] = true,
	["7500"] = true,
	["7400"] = true,
}

local squawkMissionType = {
	["SAR"]  = 0,
	["SUPT"] = 1,
	["A2A"]  = 2,
	["SEAD"] = 3,
	["SEA"]  = 4,
	["A2G"]  = 5,
}

local function map_mission_type(msntype)
	local sqwkcode
	if msntype == enum.missionType.CAP then
		sqwkcode = squawkMissionType.A2A
	--elseif msntype == enum.missionType.SAR then
	--	sqwkcode = squawkMissionType.SAR
	--elseif msntype == enum.missionType.SUPPORT then
	--	sqwkcode = squawkMissionType.SUPT
	elseif msntype == enum.missionType.SEAD then
		sqwkcode = squawkMissionType.SEAD
	else
		sqwkcode = squawkMissionType.A2G
	end
	return sqwkcode
end

--[[
-- Generates a mission id as well as generating IFF codes for the
-- mission.
--
-- Returns: a table with the following:
--   * id (string): is the mission ID
--   * m1 (number): is the mode 1 IFF code
--   * m3 (number): is the mode 3 IFF code
--  If 'nil' is returned no valid mission id could be generated.
--]]
function Commander:genMissionCodes(msntype)
	local id
	local m1 = map_mission_type(msntype)
	while true do
		MISSION_ID = (MISSION_ID + 1) % 64
		id = string.format("%01o%02o0", m1, MISSION_ID)
		if invalidXpdrTbl[id] == nil and
			self:getMission(id) == nil then
			break
		end
	end
	local m3 = (512*m1)+(MISSION_ID*8)
	return { ["id"] = id, ["m1"] = m1, ["m3"] = m3, }
end

--[[
-- recommendMission - recommend a mission type given a unit type
-- unittype - (string) the type of unit making request requesting
-- return: mission type value
--]]
function Commander:recommendMissionType(allowedmissions)
	local assetfilter = {}

	for _, v in pairs(allowedmissions) do
		utils.mergetables(assetfilter, enum.missionTypeMap[v])
	end

	local pq = heapsort_tgtlist(self.theater:getAssetMgr(),
		self.owner, assetfilter)

	local tgt = pq:pop()
	if tgt == nil then
		return nil
	end
	return dctutils.assettype2mission(tgt.type)
end

--[[
-- requestMission - get a new mission
--
-- Creates a new mission where the target conforms to the mission type
-- specified and is of the highest priority. The Commander will track
-- the mission and handling tracking which asset is assigned to the
-- mission.
--
-- grpname - the name of the commander's asset that is assigned to take
--   out the target.
-- missiontype - the type of mission which defines the type of target
--   that will be looked for.
--
-- return: a Mission object or nil if no target can be found which
--   meets the mission criteria
--]]
function Commander:requestMission(grpname, missiontype)
	local pq = heapsort_tgtlist(self.theater:getAssetMgr(),
		self.owner, enum.missionTypeMap[missiontype])

	-- if no target, there is no mission to assign so return back
	-- a nil object
	local tgt = pq:pop()
	if tgt == nil then
		return nil
	end
	Logger:debug(string.format("requestMission() - tgt name: '%s'; "..
		"isTargeted: %s", tgt.name, tostring(tgt:isTargeted())))

	local mission = Mission(self, missiontype, grpname, tgt.name)
	self:addMission(mission)
	return mission
end

--[[
-- return the Mission object identified by the id supplied.
--]]
function Commander:getMission(id)
	return self.missions[id]
end

function Commander:addMission(mission)
	self.missions[mission:getID()] = mission
	self.missionstats:inc(mission.type)
end

--[[
-- remove the mission identified by id from the commander's tracking
--]]
function Commander:removeMission(id)
	local mission = self.missions[id]
	self.missions[id] = nil
	self.missionstats:dec(mission.type)
end

function Commander:getAssigned(asset)
	local msn = self.missions[asset.missionid]

	if msn == nil then
		asset.missionid = 0
		return nil
	end

	local member = msn:isMember(asset.name)
	if not member then
		asset.missionid = 0
		return nil
	end
	return msn
end

function Commander:getAsset(name)
	return self.theater:getAssetMgr():getAsset(name)
end

return Commander
