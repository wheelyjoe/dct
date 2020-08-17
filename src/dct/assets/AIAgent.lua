--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a player asset.
-- A player asset doesn't die, is always spawned, never
-- reduces status, and is associated with a squadron.
-- Optionally the player can be associated with an airbase.
--]]

--[[
   Player<MoveableAsset>
   * flight groups with player slots in them
   * DCS-objects, has associated DCS objects
     * objects move
     * no death goals, has death goals due to having DCS objects
     * spawn, nothing to spawn
   * invincible, asset cannot die (i.e. be deleted)
   * no associated "team leader" AI
   * player specific isSpawned() test - why?
   * enabled, asset can be enabled/disabled
     * DCS flag associated to control if the slot is enabled
       (think airbase captured so slot should not be joinable)
   * registers with an airbase asset
--]]

local class = require("libs.class")
local StaticAsset = require("dct.assets.StaticAsset")
local dctutils= require("dct.utils.utils")
local Logger  = require("dct.utils.Logger").getByName("Asset")

local IAgent = class(StaticAsset)
function Player:__init(template, region)
	self.__clsname = "Player"
	StaticAsset.__init(self, template, region)
	self:_addMarshalNames({
		"unittype",
		"groupId",
		"airbase",
		"parking",
	})
end


