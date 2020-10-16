--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Squadron.
--
-- Squadron<AssetBase>:
--   generates additional assets (flights), tracks the state of an
--   aircraft squadron, handles AI or player squadrons
--]]

local class = require("libs.class")
local enum  = require("dct.enum")
local AssetBase = require("dct.assets.AssetBase")
local Logger = dct.Logger.getByName("Asset")

local Squadron = class(AssetBase)
function Squadron:__init(template, region)
	self.__clsname = "Squadron"
	self._subordinates = {}
	AssetBase.__init(self, template, region)
	self:_addMarshalNames({
		"planedata",
		"airbase",
	})
end

function Squadron:_completeinit(template, region)
	AssetBase._completeinit(self, template, region)
	self.planedata = utils.deepcopy(template.planedata)
	self.airbase   = template.airbase
end

function Squadron:addSubordinate(asset)
	self._subordinates[asset.name] = true
end

function Squadron:removeSubordinate(name)
	self._subordinates[asset.name] = nil
end

function PlayerSquadron:despawn()
	for sub, _ in pairs(self._subordinates) do
		-- TODO: despawn subordinates?
	end
	AssetBase.despawn(self)
end

return Squadron
