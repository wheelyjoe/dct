--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides functions to define and manage Assets.
--]]

local checklib = require("libs.check")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local Command  = require("dct.Command")
local Logger   = dct.Logger.getByName("AssetManager")

local AssetManager = require("libs.namedclass")("AssetManager")
function AssetManager:__init(theater)
	self.updaterate = 120
	-- The master list of assets, regardless of side, indexed by name.
	-- Means Asset names must be globally unique.
	self._assetset = {}

	-- The per side lists to maintain "short-cuts" to assets that
	-- belong to a given side and are alive or dead.
	-- These lists are simply asset names as keys with values of
	-- asset type. To get the actual asset object we need to lookup
	-- the name in a master asset list.
	self._sideassets = {
		[coalition.side.NEUTRAL] = {
			["assets"] = {},
		},
		[coalition.side.RED]     = {
			["assets"] = {},
		},
		[coalition.side.BLUE]    = {
			["assets"] = {},
		},
	}

	-- keeps track of static/unit/group names to asset objects,
	-- remember all spawned Asset classes will need to register the names
	-- of their DCS objects with 'something', this will be the something.
	self._object2asset = {}

	theater:addObserver(self.onDCSEvent, self, "AssetManager.onDCSEvent")
	theater:queueCommand(self.updaterate,
		Command(self.__clsname..".update", self.update, self))
end

function AssetManager:factory(assettype)
	local staticassets = {
		[enum.assetType.OCA]           = true,
		[enum.assetType.BASEDEFENSE]   = true,
		[enum.assetType.SHORAD]        = true,
		[enum.assetType.SPECIALFORCES] = true,
	}
	local asset = nil
	if assettype == enum.assetType.AIRSPACE then
		asset = require("dct.assets.Airspace")
	elseif assettype == enum.assetType.AIRBASE then
		asset = require("dct.assets.Airbase")
	elseif enum.assetClass.STRATEGIC[assettype] or
	       staticassets[assettype] == true then
		asset = require("dct.assets.StaticAsset")
	elseif assettype == enum.assetType.PLAYERGROUP then
		asset = require("dct.assets.Player")
	elseif assettype == enum.assetType.SQUADRONPLAYER then
		asset = require("dct.assets.Squadron")
	else
		assert(false, "unsupported asset type: "..assettype)
	end
	return asset
end

function AssetManager:remove(asset)
	assert(asset ~= nil, "value error: asset object must be provided")

	asset:removeObserver(self)
	self._assetset[asset.name] = nil

	-- remove asset name from per-side asset list
	self._sideassets[asset.owner].assets[asset.name] = nil

	-- remove asset object names from name list
	for _, objname in pairs(asset:getObjectNames()) do
		self._object2asset[objname] = nil
	end
end

function AssetManager:add(asset)
	assert(asset ~= nil, "value error: asset object must be provided")
	assert(self._assetset[asset.name] == nil, "asset name ('"..
		asset.name.."') already exists")

	if asset:isDead() then
		Logger:debug("AssetManager:add - not adding dead asset:"..
			asset.name)
		return
	end

	self._assetset[asset.name] = asset
	asset:addObserver(self.onDCSEvent, self, "AssetManager.onDCSEvent")

	-- add asset to approperate side lists
	if asset.type == enum.assetType.AIRSPACE then
		for _, side in pairs(coalition.side) do
			self._sideassets[side].assets[asset.name] = asset.type
		end
	else
		self._sideassets[asset.owner].assets[asset.name] = asset.type
	end

	Logger:debug("Adding object names for '"..asset.name.."'")
	-- read Asset's object names and setup object to asset mapping
	-- to be used in handling DCS events and other uses
	for _, objname in pairs(asset:getObjectNames()) do
		Logger:debug("    + "..objname)
		self._object2asset[objname] = asset.name
	end
end

function AssetManager:getAsset(name)
	return self._assetset[name]
end

--[[
-- filterAssets - return all asset names matching `filter`
-- filter(asset)
--   returns true if the filter matches and the asset name should be kept
-- Return: a table with asset names as keys. Will always returns a table,
--   even if it is empty
--]]
function AssetManager:filterAssets(filter)
	checklib.func(filter)

	local list = {}
	for name, asset in pairs(self._assetset) do
		if filter(asset) then
			list[name] = true
		end
	end
	return list
end

