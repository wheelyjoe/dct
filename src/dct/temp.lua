--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common utility functions
--]]


local settings = _G.dct.settings

function utils.getATO(side, unittype)
	local unitATO = settings.atorestrictions[side][unittype]

	if unitATO == nil then
		unitATO = enum.missionType
	end
	return unitATO
end

