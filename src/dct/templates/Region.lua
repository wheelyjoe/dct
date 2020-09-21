--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the Region class.
--]]

require("lfs")
require("math")
local class      = require("libs.class")
local utils      = require("libs.utils")
local dctenums   = require("dct.enum")
local dctutils   = require("dct.utils.utils")
local Template   = require("dct.templates.Template")
local Asset      = require("dct.assets.Asset")
local Logger     = require("dct.utils.Logger").getByName("Region")

local tplkind = {
	["TEMPLATE"]  = 1,
	["EXCLUSION"] = 2,
}

local function processlimits(_, tbl)
	-- process limits; convert the human readable asset type names into
	-- their numerical equivalents.
	local limits = {}
	for key, data in pairs(tbl.limits) do
		local typenum = dctenums.assetType[string.upper(key)]
		if typenum == nil then
			Logger:warn("invalid asset type '"..key..
				"' found in limits definition in file: "..
				tbl.defpath or "nil")
		else
			limits[typenum] = data
		end
	end
	tbl.limits = limits
	return true
end

local function loadMetadata(self, regiondefpath)
	Logger:debug("=> regiondefpath: "..regiondefpath)
	local keys = {
		[1] = {
			["name"] = "name",
			["type"] = "string",
		},
		[2] = {
			["name"] = "priority",
			["type"] = "number",
		},
		[3] = {
			["name"] = "limits",
			["type"] = "table",
			["default"] = {},
			["check"] = processlimits,
		},
		[4] = {
			["name"] = "airspace",
			["type"] = "boolean",
			["default"] = true,
		},
	}

	local region = utils.readlua(regiondefpath, "region")
	region.defpath = regiondefpath
	dctutils.checkkeys(keys, region)
	utils.mergetables(self, region)
end

local function getTemplates(self, dirname, basepath)
	local tplpath = basepath .. "/" .. dirname
	Logger:debug("=> tplpath: "..tplpath)

	for filename in lfs.dir(tplpath) do
		if filename ~= "." and filename ~= ".." then
			local fpath = tplpath .. "/" .. filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				getTemplates(self, filename, tplpath)
			else
				if string.find(fpath, ".dct", -4, true) ~= nil then
					Logger:debug("=> process template: "..fpath)
					local stmpath = string.gsub(fpath, "[.]dct", ".stm")
					if lfs.attributes(stmpath) == nil then
						stmpath = nil
					end
					self:addTemplate(
						Template.fromFile(self.name, fpath, stmpath))
				end
			end
		end
	end
end

local function loadTemplates(self)
	for filename in lfs.dir(self.path) do
		if filename ~= "." and filename ~= ".." then
			local fpath = self.path.."/"..filename
			local fattr = lfs.attributes(fpath)
			if fattr.mode == "directory" then
				getTemplates(self, filename, self.path)
			end
		end
	end
end

local function createExclusion(self, tpl)
	self._exclusions[tpl.exclusion] = {
		["ttype"] = tpl.objtype,
		["names"] = {},
	}
end

local function registerExclusion(self, tpl)
	assert(tpl.objtype == self._exclusions[tpl.exclusion].ttype,
	       "exclusions across objective types not allowed, '"..
	       tpl.name.."'")
	table.insert(self._exclusions[tpl.exclusion].names,
	             tpl.name)
end

local function registerType(self, kind, ttype, name)
	local entry = {
		["kind"] = kind,
		["name"] = name,
	}

	if self._tpltypes[ttype] == nil then
		self._tpltypes[ttype] = {}
	end
	table.insert(self._tpltypes[ttype], entry)
end

local function addAndSpawnAsset(self, name, assetmgr, centroids)
	if name == nil then
		return nil
	end

	local tpl = self:getTemplateByName(name)
	if tpl == nil then
		return nil
	end

	local asset = Asset.factory(tpl, self)
	assetmgr:add(asset)
	asset:spawn()
	asset:generate(assetmgr, self)
	if centroids then
		table.insert(centroids, asset:getLocation())
	end
	return asset
end

