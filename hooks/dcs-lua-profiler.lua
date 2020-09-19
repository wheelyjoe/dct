--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Generic LUA profiling for DCS
--
-- This script is intended to be put into the hooks directory.
-- It allows a mission designer and script writer to profile
-- their code in a generic and unobtrusive way.
--
-- Inspired from the MOOSE PROFILER for DCS.
--]]

-- luacheck: read_globals log DCS net

require("os")
require("io")
local PROFILEENABLE = false

-- Integrate with DCT if installed
--[[
-- TODO: uncomment when DCT supports pulling in settings for only the
-- server config.
local modpath = lfs.writedir() .. "Mods\\tech\\DCT"
if lfs.attributes(modpath) == nil then
	package.path = package.path .. ";" .. modpath .. "\\lua\\?.lua"
	local settings = require("dct.settings")()
	PROFILEENABLE = settings.server.profile
end
--]]

local facility = "[LUAPROFILE]"

local function rpc_set_hook()
	local cmd = [[
		local debug_hook = function(why)
			local f = debug.getinfo(2, "f").func
			local pdata = _G.dctprofiler.pdata
			local add = function(base, val)
				base = base + val
				return base
			end

			if why == "call" then
				if pdata[f] == nil then
					pdata[f] = {
						["tottime"] = 0,
						["dinfo"]   = debug.getinfo(2, "Sn"),
						["called"]  = 1,
						["nopen"]   = 1,
						["ctime"]   = os.clock(),
					}
				else
					if pdata[f].ctime == nil then
						pdata[f].ctime = os.clock()
					end
					add(pdata[f].nopen, 1)
					add(pdata[f].called, 1)
				end
			elseif why == "return" then
				add(pdata[f].nopen, -1)
				if pdata[f].nopen == 0 then
					add(pdata[f].tottime, os.clock() - pdata[f].ctime)
					pdata[f].ctime = nil
				end
			end
		end
		debug.sethook(debug_hook, "cr")
	]]
	return cmd
end

local function rpc_export_profile_data()
	local cmd = [[
		return _G.json:encode(_G.dctprofiler)
	]]
	return cmd
end

local function rpc_meet_requirements(jsonpath)
	local cmd = [[
		local function check()
			if not os then
				log.error("DCTProfiler: os library not available")
				return 0
			end

			if not debug then
				log.error("DCTProfiler: debug library not available")
				return 0
			end

			local ok, json = pcall(dofile, "]]..jsonpath..[[")
			if not ok then
				log.error("DCTProfiler: failed to load json library: "..
					tostring(json))
				return 0
			end
			_G.json = json
			_G.dctprofiler = {}
			_G.dctprofiler.pdata = {}
			return 1
		end
		return check()
	]]
	return cmd
end

-- Returns: nil on error otherwise data in the requested type
local function do_rpc(ctx, cmd, valtype)
	local status, errmsg = net.dostring_in(ctx, cmd)

	if not status then
		log.write(facility, log.ERROR,
			string.format("rpc failed in context(%s): %s", ctx, errmsg))
		return
	end

	local val
	if valtype == "number" or valtype == "boolean" then
		val = tonumber(status)
	elseif valtype == "string" then
		val = status
	else
		log.write(facility, log.ERROR,
			string.format("rpc unsupported type(%s)", valtype))
		val = nil
	end
	return val
end


local DCTProfiler = {}
DCTProfiler.loadhook = false

function DCTProfiler:onMissionLoadEnd()
	if not PROFILEENABLE then
		return
	end
	self.loadhook    = true
	self.missionname = DCS.getMissionName()
	self.theater     = DCS.getCurrentMission().mission.theatre
	self.stime       = os.date("!%Y%m%d_%H:%M:%S")
end

function DCTProfiler:onSimulationResume()
	if not loadhook then
		return
	end

	local jsonpath = lfs.currentdir().."Scripts\\JSON.lua"
	local ok = do_rpc('server', rpc_meet_requirements(jsonpath), "number")
	if ok == nil or ok == 0 then
		log.write(facility, log.ERROR,
			"mission environment requirements not met")
		return
	end
	do_rpc('server', rpc_set_hook, "number")
end

function DCTProfiler:onGameEvent(event)
	if event ~= "mission_end" then
		return
	end
	local result = do_rpc('server', rpc_export_profile_data(), "string")
	if result == nil then
		return
	end
	local f, ok, errmsg
	local filepath = lfs.writedir().."Logs\\"..stime.."-"..theater..
		"-"..missionname..".json"
	f, errmsg = io.open(filepath, 'w')
	if not f then
		log.write(facility, log.ERROR, string.format(
			"unable to open file(%s): %s", filepath, tostring(errmsg)))
		return
	end
	ok, errmsg = f:write(result)
	if not ok then
		log.write(facility, log.ERROR, string.format(
			"unable to write file(%s): %s", filepath, tostring(errmsg)))
	end
	f:close()
end

local function dct_call_hook(hook, ...)
	local status, result = pcall(hook, ...)
	if not status then
		log.write(facility, log.ERROR,
			string.format("call to hook failed; %s\n%s",
				result, debug.traceback()))
		return
	end
	return result
end

local function dct_profiler_load()
	local handler = {}
	function handler.onMissionLoadEnd()
		dct_call_hook(DCTProfiler.onMissionLoadEnd, DCTProfiler)
	end
	function handler.onSimulationResume()
		dct_call_hook(DCTProfiler.onSimulationResume, DCTProfiler)
	end
	function handler.onGameEvent(event)
		dct_call_hook(DCTProfiler.onGameEvent, DCTProfiler)
	end
	DCS.setUserCallbacks(DCTProfiler)
	log.write(facility, log.INFO, "Hooks Loaded")
end

local status, errmsg = pcall(dct_profiler_load)
if not status then
	log.write(facility, log.ERROR, "Load Error: "..tostring(errmsg))
end
