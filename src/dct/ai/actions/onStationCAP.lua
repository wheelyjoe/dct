--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents the action of picking up a target.
-- Once an asset has 'died' i.e. met it's death goal
-- the action is considered complete.
--]]

local dctenum = require("dct.enum")
local Action = require("dct.ai.actions.Action")

local OnStationCAP = require("libs.namedclass")("OnStationCAP", Action)
function OnStationCAP:__init(tgtasset, groupName)
	assert(tgtasset ~= nil and tgtasset:isa(require("dct.assets.AssetBase")),
		"tgtasset is not a BaseAsset")
  self.groupName = groupName
  self.group = AssetMgr:getAsset(groupName)
  self.onStation = false
end

function OnStationCAP:AddMenu()
  self.CAPMenu = missionCommands.addSubMenuForGroup(self.group.groupId, "CAP")
  self.OnStnOpt = missionCommands.addCommandForGroup(self.group.groupId, "On Station", self.CAPMenu, self.rptOnStn)
end


function OnStationCAP:rptOnStn()
  trigger.action.outTextForGroup(self.group.groupId, "You are now cosidered on station CAP, remain on station for X minutes or checkout to end mission")
  missionCommands.removeItemForGroup(self.groupName, self.OnStnOpt)
  self.OffStnOpt = missionCommands.addCommandForGroup(self.group.groupId, "Off Station", self.CAPMenu, self.rptOffStn)
end

-- Perform check for action completion here
-- Examples: target death criteria, F10 command execution, etc
function OnStationCAP:complete()
	return self._complete
end

return OnStationCAP