--[[
--  Region class
--    base class that reads in a region definition.
--
--    properties
--    ----------
--      * name
--      * priority
--
--    Storage
--    -------
--		_templates   = {
--			["<tpl-name>"] = Template(),
--		},
--		_tpltypes    = {
--			<ttype> = {
--				[#] = {
--					kind = tpl | exclusion,
--					name = "<tpl-name>" | "<ex-name>",
--				},
--			},
--		},
--		_exclusions  = {
--			["<ex-name>"] = {
--				ttype = <ttype>,
--				names = {
--					[#] = ["<tpl-name>"],
--				},
--			},
--		}
--
--    region.def File
--    ---------------
--      Required Keys:
--        * priority - how high in the targets from this region will be
--				ordered
--        * name - the name of the region, mainly used for debugging
--
--      Optional Keys:
--        * limits - a table defining the minimum and maximum number of
--              assets to spawn from a given asset type
--              [<objtype>] = { ["min"] = <num>, ["max"] = <num>, }
--]]
local Region = class()
function Region:__init(regionpath)
	self.path          = regionpath
	self._templates    = {}
	self._tpltypes     = {}
	self._exclusions   = {}
	Logger:debug("=> regionpath: "..regionpath)
	loadMetadata(self, regionpath..utils.sep.."region.def")
	loadTemplates(self)
end

function Region:addTemplate(tpl)
	assert(self._templates[tpl.name] == nil,
		"duplicate template '"..tpl.name.."' defined; "..tostring(tpl.path))
	self._templates[tpl.name] = tpl
	if tpl.exclusion ~= nil then
		if self._exclusions[tpl.exclusion] == nil then
			createExclusion(self, tpl)
			registerType(self, tplkind.EXCLUSION,
				tpl.objtype, tpl.exclusion)
		end
		registerExclusion(self, tpl)
	else
		registerType(self, tplkind.TEMPLATE, tpl.objtype, tpl.name)
	end
end

function Region:getTemplateByName(name)
	return self._templates[name]
end

function Region:_generate(assetmgr, objtype, names, centroids)
	local limits = {
		["min"]     = #names,
		["max"]     = #names,
		["limit"]   = #names,
		["current"] = 0,
	}

	if self.limits and self.limits[objtype] then
		limits.min   = self.limits[objtype].min
		limits.max   = self.limits[objtype].max
		limits.limit = math.random(limits.min, limits.max)
	end

	for i, tpl in ipairs(names) do
		if tpl.kind ~= tplkind.EXCLUSION and
			self._templates[tpl.name].spawnalways == true then
			addAndSpawnAsset(self, tpl.name, assetmgr, centroids)
			table.remove(names, i)
			limits.current = 1 + limits.current
		end
	end

	while #names >= 1 and limits.current < limits.limit do
		local idx  = math.random(1, #names)
		local name = names[idx].name
		if names[idx].kind == tplkind.EXCLUSION then
			local i = math.random(1, #self._exclusions[name].names)
			name = self._exclusions[name]["names"][i]
		end
		addAndSpawnAsset(self, name, assetmgr, centroids)
		table.remove(names, idx)
		limits.current = 1 + limits.current
	end
end

-- generates all "strategic" assets for a region from
-- a spawn format (limits). We then immediatly register
-- that asset with the asset manager (provided) and spawn
-- the asset into the game world. Region generation should
-- be limited to mission startup.
function Region:generate(assetmgr)
	local tpltypes = utils.deepcopy(self._tpltypes)
	local centroidpoints = {}

	for objtype, _ in pairs(dctenums.assetClass["STRATEGIC"]) do
		local names = tpltypes[objtype]
		if names ~= nil then
			self:_generate(assetmgr, objtype, names, centroidpoints)
		end
	end

	-- do not create an airspace object if not wanted
	if self.airspace ~= true then
		return
	end

	-- create airspace asset based on the centroid of this region
	self.location = dctutils.centroid(centroidpoints)
	local airspacetpl = Template({
		["objtype"]    = "airspace",
		["name"]       = "airspace",
		["regionname"] = self.name,
		["desc"]       = "airspace",
		["coalition"]  = coalition.side.NEUTRAL,
		["location"]   = self.location,
		["volume"]     = {
			["point"]  = self.location,
			["radius"] = 55560,  -- 30NM
		},
	})
	self:addTemplate(airspacetpl)
	addAndSpawnAsset(self, airspacetpl.name, assetmgr)
end

return Region
