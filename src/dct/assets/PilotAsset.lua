--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines a PilotAsset to handle downed airmen.
--]]

local class    = require("libs.class")
local enum     = require("dct.enum")
local Asset    = require("dct.Asset")
local Goal     = require("dct.Goal")
local Command  = require("dct.Command")
local Logger   = require("dct.Logger").getByName("PilotAsset")
local settings = _G.dct.settings
local DOWNED_PILOT_CREATION_DELAY = 60

local function createPilot(position, owner, cntry)
	local sprite = settings.pilotdb[cntry]
	local tpldata = {
		["vehicle"] = {
			[1] = {
				["countryid"] = cntry,
				["data"] = {
					["visible"] = true,
					["lateActivation"] = false,
					["uncontrollable"] = true,
					["hidden"] = false,
					["units"] = {
						[1] = {
							["type"] = sprite,
							["skill"] = "Average",
							["y"] = position.x,
							["x"] = position.z,
							["name"] = "DESTROYED PRIMARY pilot",
							["heading"] = 0,
							["playerCanDrive"] = false,
						}, -- end of [1]
					}, -- end of ["units"]
					["y"] = position.x,
					["x"] = position.z,
					["name"] = "Downed Pilot Group",
					["start_time"] = 0,
				},
			},
		},
	}
	local template = {}
	template.tpldata = tpldata
	template.coalition = owner
	template.objtype = enum.assetType.PILOT
	template.uniquenames = true
	template.name = "Downed Pilot"
	template.desc = "A downed airman is blah blah"
	return Asset(Template(template))
end

local DownedPilotCmd = class(Command)
function DownedPilotCmd:__init(theater, unit)
	self.theater  = theater
	self.position = unit:getPoint()
	self.owner    = unit:getCoalition()
	self.country  = unit:getCountry()
end

function DownedPilotCmd:execute(time)
	local asset = createPilot(self.position, self.owner, self.country)
	self.theater:getAssetMgr():add(asset)
	asset:spawn()
	-- TODO: queue a command to add tasks, options, and commands to
	-- this pilot asset
	return nil
end

local function DownedPilot(theater, unit)
	theater:queueCommand(DOWNED_PILOT_CREATION_DELAY,
		DownedPilotCmd(unit))
end

return DownedPilot
