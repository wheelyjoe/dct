--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides the base class for Assets.
-- An Asset is a group of virtual or real objects in the game world
-- that can be interacted with.
--
Class Hierarchy:

            BaseAsset----Airspace
                |
   Airbase------+------Squadron
				|
			  Static-----IAgent-----Player

An AIAgent is an Asset that is movable.
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local dctenum  = require("dct.enum")
local dctutils = require("dct.utils.utils")
local Goal     = require("dct.Goal")
local Marshallable = require("dct.utils.Marshallable")
local settings = _G.dct.settings

local norenametype = {
	[dctenum.assetType.PLAYERSQUADRON] = true,
	[dctenum.assetType.PLAYERGROUP]    = true,
	[dctenum.assetType.SQUADRON]       = true,
	[dctenum.assetType.AIRBASE]        = true,
}

local function generateCodename(objtype)
	local codenamedb = settings.codenamedb
	local typetbl = codenamedb[objtype]

	if typetbl == nil then
		typetbl = codenamedb.default
	end

	local idx = math.random(1, #typetbl)
	return typetbl[idx]
end


local function genLocationMethod()
	local txt = {
		"Reconaissasnce elements have located",
		"A recon flight earlier today discovered",
		"We have reason to believe there is",
		"Aerial photography shows that there is",
		"Satellite Imaging has found",
		"Ground units operating in the area have informed us of",
	}
	local idx = math.random(1,#txt)
	return txt[idx]
end

--[[
BaseAsset:
	attributes(public, read-only):
	- type - [number] asset type
	- briefing - [string] briefing text used when displaying the briefing
	             to players
	- owner - [number] the coalition the asset belongs to
	- rgnname - [string] the region name the asset is in
	- tplname - [string] the template name the asset was created from
	- name - [string] name of the asset
	- codename - [string] single word code name of the asset, used in
	             briefings to players
--]]
local BaseAsset = class(Marshallable)
function BaseAsset:__init(template, region)
	if not self.__clsname then
		self.__clsname = "BaseAsset"
	end
	Marshallable.__init(self)
	self:_addMarshalNames({
		"_spawned",
		"_dead",
		"_intel",
		"_priority",
		"_dctobservers",
		"type",
		"briefing",
		"owner",
		"rgnname",
		"tplname",
		"name",
		"codename",})
	self._spawned    = false
	self._dead       = false
	self._targeted   = {}
	self._intel      = {}
	self._priority   = {}
	for _, side in pairs(coalition.side) do
		self._targeted[side] = 0
		self._intel[side]    = 0
		self._priority[side] = {
			["region"] = 0,
			["asset"]  = 0,
		}
	end
	self._dctobservers = {}
	self._initcomplete = false
	if template ~= nil and region ~= nil then
		self:_completeinit(template, region)
		self:_setup()
		self._initcomplete = true
	end
end

function BaseAsset:_completeinit(template, region)
	self.type     = template.objtype
	if template.desc then
		self.briefing = dctutils.interp(template.desc, {
			["LOCATIONMETHOD"] = genLocationMethod(),
		})
	else
		print(string.format("Template(%s) has nil 'desc' field",
			template.name))
	end
	self.owner    = template.coalition
	self.rgnname  = region.name
	self.tplname  = template.name
	if norenametype[self.type] == true then
		self.name = self.tplname
	else
		self.name = region.name.."_"..self.owner.."_"..template.name
	end
	self.codename = generateCodename(self.type)

	self._intel[self.owner] = dctutils.INTELMAX
	if self.owner ~= coalition.side.NEUTRAL and template.intel then
		self._intel[dctutils.getenemy(self.owner)] = template.intel
	end
	for _, side in pairs(coalition.side) do
		self._priority[side] = {
			["region"] = region.priority,
			["asset"]  = template.priority,
		}
	end
end

--[[
-- Do whatever post init setup needs to be done, is also called
-- when unmarshalling an object.
--]]
function BaseAsset:_setup()
end

--[[
-- Magic function used by the Marshallable class.
-- Handle the intel and priority tables special because even
-- though their keys were numbers when the state was serialized
-- in json's wisdom it decided to convert them to strings. So we
-- need to convert back so we can access the data in our lookups.
--]]
function BaseAsset:_unmarshalpost(data)
	for _, tbl in ipairs({"_intel", "_priority"}) do
		self[tbl] = {}
		for k, v in pairs(data[tbl]) do
			self[tbl][tonumber(k)] = v
		end
	end
end

function BaseAsset:marshal()
	assert(self._initcomplete == true,
		"runtime error: init not completed")
	return Marshallable.marshal(self)
end

function BaseAsset:unmarshal(data)
	assert(self._initcomplete == false,
		"runtime error: init completed already")
	Marshallable.unmarshal(self, data)
	self:_setup()
	self._initcomplete = true
	if self:isSpawned() then
		self:spawn(true)
	end
end

function BaseAsset:generate(_ --[[assetmgr, region]])
end

--[[
-- Get the priority of the asset.
-- Returns: number
--]]
function BaseAsset:getPriority(side)
	return ((self._priority[side].region * 65536) +
		self._priority[side].asset)
end

--[[
-- Modify the priority of the asset table, where 'side' is the
-- priority table to use and 'tbl' is the table to merge with.
-- Returns: none
--]]
function BaseAsset:setPriority(side, tbl)
	utils.mergetables(self._priority[side], tbl)
end

--[[
-- Intel - an intel level of zero implies the given side has no
-- idea about the asset.
--
-- Get the intel level the specified side has on this asset.
-- Returns: number, intel level
--]]
function BaseAsset:getIntel(side)
	return self._intel[side]
end

--[[
-- Set the intel level for the given side.
-- Returns: none
--]]
function BaseAsset:setIntel(side, val)
	assert(type(val) == "number", "value error: must be a number")
	self._intel[side] = val
end

--[[
-- Is the specified side currently targeting the asset?
-- Returns: boolean
--]]
function BaseAsset:isTargeted(side)
	return self._targeted[side]
end

--[[
-- Set the targeted state for a side for an asset.
-- Returns: none
--]]
function BaseAsset:setTargeted(side, val)
	assert(type(val) == "boolean",
		"value error: argument must be of type bool")
	self._targeted[side] = val
end

--[[
-- Get the centroid location of the asset.
-- Returns: nil - if not supported otherwise a DCS Vec3
--]]
function BaseAsset:getLocation()
	return self._location
end

--[[
-- Get the "status" of the asset, that being a percentage
-- completion of the death goal.
-- Returns: 0-100 value, example if there were 10 original goals
--          and 4 were complete the value returned would be '40'.
--]]
function BaseAsset:getStatus()
	return 0
end

--[[
-- Is the asset considered dead yet?
-- Returns: boolean
--]]
function BaseAsset:isDead()
	return self._dead
end

--[[
-- Sets if the object should be thought of as dead or not
-- Returns: none
--]]
function BaseAsset:setDead(val)
	assert(type(val) == "boolean", "value error: val must be of type bool")
	self._dead = val
end

--[[
-- Check the asset death goals.
-- Returns: none
--]]
function BaseAsset:checkDead()
end

--[[
-- Get DCS object names associated with this asset.
-- Returns: A list of DCS group names that map to this asset.
--          An empty table is valid.
--]]
function BaseAsset:getObjectNames()
	return {}
end

--[[
-- Process a DCS event associated w/ this asset.
-- Returns: none
--]]
function BaseAsset:onDCSEvent(_ --[[event]])
end

--[[
-- Have the DCS objects associated with this asset been spawned?
-- Returns: boolean
--]]
function BaseAsset:isSpawned()
	return self._spawned
end

--[[
-- Spawn any DCS objects associated with this asset.
-- Returns: none
--]]
function BaseAsset:spawn(_ --[[ignore]])
	self._spawned = true
end

--[[
-- Remove any DCS objects associated with this asset from the game world.
-- The method used should result in no DCS events being triggered.
-- Returns: none
--]]
function BaseAsset:despawn()
	self._spawned = false
end

function BaseAsset:addObserver(asset)
	if type(asset.onDCTEvent) == "function" then
		self._dctobservers[asset.name] = true
	end
end

function BaseAsset:removeObserver(name)
	self._dctobservers[name] = nil
end

function BaseAsset:notifyObservers(event)
	local theater = _G.dct.theater
	for name, _ in pairs(self._dctobservers) do
		local asset = theater:getAssetMgr():getAsset(name)
		if type(asset.onDCTEvent) == "function" then
			asset:onDCTEvent(event)
		end
	end
end

--[[
Assets that support receiving DCT events should implement this function.

function BaseAsset:onDCTEvent(event)
end
--]]

function BaseAsset.defaultgoal(static)
	local goal = {}
	goal.priority = Goal.priority.PRIMARY
	goal.goaltype = Goal.goaltype.DAMAGE
	goal.objtype  = Goal.objtype.GROUP
	goal.value    = 90

	if static then
		goal.objtype = Goal.objtype.STATIC
	end
	return goal
end

return BaseAsset