--[[
-- getTargets - returns the names of the assets conforming to the asset
--   type filter list, the caller must use AssetManager:get() to obtain
--   the actual asset object.
-- assettypelist - a list of asset types wanted to be included
-- requestingside - the coalition requesting the target list, thus
--     we need to return their enemy asset list
-- Return: return a table that lists the asset names that fit the
--    filter list requested
--]]
function AssetManager:getTargets(requestingside, assettypelist)
	local enemy = dctutils.getenemy(requestingside)
	local tgtlist = {}
	local filterlist

	-- some sides may not have enemies, return an empty target list
	-- in this case
	if enemy == false then
		return {}
	end

	if type(assettypelist) == "table" then
		filterlist = assettypelist
	elseif type(assettypelist) == "number" then
		filterlist = {}
		filterlist[assettypelist] = true
	else
		assert(false, "value error: assettypelist must be a number or table")
	end

	for tgtname, tgttype in pairs(self._sideassets[enemy].assets) do
		if filterlist[tgttype] ~= nil and
		   not self._assetset[tgtname].ignore then
			tgtlist[tgtname] = tgttype
		end
	end
	return tgtlist
end

function AssetManager:update()
	local deletionq = {}
	for _, asset in pairs(self._assetset) do
		if type(asset.update) == "function" then
			asset:update()
		end
		if asset:isDead() then
			deletionq[asset.name] = true
		end
	end
	for name, _ in pairs(deletionq) do
		self:remove(self:getAsset(name))
	end
	return self.updaterate
end

local function handleDead(self, event)
	self._object2asset[tostring(event.initiator:getName())] = nil
end

local function handleAssetDeath(self, event)
	local asset = event.initiator
	dct.Theater.singleton():getTickets():loss(asset.owner,
		asset.cost, false)
	if asset.type ~= enum.assetType.PLAYERGROUP then
		self:remove(asset)
	end
end

local handlers = {
	[world.event.S_EVENT_DEAD] = handleDead,
	[enum.event.DCT_EVENT_DEAD] = handleAssetDeath,
}

function AssetManager:doOneObject(obj, event)
	if event.id > world.event.S_EVENT_MAX then
		return
	end

	local name = tostring(obj:getName())
	if obj:getCategory() == Object.Category.UNIT then
		name = obj:getGroup():getName()
	end

	local assetname = self._object2asset[name]
	if assetname == nil then
		Logger:debug("onDCSEvent - not tracked object, obj name: "..name)
		return
	end
	local asset = self:getAsset(assetname)
	if asset == nil then
		Logger:debug("onDCSEvent - asset doesn't exist, name: "..assetname)
		self._object2asset[name] = nil
		return
	end
	asset:onDCTEvent(event)
end

function AssetManager:onDCSEvent(event)
	local relevents = {
		[world.event.S_EVENT_BIRTH]           = true,
		[world.event.S_EVENT_ENGINE_STARTUP]  = true,
		[world.event.S_EVENT_ENGINE_SHUTDOWN] = true,
		[world.event.S_EVENT_TAKEOFF]         = true,
		[world.event.S_EVENT_LAND]            = true,
		[world.event.S_EVENT_CRASH]           = true,
		[world.event.S_EVENT_KILL]            = true,
		[world.event.S_EVENT_PILOT_DEAD]      = true,
		[world.event.S_EVENT_EJECTION]        = true,
		[world.event.S_EVENT_HIT]             = true,
		[world.event.S_EVENT_DEAD]            = true,
		[enum.event.DCT_EVENT_DEAD]           = true,
		--[world.event.S_EVENT_UNIT_LOST]     = true,
	}
	local objmap = {
		[world.event.S_EVENT_HIT]  = "target", -- type: Object
		[world.event.S_EVENT_KILL] = "target", -- type: Unit
		[world.event.S_EVENT_LAND] = "place", -- type: Object
		[world.event.S_EVENT_TAKEOFF] = "place", -- type: Object
	}

	if not relevents[event.id] then
		Logger:debug("onDCSEvent - not relevent event: "..
			tostring(event.id))
		return
	end

	local objs = { event.initiator }
	if objmap[event.id] ~= nil then
		if event[objmap[event.id]] ~= nil then
			table.insert(objs, event[objmap[event.id]])
		end
	end

	for _, obj in ipairs(objs) do
		self:doOneObject(obj, event)
	end
	local handler = handlers[event.id]
	if handler ~= nil then
		handler(self, event)
	end
end

function AssetManager:marshal()
	local tbl = {
		["assets"] = {},
	}

	for name, asset in pairs(self._assetset) do
		if type(asset.marshal) == "function" and not asset:isDead() then
			tbl.assets[name] = asset:marshal()
		end
	end
	return tbl
end

function AssetManager:unmarshal(data)
	local spawnq = {}
	for _, assettbl in pairs(data.assets) do
		local assettype = assettbl.type
		local asset = self:factory(assettype)()
		asset:unmarshal(assettbl)
		self:add(asset)
		if asset:isSpawned() then
			spawnq[asset.name] = true
		end
	end

	for assetname, _ in pairs(spawnq) do
		self:getAsset(assetname):spawn(true)
	end
end

return AssetManager
