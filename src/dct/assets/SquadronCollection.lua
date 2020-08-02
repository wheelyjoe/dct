--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Squadron collection.
--]]

local class = require("libs.class")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")
local enum  = require("dct.enum")

local SquadronCollection = class(IDCSObjectCollection)
function SquadronCollection:__init(asset, template, region)
	self._marshalnames = {
		"planedata", "airbase",
	}
	IDCSObjectCollection.__init(self, asset, template, region)
end

function SquadronCollection:_completeinit(template, _ --[[region]])
	self.planedata  = template.planedata
	self.airbase    = template.airbase
	print("spawned Squadron: "..self._asset.name)
	print("planedata: "..require("libs.json"):encode_pretty(self.planedata))
	print("airbase: "..require("libs.json"):encode_pretty(self.airbase))
end

function SquadronCollection:spawn(_ --[[ignore]])
	-- start a periodic command to do, what?
end

function SquadronCollection:takeMission(mission)
end

return SquadronCollection
