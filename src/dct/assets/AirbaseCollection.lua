--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an Airbase collection.
--]]

local class = require("libs.class")
local IDCSObjectCollection = require("dct.dcscollections.IDCSObjectCollection")
local Asset = require("dct.Asset")
local enum  = require("dct.enum")

local allowedtpltypes = {
	[enum.assetType.BASEDEFENSE] = true,
	[enum.assetType.SQUADRON]    = true,
}

local AirbaseCollection = class(IDCSObjectCollection)
function AirbaseCollection:__init(asset, template, region)
	self._marshalnames = {
		"subordinates",
	}
	IDCSObjectCollection.__init(self, asset, template, region)
end

function AirbaseCollection:_completeinit(template, _)
	self.subordinates = template.subordinates
end

--[[
-- TODO: only support on-map airbases for now, would need to provide a
-- spawn method that does something to support dynamically spawned
-- airbases.
--]]
function AirbaseCollection:_setup()
	local dcsairbase = Airbase.getByName(self._asset.name)
	assert(dcsairbase, string.format("runtime error: '%s' is not a DCS "..
		"Airbase", self._asset.name))
end

function AirbaseCollection:addSubordinate(asset)
	self.subordinates[asset.name] = asset.type
end

function AirbaseCollection:removeSubordinate(name)
	self.subordinates[name] = nil
end

function AirbaseCollection:notifySubordinates(event)
	for name, assettype in pairs(self.subordinates) do
		local asset = theater:getAssetMgr():getAsset(name)
		if type(asset["onHigherEvent"]) == "function" then
			asset:onHigherEvent(event)
		end
	end
end

function AirbaseCollection:generate(assetmgr, region)
	for _, subordinate in ipairs({"subordinates"}) do
		for _, name in ipairs(self[subordinate] or {}) do
			--print("airbase collection subordinate: "..name)
			local tpl = region:getTemplateByName(name)
			assert(tpl, string.format("runtime error: airbase(%s) defines "..
				"a %s template of name '%s', does not exist",
				self._asset.name, subordinate, name))
			assert(allowedtpltypes[tpl.objtype],
				string.format("runtime error: airbase(%s) defines "..
					"a %s template of name '%s' and type: %d ;"..
					"not supported type", self._asset.name, subordinate,
					name, tpl.objtype))
			tpl.airbase = self._asset.name
			local asset = Asset(tpl, region)
			assetmgr:add(asset)
			self:addSubordinate(asset)
		end
	end
end

return AirbaseCollection
