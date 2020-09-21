--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- common utility functions
--]]

require("os")
require("math")
local enum  = require("dct.enum")
local utils = {}

local enemymap = {
	[coalition.side.NEUTRAL] = false,
	[coalition.side.BLUE]    = coalition.side.RED,
	[coalition.side.RED]     = coalition.side.BLUE,
}

utils.INTELMAX = 5

function utils.getenemy(side)
	return enemymap[side]
end

local function errorhandler(key, m, path)
	local msg = string.format("%s: %s; file: %s",
		key, m, path or "nil")
	error(msg, 2)
end

function utils.checkkeys(keys, tbl)
	for _, keydata in ipairs(keys) do
		if keydata.default == nil and tbl[keydata.name] == nil then
			errorhandler(keydata.name, "missing required key", tbl.path)
		elseif keydata.default ~= nil and tbl[keydata.name] == nil then
			tbl[keydata.name] = keydata.default
		else
			if type(tbl[keydata.name]) ~= keydata.type then
				errorhandler(keydata.name, "invalid key value", tbl.path)
			end

			if type(keydata.check) == "function" and
				not keydata.check(keydata, tbl) then
				errorhandler(keydata.name, "invalid key value", tbl.path)
			end
		end
	end
end

function utils.isalive(grpname)
	local grp = Group.getByName(grpname)
	return (grp and grp:isExist() and grp:getSize() > 0)
end

function utils.getkey(tbl, val)
	for k, v in pairs(tbl) do
		if v == val then
			return k
		end
	end
	return nil
end

function utils.interp(s, tab)
	return (s:gsub('(%b%%)', function(w) return tab[w:sub(2,-2)] or w end))
end

function utils.assettype2mission(assettype)
	for k, v in pairs(enum.missionTypeMap) do
		if v[assettype] then
			return k
		end
	end
	return nil
end

local airbase_id2name_map = nil
function utils.airbaseId2Name(id)
	if id == nil then
		return nil
	end
	if airbase_id2name_map == nil then
		for _, ab in pairs(coalition.getAirbases()) do
			airbase_id2name_map[ab:getID()] = ab:getName()
		end
	end
	return airbase_id2name_map[id]
end

function utils.time(dcsabstime)
	local time = os.time({
		["year"]  = env.mission.date.Year,
		["month"] = env.mission.date.Month,
		["day"]   = env.mission.date.Day,
		["hour"]  = 0,
		["min"]   = 0,
		["sec"]   = 0,
		["isdst"] = false,
	})
	return time + timer.getTime0() + dcsabstime
end

local offsettbl = {
	["Test Theater"] = -6*3600,
	["PersianGulf"]  = -4*3600,
	["Nevada"]       =  8*3600,
	["Caucuses"]     = -4*3600,
	["Normandy"]     =  1*3600,
}

function utils.zulutime(abstime)
	local correction = offsettbl[env.mission.theatre]
	return (utils.time(abstime) + correction)
end

local dst
function utils.date(fmt, time)
	if dst == nil then
		local t = os.date("*t")
		dst = t.isdst
	end

	if dst == true then
		time = time - 3600
	end
	return os.date(fmt, time)
end

--[[
function utils.centroid(points)
	local i = 0
	local centroid = {
		["x"] = 0, ["y"] = 0, ["z"] = 0,
	}
	for _,v in pairs(points) do
		if v.x then
			centroid.x = centroid.x + v.x
		end
		if v.y then
			centroid.y = centroid.y + v.y
		end
		if v.z then
			centroid.z = centroid.z + v.z
		end
		i = i + 1
	end
	centroid.x = centroid.x / i
	centroid.y = centroid.y / i
	centroid.z = centroid.z / i
	return centroid
end
--]]

function utils.createVec2(vec3)
	if vec3.z then
		return {["x"] = vec3.x, ["y"] = vec3.z}
	end
	return {["x"] = vec3.x, ["y"] = vec3.y}
end

function utils.createVec3(vec2, height)
	if vec2.z then
		return {["x"] = vec2.x, ["y"] = vec2.y, ["z"] = vec2.z}
	end
	local h = height or vec2.alt or 0
	return {["x"] = vec2.x, ["y"] = h, ["z"] = vec2.y}
end

function utils.centroid(point, pcentroid, n)
	if pcentroid == nil or n == nil then
		return {["x"] = point.x, ["y"] = point.y, ["z"] = point.z,}, 1
	end

	local centroid = {}
	local n1 = n + 1
	local x = point.x or 0
	local y = point.y or 0
	local z = point.z or point.alt or 0
	pcentroid = {
		["x"] = pcentroid.x or 0,
		["y"] = pcentroid.y or 0,
		["z"] = pcentroid.z or 0,
	}
	centroid.x = (x + (n * pcentroid.x))/n1
	centroid.y = (y + (n * pcentroid.y))/n1
	centroid.z = (z + (n * pcentroid.z))/n1
	return centroid, n1
