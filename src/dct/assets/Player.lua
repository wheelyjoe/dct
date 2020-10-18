--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a player asset.
--
-- Player<AssetBase>
-- A player asset doesn't die, is always spawned, never
-- reduces status, and is associated with a squadron.
-- Optionally the player can be associated with an airbase.
--]]

local class = require("libs.class")
local AssetBase = require("dct.assets.AssetBase")
local uimenu  = require("dct.ui.groupmenu")
local dctutils= require("dct.utils")
local Logger  = dct.Logger.getByName("Asset")
local loadout = require("dct.systems.loadouts")
local settings = _G.dct.settings

--[[
-- Player - represents a player slot in DCS
--
-- Slot Management
--   Player objects cannot die however they can be spawned. Spawning
--   is used as the signal for enabling/disabling the slot. The external
--   hooks script will check if this object is spawned before allowing
--   a player to enter the slot.
--
--   This covers disabling the other side is covering kicking a player
--   from a slot.
--]]
local Player = class(AssetBase)
function Player:__init(template, region)
	self.__clsname = "Player"
	self._eventhandlers = {
		[world.event.S_EVENT_BIRTH]   = self.handleBirth,
		[world.event.S_EVENT_TAKEOFF] = self.handleTakeoff,
	}
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"unittype",
		"groupId",
		"airbase",
		"parking",
	})
end

local function airbaseId(grp)
	assert(grp, "value error: grp cannot be nil")
	local name = "airdromeId"
	if grp.category == Unit.Category.HELICOPTER then
		name = "helipadId"
	end
	return grp.data.route.points[1][name]
end

local function airbaseParkingId(grp)
	assert(grp, "value error: grp cannot be nil")
	local wp = grp.data.route.points[1]
	if wp.type == AI.Task.WaypointType.TAKEOFF_PARKING or
	   wp.type == AI.Task.WaypointType.TAKEOFF_PARKING_HOT then
		return grp.data.units[1].parking
	end
	return nil
end

function Player:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	-- we assume all slots in a player group are the same
	self._tpldata   = template:copyData()
	self.unittype   = self._tpldata.data.units[1].type
	self.cmdpending = false
	self.groupId    = self._tpldata.data.groupId
	self.airbase    = dctutils.airbaseId2Name(airbaseId(self._tpldata))
	self.parking    = airbaseParkingId(self._tpldata)
	self.ato        = settings.ui.ato[self.unittype]
	if self.ato == nil then
		self.ato = require("dct.enum").missionType
	end
	self.payloadlimits = settings.payloadlimits
end

function Player:getObjectNames()
	return {self.name, }
end

function Player:getLocation()
	local p = Group.getByName(self.name)
	self._location = p:getUnit(1):getPoint()
	return self._location
end

function Player:handleBirth(event)
	local theater = require("dct.Theater").singleton()
	local grp = event.initiator:getGroup()
	local id = grp:getID()
	if self.groupId ~= id then
		Logger:warn(
			string.format("(%s) - asset.groupId(%d) != object:getID(%d)",
				self.name, self.groupId, id))
	end
	self.groupId = id
	uimenu.createMenu(self)
	local cmdr = theater:getCommander(grp:getCoalition())
	local msn  = cmdr:getAssigned(self)

	if msn then
		trigger.action.outTextForGroup(self.groupId,
			"Welcome. A mission is already assigned to this slot, "..
			"use the F10 menu to get the briefing or find another.",
			20, false)
	else
		trigger.action.outTextForGroup(self.groupId,
			"Welcome. Use the F10 Menu to get a theater update and "..
			"request a mission.",
			20, false)
	end
	loadout.notify(self)
end

function Player:handleTakeoff(_ --[[event]])
	loadout.kick(self)
end

--[[
-- kick - cause the player to be removed from the slot
--
-- players are immediately removed from the slot, however, this
-- action does not prevent another player from joing the slot
--]]
function Player:kick()
	require("dct.Theater").singleton():queuekick(self)
end

return Player
