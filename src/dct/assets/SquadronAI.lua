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
local Squadron = require("dct.assets.Squadron")
local Logger = dct.Logger.getByName("Asset")

local function processGroup(sqdn, grp)
	if grp.units == nil then
		Logger:error(string.format("%s(%s) aircraft group(%s), "..
			"no units defined", sqdn.__clsname, sqdn.name, grp.name))
		return
	end
	if sqdn.planedata.type ~= nil and
	   sqdn.planedata.type ~= grp.units[1].type then
		Logger:info(string.format("%s(%s) aircraft group(%s), "..
			"plane type not the same, skipping",
			sqdn.__clsname, sqdn.name, grp.name))
		return
	end

	local unit = grp.units[1]
	if sqdn.plandata.type == nil then
		sqdn.plandata.type = unit.type
		sqdn.plandata.livery = unit.livery_id
		sqdn.plandata.callsign = unit.callsign
	end

	local tasktype = grp.task
	if sqdn.planedata.payloads.default == nil then
		tasktype = "default"
	end

	sqdn.planedata.payloads[tasktype] = {}
	sqdn.planedata.payloads[tasktype].hardpoint_racks =
		unit.hardpoint_racks
	sqdn.planedata.payloads[tasktype].payload = unit.payload
end

local function getPlaneInfo(sqdn, tpldata)
	assert(tpldata ~= nil, "value error: tpldata cannot be nil")
	local allowed = {
		[Unit.Category.AIRPLANE]   = true,
		[Unit.Category.HELICOPTER] = true,
	}

	for _, grp in ipairs(tpldata) do
		if allowed[grp.category] ~= nil then
			processGroup(sqdn, grp)
		end
	end
end

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
	getPlaneInfo(self, template:copyData())

end

function Squadron:addSubordinate(asset)
	self._subordinates[asset.name] = true
end

function Squadron:removeSubordinate(name)
	self._subordinates[asset.name] = nil
end

function Squadron:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	AssetBase.spawn(self)
end

return Squadron

--[[
unit definition

 - onboard_num
 - callsign
 - heading
 - payload
 - name
 - x
 - y
 - ?parking_id
 - psi
 - type
 - speed
 - ?parking
 - skill
 - livery_id
 - alt_type
 - ?hardpoint_racks
 - alt

group definition

 - modulation
 - task
 - uncontrolled
 - route
 - units
 - frequency
 - start_time
 - communication
 - name
 - x
 - y
--]]