end

-- TODO: test point in rectangle
-- given: a rectangle with points A, B & C defined in an x,y plane
--        where, B is the point at the 90-deg angle
--
--        -and-
--
--        Let M represent the sample point (x,y),
--        Then, M is inside the rectangle iff
--          (0 < AM * AB < AB * AB) and (0 < AM * AC < AC * AC)
--          where, '*' represents the saclar dot product of the two
--          vectors created by points describing each line segment.
--
-- references:
-- https://math.stackexchange.com/questions/190111/how-to-check-if-a-point-is-inside-a-rectangle
-- https://stackoverflow.com/questions/2752725/finding-whether-a-point-lies-inside-a-rectangle-or-not
--
-- This allows for the creation of runway strike missions by letting DCT
-- define runway geometry and then determining if a weapon impacts inside
-- this geometry.


utils.posfmt = {
	["DD"]   = 1,
	["DDM"]  = 2,
	["DMS"]  = 3,
	["MGRS"] = 4,
}

function utils.LLtostring(lat, long, precision, fmt)
	-- reduce the accuracy of the position to the precision specified
	lat  = tonumber(string.format("%0"..(3+precision).."."..precision.."f",
		lat))
	long = tonumber(string.format("%0"..(3+precision).."."..precision.."f",
		long))

	local northing = "N"
	local easting  = "E"
	local degsym   = '°'

	if fmt == utils.posfmt.DDM then
		if precision > 1 then
			precision = precision - 1
		else
			precision = 0
		end
	elseif fmt == utils.posfmt.DMS then
		if precision > 2 then
			precision = precision - 2
		else
			precision = 0
		end
	end

	local width  = 3 + precision
	local fmtstr = "%0"..width

	if precision == 0 then
		fmtstr = fmtstr.."d"
	else
		fmtstr = fmtstr.."."..precision.."f"
	end

	if lat < 0 then
		northing = "S"
	end

	if long < 0 then
		easting = "W"
	end

	lat  = math.abs(lat)
	long = math.abs(long)

	if fmt == utils.posfmt.DD then
		return string.format(fmtstr..degsym, lat)..northing..
			" "..
			string.format(fmtstr..degsym, long)..easting
	end

	local latdeg   = math.floor(lat)
	local latmind  = (lat - latdeg)*60
	local longdeg  = math.floor(long)
	local longmind = (long - longdeg)*60

	if fmt == utils.posfmt.DDM then
		return string.format("%02d"..degsym..fmtstr.."'", latdeg, latmind)..
			northing..
			" "..
			string.format("%03d"..degsym..fmtstr.."'", longdeg, longmind)..
			easting
	end

	local latmin   = math.floor(latmind)
	local latsecd  = (latmind - latmin)*60
	local longmin  = math.floor(longmind)
	local longsecd = (longmind - longmin)*60

	return string.format("%02d"..degsym.."%02d'"..fmtstr.."\"",
			latdeg, latmin, latsecd)..
		northing..
		" "..
		string.format("%03d"..degsym.."%02d'"..fmtstr.."\"",
			longdeg, longmin, longsecd)..
		easting
end

function utils.MGRStostring(mgrs, precision)
	local str = mgrs.UTMZone .. " " .. mgrs.MGRSDigraph

	if precision == 0 then
		return str
	end

	local divisor = 10^(5-precision)
	local fmtstr  = "%0"..precision.."d"
	return str .. string.format(fmtstr, (mgrs.Easting/divisor)) ..
		string.format(fmtstr, (mgrs.Northing/divisor))
end

function utils.degrade_position(position, precision)
	local lat, long = coord.LOtoLL(position)
	lat  = tonumber(string.format("%0"..(3+precision).."."..precision.."f",
		lat))
	long = tonumber(string.format("%0"..(3+precision).."."..precision.."f",
		long))
	return coord.LLtoLO(lat, long, 0)
end

function utils.fmtposition(position, precision, fmt)
	precision = math.floor(precision)
	assert(precision >= 0 and precision <= 5,
		"value error: precision range [0,5]")
	local lat, long = coord.LOtoLL(position)

	if fmt == utils.posfmt.MGRS then
		return utils.MGRStostring(coord.LLtoMGRS(lat, long),
			precision)
	end

	return utils.LLtostring(lat, long, precision, fmt)
end

return utils
