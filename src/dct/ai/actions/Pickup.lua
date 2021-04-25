--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents the action of picking up a target.
-- Once an asset has 'died' i.e. met it's death goal
-- the action is considered complete.
--]]

local dctenum = require("dct.enum")
local Action = require("dct.ai.actions.Action")
local AssetMgr = require("dct.assets.AssetManager")
local vect = require("dct.libs.vector")

local Collect = require("libs.namedclass")("Collect", Action)
function Collect:__init(tgtasset, groupName)
	assert(tgtasset ~= nil and tgtasset:isa(require("dct.assets.AssetBase")),
		"tgtasset is not a BaseAsset")
	Action.__init(self, tgtasset)
	self.tgtname = tgtasset.name
  self.groupName = groupName
  self.group = AssetMgr:getAsset(groupName)
	self._complete = tgtasset:isDead()
  self.searchRadius = 200
end

function Collect:AddMenu()
  self.pickupOption = missionCommands.addCommandForGroup(self.group.groupId, "Pickup", nil, self.checkPickup, self.groupName)
end

function Collect:assetCheck(foundItem, val)
  if foundItem:getCategory() == Object.Category.UNIT then
		for _, name  in pairs(self.tgtName) do
			if foundItem:getName() == name then
				--increment weight + delete unit or
				--add pickup option "f1. Crate - 1000kg", etc
			end
		end
    --check if unit is part of group to be picked up
  elseif foundItem:getCategory() == Object.Category.STATIC then
		for _, name  in pairs(self.tgtName) do
			if foundItem:getName() == name then
			--increment weight + delete unit or
			--add pickup option "f1. Crate - 1000kg", etc
			end
		end
  end
end

function Collect:checkPickup()
	if (self.group:getUnit(1):inAir()) then
  	trigger.action.outTextForGroup(self.group.groupId, "Please land before attempting pickup", 10
		return
	end
  local volS = {
   id = world.VolumeType.SPHERE,
   params = {
     point = self.group:getUnit(1):getPoint(),
     radius = 200
   }
 }
  world.searchObjects({Object.Category.STATIC, Object.Category.UNIT}, volS, self.assetCheck())
end

function Collect:Pickup()
  missionCommands.removeItemForGroup(self.groupName, self.pickupOption)

end

-- Perform check for action completion here
-- Examples: target death criteria, F10 command execution, etc
function Collect:complete()
	return self._complete
end

return Collect
