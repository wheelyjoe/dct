--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Squadron.
--
-- Squadron<BaseAsset>:
--   generates additional assets (flights), tracks the state of an
--   aircraft squadron, handles AI or player squadrons
--]]

local class = require("libs.class")
local enum  = require("dct.enum")
local BaseAsset = require("dct.assets.BaseAsset")
local Asset = require("dct.assets.Asset")
local Stats = require("dct.utils.Stats")

local statids = {
	["ACLOST"] = "aclost",
	["MIA"]    = "mia",
	["KIA"]    = "kia",
}

local function task2msntype(edtask)
	-- TODO: map task type to DCT mission type
	return edtask
end

local function get_plane_info(cls, tpldata)
	local planetpl
	local country
	local category
	local payloads = {}

	for _, planegrp in ipairs(tpldata) do
		if category == nil and
		   (planegrp.category == Unit.Category.AIRPLANE or
		    planegrp.category == Unit.Category.HELICOPTER) then
			-- we found our first group
			planetpl = planegrp.data.units[1]
			country  = planegrp.countryid
			category = planegrp.category
		elseif category == planegrp.category and
		       planetpl.type == planegrp.units[1].type then
			-- we found an additional payload
			-- TODO: we only support one payload per mission type, thus
			-- if multiple payloads are specified for the same mission
			-- the last one will be chosen.
			local msntype = task2msntype(planegrp.data.task)
			payloads[msntype] = planegrp.data.units[1].payload
		end
	end

	-- clean some keys from the unit table
	for _, v in pairs({"alt", "alt_type", "parking", "speed",
		"parking_id", "x", "y",}) do
		planetpl[v] = nil
	end

	cls.plane_info = {
		["unit"]     = planetpl,
		["country"]  = country,
		["category"] = category,
		["payloads"] = payloads,
	}
end

local Squadron = class(BaseAsset)
function Squadron:__init(template, region)
	self.__clsname = "Squadron"
	self._subordinates = {}
	self.stats = Stats()
	self._flying = 0
	BaseAsset.__init(self, template, region)
	self:_addMarshalNames({
		"airbase",
		"ato",
		"count",
		"flightsize",
	})
end

function Squadron:_completeinit(template, region)
	BaseAsset._completeinit(self, template, region)
	local planedata = utils.deepcopy(template.planedata)
	self.airbase = template.airbase
	if self.type == enum.assetType.SQUADRON then
		assert(self.airbase,
			"An airbase must be defined for an AI squadron")
	end
	self.ato     = planedata.ato
	self.count   = {
		["max"]     = planedata.max,
		["current"] = planedata.current,
	}
	self.flightsize = planedata.flightsize
	if self.type == enum.assetType.PLAYERSQUADRON then
		self.payloadlimits = planedata.payloadlimits
		self.gridfmt       = planedata.gridfmt
	else
		self.ai = {
			["experience"] = planedata.experience,
			["readytime"]  = planedata.readytime,
			["alerttime"]  = planedata.alerttime,
		}
		get_plane_info(self, template:copyData())
	end
	self.stats:register(statids.ACLOST, 0, "Aircraft Lost")
	self.stats:register(statids.MIA, 0, "Pilots Missing")
	self.stats:register(statids.KIA, 0, "Pilots Killed")
end

function Squadron:_setup()
	if self.type == enum.assetType.PLAYERSQUADRON then
		self:_addMarshalNames({
			"payloadlimits",
			"gridfmt",
		})
		self.takeMission = nil
	else
		self:_addMarshalNames({
			"ai",
			"plane_info",
		})
		self.addPlayer   = nil
	end
end

function Squadron:getLocation()
	if self.airbase == nil then
		return nil
	end

	local airbase = theater:getAssetMgr():getAsset(self.airbase)
	if airbase == nil then
		return nil
	end
	return airbase:getLocation()
end

function Squadron:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	self._spawned = true
end

-- Extended methods
--
function Squadron:addPlayer(player)
	self._subordinates[player.name] = true
end

--[[
-- Determine if the squadron can take the proposed mission.
--
-- Returns: false if unable to take mission, true if taken
--]]
function Squadron:takeMission(mission)
	if not self:isSpawned() then
		return false
	end
	if self.ato[mission.type] == nil then
		return false
	end
	local available = self.count.current - self._flying
	if available < self.flightsize then
		return false
	end

	local airbase = theater:getAssetMgr():getAsset(self.airbase)
	if airbase == nil or not airbase:isOperational() then
		return false
	end
	-- TODO: This is where we would add more checking to determine
	-- if target was within the combat radius of the payload, select
	-- the optimal payload, etc.

	local unit = utils.deepcopy(self.plane_info.unit)
	if self.plane_info.payloads[mission.type] ~= nil then
		unit.payload = self.plane_inf.payloads[mission.type]
	end

	local grp = {
		["category"]  = self.plane_info.category,
		["countryid"] = self.plane_info.country,
		["data"]      = {
			["route"] = {},
			["units"] = {},
			["name"]  = "",
			["communication"] = true,
		},
	}

	for i = 1, self.flightsize, 1 do
		-- TODO: set the unit's callsign, board number, and skill
		-- based on the squadron's parameters
		table.insert(grp.data.units, utils.deepcopy(unit))
	end

	local flight = Asset.factory(Template({
		["objtype"]   = "flight",
		["name"]      = self.name..":"..self.flightcnt,
		["regionname"]= "theater",
		["coalition"] = self.owner,
		["desc"]      = "AI Flight",
		["tpldata"]   = grp,
		["airbase"]   = airbase.name,
	}), {["name"] = "theater", ["priority"] = 1000,})
	theater:getAssetMgr():add(flight)
	airbase:addFlight(addstddev(unpack(self.readytime)), flight)
	self:onAircraftDepart(self.flightsize)
	return true
end

function Squadron:onAircraftAdd(num)
	if self.count.current < 0 then
		return
	end

	local max = 10000
	if self.count.max > 0 then
		max = self.count.max
	end
	self.count.current = clamp(self.count.current + num, 0, max)
end

function Squadron:onAircraftDepart(num)
	self._flying = self._flying + num
end

function Squadron:onAircraftRecovered(num)
	self._flying = self._flying - num
end

function Squadron:onAircraftLost()
	self.stats:inc(statids.ACLOST)
	if self.count.current > 0 then
		self.count.current = self.count.current - 1
	end
	self._flying = clamp(self._flying - 1, 0, self._flying)
end

function Squadron:onPilotKIA()
	self.stats:inc(statids.KIA)
end

function Squadron:onPilotMIA()
	self.stats:inc(statids.MIA)
end

return Squadron
