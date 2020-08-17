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

local Squadron = class(BaseAsset)
function Squadron:__init(template, region)
	self.__clsname = "Squadron"
	self._subordinates = {}
	BaseAsset.__init(self, template, region)
	self:_addMarshalNames({
		"_planedata",
		"airbase",
	})
end

function Squadron:_completeinit(template, region)
	BaseAsset._completeinit(self, template, region)
	self._planedata  = template.planedata
	self.airbase       = template.airbase
	-- TODO: process _tpldata for AI
	self:getPlaneInfo(template:copyData())

	-- remove player specific APIs if we are not a player
	-- squadron
	if self.type ~= enum.assetType.PLAYERSQUADRON then
		self.addPlayer   = nil
		-- player squadrons do not take missions a player
		-- requests one
		self.takeMission = nil
	end
end

function Squadron:addPlayer(player)
	self._subordinates[player.name] = true
end

function Squadron:takeMission(mission)
	if not self:isSpawned() then
		return 0
	end
	-- TODO: check if the mission is of a type possible to be performed
	-- by the squadron
	--   * schedule flight for mission
	--   * track how many a/c are available to fly, currently flying,
	--     and number in maintance
	return rc
end

function Squadron:onDCSEvent(event)
	-- TODO: handle aircraft death messages, aircraft takeoff/landing,
	-- and hit events to track
end

function Squadron:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	self._spawned = true
end

return Squadron
