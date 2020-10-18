--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides config facilities.
--]]

local utils      = require("libs.utils")
local enum       = require("dct.enum")
local dctutils   = require("dct.utils")

local function validate_weapon_restrictions(cfgdata, tbl)
	local path = cfgdata.file
	local keys = {
		[1] = {
			["name"] = "cost",
			["type"] = "number",
		},
		[2] = {
			["name"] = "category",
			["type"] = "string",
			["check"] = function (keydata, t)
		if enum.weaponCategory[string.upper(t[keydata.name])] ~= nil then
			t[keydata.name] =
				enum.weaponCategory[string.upper(t[keydata.name])]
			return true
		end
		return false
	end,
		},
	}
	for _, wpndata in pairs(tbl) do
		wpndata.path = path
		utils.checkkeys(keys, wpndata)
		wpndata.path = nil
	end
	return tbl
end

local function validate_payload_limits(cfgdata, tbl)
	local newlimits = {}
	for wpncat, val in pairs(tbl) do
		local w = enum.weaponCategory[string.upper(wpncat)]
		assert(w ~= nil,
			string.format("invalid weapon category '%s'; file: %s",
				wpncat, cfgdata.file))
		newlimits[w] = val
	end
	return newlimits
end

local function validate_codenamedb(cfgdata, tbl)
	local newtbl = {}
	for key, list in pairs(tbl) do
		local newkey
		assert(type(key) == "string",
			string.format("invalid codename category '%s'; file: %s",
			key, cfgdata.file))

		local k = enum.assetType[string.upper(key)]
		if k ~= nil then
			newkey = k
		elseif key == "default" then
			newkey = key
		else
			assert(nil,
				string.format("invalid codename category '%s'; file: %s",
				key, cfgdata.file))
		end
		assert(type(list) == "table",
			string.format("invalid codename value for category "..
				"'%s', must be a table; file: %s", key, cfgdata.file))
		newtbl[newkey] = list
	end
	return newtbl
end

local function checkgridfmt(fmttbl, file)
	for actype, gridfmt in pairs(fmttbl) do
		local fmt = dctutils.posfmt[string.upper(gridfmt)]
		assert(fmt ~= nil,
			string.format("invalid grid format '%s'; file: %s",
				actype, file))
		fmttbl[actype] = fmt
	end
end

local function validate_ui(cfgdata, tbl)
	local newtbl = {}
	utils.mergetables(newtbl, cfgdata.default)
	for k, v in pairs(tbl) do
		if k == "" then
			checkgridfmt(v, cfgdata.file)
		else
			utils.mergetables(newtbl[k], v)
		end
	end
	return newtbl
end

--[[
-- We have a few levels of configuration:
-- 	* server defined config file; <dcs-saved-games>/Config/dct.cfg
-- 	* theater defined configuration; <theater-path>/settings/<config-files>
-- 	* default config values
-- simple algorithm; assign the defaults, then apply the server and
-- theater configs
--]]
local function theatercfgs(config)
	local defaultpayload = {}
	for _,v in pairs(enum.weaponCategory) do
		defaultpayload[v] = enum.WPNINFCOST - 1
	end

	local cfgs = {
		{
			["name"] = "restrictedweapons",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."restrictedweapons.cfg",
			["cfgtblname"] = "restrictedweapons",
			["validate"] = validate_weapon_restrictions,
			["default"] = {
				["RN-24"] = {
					["cost"]     = enum.WPNINFCOST,
					["category"] = enum.weaponCategory.AG,
				},
				["RN-28"] = {
					["cost"]     = enum.WPNINFCOST,
					["category"] = enum.weaponCategory.AG,
				},
			},
		},
		{
			["name"] = "payloadlimits",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."payloadlimits.cfg",
			["cfgtblname"] = "payloadlimits",
			["validate"] = validate_payload_limits,
			["default"] = defaultpayload,
		},
		{
			["name"] = "codenamedb",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."codenamedb.cfg",
			["cfgtblname"] = "codenamedb",
			["validate"] = validate_codenamedb,
			["default"] = require("dct.data.codenamedb"),
		},
		{
			["name"] = "ui",
			["file"] = config.server.theaterpath..utils.sep.."settings"..
				utils.sep.."ui.cfg",
			["cfgtblname"] = "dctui",
			["validate"] = validate_ui,
			["default"] = {
				["gridfmt"] = {
					-- default is DMS, no need to list
					["Ka-50"]         = dctutils.posfmt.DDM,
					["Mi-8MT"]        = dctutils.posfmt.DDM,
					["SA342M"]        = dctutils.posfmt.DDM,
					["SA342L"]        = dctutils.posfmt.DDM,
					["UH-1H"]         = dctutils.posfmt.DDM,
					["A-10A"]         = dctutils.posfmt.MGRS,
					["A-10C"]         = dctutils.posfmt.MGRS,
					["A-10C_2"]       = dctutils.posfmt.MGRS,
					["AV8BNA"]        = dctutils.posfmt.DDM,
					["F-5E-3"]        = dctutils.posfmt.DDM,
					["F-16C_50"]      = dctutils.posfmt.DDM,
					["FA-18C_hornet"] = dctutils.posfmt.DDM,
					["M-2000C"]       = dctutils.posfmt.DDM,
				},
			},
		},
	}

	utils.readconfigs(cfgs, config)
	return config
end

return theatercfgs
