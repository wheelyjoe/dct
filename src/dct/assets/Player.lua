--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a player asset.
--
-- Player<BaseAsset>
-- A player asset doesn't die, is always spawned, never
-- reduces status, and is associated with a squadron.
-- Optionally the player can be associated with an airbase.
--]]

local class = require("libs.class")
local BaseAsset = require("dct.assets.BaseAsset")
local uimenu  = require("dct.ui.groupmenu")
local dctutils= require("dct.utils.utils")
local Logger  = require("dct.utils.Logger").getByName("Asset")
local loadout = require("dct.systems.loadouts")

-- TODO: how to disable the player slot, we need to cover two cases:
--  * disabled: a player cannot enter the slot but if already occupied
--    the player is not removed from the slot
--  * kick: players are immediately removed from the slot and
--    new players are prevented from joining

local Player = class(BaseAsset)
function Player:__init(template, region)
	self.__clsname = "Player"
	BaseAsset.__init(self, template, region)
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
	BaseAsset._completeinit(self, template, region)
	-- we assume all slots in a player group are the same
	self._tpldata   = template:copyData()
	self.unittype   = self._tpldata.units[1].type
	self.cmdpending = false
	self.groupId    = self._tpldata.groupId
	self.airbase    = dctutils.airbaseId2Name(airbaseId(self._tpldata))
	self.parking    = airbaseParkingId(self._tpldata)
end

function Player:getObjectNames()
	return {self.name, }
end

function Player:getLocation()
	local p = Group.getByName(self.name)
	self._location = p:getUnit(1):getPoint()
	return self._location
end

local function handleBirth(self, event)
	local theater = _G.dct.theater
	local grp = event.initiator:getGroup()
	local id = grp:getID()
	if self.groupId ~= id then
		Logger:warn(
			string.format("(%s) - asset.groupId(%d) != object:getID(%d)",
				self.name, self.groupId, id))
	end
	self.groupId = id
	uimenu.createMenu(theater, self)
	local cmdr = theater:getCommander(grp:getCoalition())
	local msn  = cmdr:getAssigned(self)

	if msn then
		trigger.action.outTextForGroup(grp:getID(),
			"Welcome. A mission is already assigned to this slot, "..
			"use the F10 menu to get the briefing or find another.",
			20, false)
	else
		trigger.action.outTextForGroup(grp:getID(),
			"Welcome. Use the F10 Menu to get a theater update and "..
			"request a mission.",
			20, false)
	end
	loadout.notify(grp)
end

local function handleTakeoff(self, event)
	loadout.kick(event.initiator:getGroup())
end

local handlers = {
	[world.event.S_EVENT_BIRTH] = handleBirth,
	[world.event.S_EVENT_TAKEOFF] = handleTakeoff,
}

function Player:onDCSEvent(event)
	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

return Player
