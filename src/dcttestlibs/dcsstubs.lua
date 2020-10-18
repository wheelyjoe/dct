--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Provides DCS stubs for the mission scripting environment.
--]]

require("os")
local utils = require("libs.utils")

require("lfs")
lfs.dct_testdata = os.getenv("DCT_DATA_ROOT") or "."
function lfs.writedir()
	return lfs.dct_testdata
end

function lfs.tempdir()
	return lfs.dct_testdata .. utils.sep .. "mission"
end
local class = require("libs.class")

local dctcheck = {}
dctcheck.spawngroups  = 0
dctcheck.spawnstatics = 0
_G.dctcheck = dctcheck

-- DCS Singletons
--

local objectcat = {
	["UNIT"]    = 1,
	["WEAPON"]  = 2,
	["STATIC"]  = 3,
	["BASE"]    = 4,
	["SCENERY"] = 5,
	["CARGO"]   = 6,
	-- not actuall part of DCS
	["GROUP"] = 7,
}

local env = {}
env.mission = utils.readlua(lfs.tempdir()..utils.sep.."mission", "mission")
env.mission.theatre = "Test Theater"
env.mission.sortie  = "test mission"
env.mission.date = {
	["Year"]  = 2001,
	["Month"] = 6,
	["Day"]   = 22,
}
local dictkeys = utils.readlua(lfs.tempdir()..utils.sep..
	table.concat({"l10n", "DEFAULT", "dictionary"}, utils.sep), "dictionary")
function env.getValueDictByKey(s)
	local r = dictkeys[s]
	if r ~= nil then
		return r
	end
	return s
end

function env.warning(msg, _)
	print("WARN: "..msg)
end
function env.info(msg, _)
	print("INFO: "..msg)
end
function env.error(msg, _)
	print("ERROR: "..msg)
end
_G.env = env

local timer = {}
function timer.getTime()
	return os.clock()
end
function timer.getAbsTime()
	return (2*3600)+234
end
function timer.getTime0()
	return 15*3600
end
function timer.scheduleFunction(_, _, _)
end
_G.timer = timer

local country = {}
country.id = {
	["RUSSIA"]                  = 0,
	["UKRAINE"]                 = 1,
	["USA"]                     = 2,
	["TURKEY"]                  = 3,
	["UK"]                      = 4,
	["FRANCE"]                  = 5,
	["GERMANY"]                 = 6,
	["AGGRESSORS"]              = 7,
	["CANADA"]                  = 8,
	["SPAIN"]                   = 9,
	["THE_NETHERLANDS"]         = 10,
	["BELGIUM"]                 = 11,
	["NORWAY"]                  = 12,
	["DENMARK"]                 = 13,
	["ISRAEL"]                  = 15,
	["GEORGIA"]                 = 16,
	["INSURGENTS"]              = 17,
	["ABKHAZIA"]                = 18,
	["SOUTH_OSETIA"]            = 19,
	["ITALY"]                   = 20,
	["AUSTRALIA"]               = 21,
	["SWITZERLAND"]             = 22,
	["AUSTRIA"]                 = 23,
	["BELARUS"]                 = 24,
	["BULGARIA"]                = 25,
	["CHEZH_REPUBLIC"]          = 26,
	["CHINA"]                   = 27,
	["CROATIA"]                 = 28,
	["EGYPT"]                   = 29,
	["FINLAND"]                 = 30,
	["GREECE"]                  = 31,
	["HUNGARY"]                 = 32,
	["INDIA"]                   = 33,
	["IRAN"]                    = 34,
	["IRAQ"]                    = 35,
	["JAPAN"]                   = 36,
	["KAZAKHSTAN"]              = 37,
	["NORTH_KOREA"]             = 38,
	["PAKISTAN"]                = 39,
	["POLAND"]                  = 40,
	["ROMANIA"]                 = 41,
	["SAUDI_ARABIA"]            = 42,
	["SERBIA"]                  = 43,
	["SLOVAKIA"]                = 44,
	["SOUTH_KOREA"]             = 45,
	["SWEDEN"]                  = 46,
	["SYRIA"]                   = 47,
	["YEMEN"]                   = 48,
	["VIETNAM"]                 = 49,
	["VENEZUELA"]               = 50,
	["TUNISIA"]                 = 51,
	["THAILAND"]                = 52,
	["SUDAN"]                   = 53,
	["PHILIPPINES"]             = 54,
	["MOROCCO"]                 = 55,
	["MEXICO"]                  = 56,
	["MALAYSIA"]                = 57,
	["LIBYA"]                   = 58,
	["JORDAN"]                  = 59,
	["INDONESIA"]               = 60,
	["HONDURAS"]                = 61,
	["ETHIOPIA"]                = 62,
	["CHILE"]                   = 63,
	["BRAZIL"]                  = 64,
	["BAHRAIN"]                 = 65,
	["THIRDREICH"]              = 66,
	["YUGOSLAVIA"]              = 67,
	["USSR"]                    = 68,
	["ITALIAN_SOCIAL_REPUBLIC"] = 69,
	["ALGERIA"]                 = 70,
	["KUWAIT"]                  = 71,
	["QATAR"]                   = 72,
	["OMAN"]                    = 73,
	["UNITED_ARAB_EMIRATES"]    = 74,
}

country.name  = {}
country.names = {}
for k,v in pairs(country.id) do
	country.name[v] = k
	country.names[v] = string.gsub(k, "_", " ")
end
_G.country = country

local radio = {}
radio.modulation = {AM = 0, FM = 1}
_G.radio = radio

local coalition = {}
coalition.side = {}
coalition.side.NEUTRAL = 0
coalition.side.RED     = 1
coalition.side.BLUE    = 2

function coalition.getAirbases(_ --[[side]])
	return {}
end

function coalition.addGroup(cntryid, groupcat, groupdata)
	dctcheck.spawngroups = dctcheck.spawngroups + 1
	groupdata.country = cntryid
	groupdata.groupCategory = groupcat
	groupdata.exists = true
	local grp = Group(#groupdata.units, groupdata)
	for _, unitdata in pairs(groupdata.units) do
		unitdata.exists = true
		Unit(unitdata, grp)
	end
end

function coalition.addStaticObject(cntryid, groupdata)
	dctcheck.spawnstatics = dctcheck.spawnstatics + 1
	groupdata.country = cntryid
	groupdata.exists = true
	StaticObject(groupdata)
end

local coaltbl = {
	-- BLUE Coalition
	[21] = {
		["name"] = "Australia",
		["side"] = coalition.side.BLUE,
	},
	[11] = {
		["name"] = "Belgium",
		["side"] = coalition.side.BLUE,
	},
	[8] = {
		["name"] = "Canada",
		["side"] = coalition.side.BLUE,
	},
	[28] = {
		["name"] = "Croatia",
		["side"] = coalition.side.BLUE,
	},
	[26] = {
		["name"] = "Czech Republic",
		["side"] = coalition.side.BLUE,
	},
	[13] = {
		["name"] = "Denmark",
		["side"] = coalition.side.BLUE,
	},
	[5] = {
		["name"] = "France",
		["side"] = coalition.side.BLUE,
	},
	[16] = {
		["name"] = "Georgia",
		["side"] = coalition.side.BLUE,
	},
	[6] = {
        ["name"] = "Germany",
		["side"] = coalition.side.BLUE,
	},
	[15] = {
		["name"] = "Israel",
		["side"] = coalition.side.BLUE,
	},
	[20] = {
		["name"] = "Italy",
		["side"] = coalition.side.BLUE,
	},
	[12] = {
		["name"] = "Norway",
		["side"] = coalition.side.BLUE,
	},
	[40] = {
		["name"] = "Poland",
		["side"] = coalition.side.BLUE,
	},
	[45] = {
		["name"] = "South Korea",
		["side"] = coalition.side.BLUE,
	},
	[9] = {
		["name"] = "Spain",
		["side"] = coalition.side.BLUE,
	},
	[46] = {
		["name"] = "Sweden",
		["side"] = coalition.side.BLUE,
	},
	[10] = {
        ["name"] = "The Netherlands",
		["side"] = coalition.side.BLUE,
	},
	[3] = {
		["name"] = "Turkey",
		["side"] = coalition.side.BLUE,
	},
	[4] = {
        ["name"] = "UK",
		["side"] = coalition.side.BLUE,
	},
	[1] = {
		["name"] = "Ukraine",
		["side"] = coalition.side.BLUE,
	},
	[2] = {
		["name"] = "USA",
		["side"] = coalition.side.BLUE,
	},
	[73] = {
		["name"] = "Oman",
		["side"] = coalition.side.BLUE,
	},
	[74] = {
		["name"] = "UAE",
		["side"] = coalition.side.BLUE,
	},
	[39] = {
		["name"] = "Pakistan",
		["side"] = coalition.side.BLUE,
	},
	[35] = {
		["name"] = "Iraq",
		["side"] = coalition.side.BLUE,
	},
	[42] = {
		["name"] = "SAUDI_ARABIA",
		["side"] = coalition.side.BLUE,
	},

	-- RED Coalition
	[25] = {
		["name"] = "Bulgaria",
		["side"] = coalition.side.RED,
	},
	[18] = {
		["name"] = "Abkhazia",
		["side"] = coalition.side.RED,
	},
	[24] = {
		["name"] = "Belarus",
		["side"] = coalition.side.RED,
	},
	[27] = {
		["name"] = "China",
		["side"] = coalition.side.RED,
	},
	[34] = {
		["name"] = "Iran",
		["side"] = coalition.side.RED,
	},
	[37] = {
		["name"] = "Kazakhstan",
		["side"] = coalition.side.RED,
	},
	[38] = {
		["name"] = "North Korea",
		["side"] = coalition.side.RED,
	},
	[0] = {
		["name"] = "Russia",
		["side"] = coalition.side.RED,
	},
	[43] = {
		["name"] = "Serbia",
		["side"] = coalition.side.RED,
	},
	[19] = {
		["name"] = "South Ossetia",
		["side"] = coalition.side.RED,
	},
	[47] = {
		["name"] = "Syria",
		["side"] = coalition.side.RED,
	},
	[7] = {
		["name"] = "USAF Aggressors",
		["side"] = coalition.side.RED,
	},
	[17] = {
		["name"] = "Insurgents",
		["side"] = coalition.side.RED,
	},
	[71] = {
		["name"] = "Unknown-RED1",
		["side"] = coalition.side.RED,
	},
	[65] = {
		["name"] = "Unknown-RED2",
		["side"] = coalition.side.RED,
	},
	[72] = {
		["name"] = "Unknown-RED3",
		["side"] = coalition.side.RED,
	},
	[59] = {
		["name"] = "JORDAN",
		["side"] = coalition.side.RED,
	},
}

function coalition.getCountryCoalition(id)
	assert(coaltbl[id] ~= nil, "get country coalition id: "..id)
	return coaltbl[id]["side"]
end
_G.coalition = coalition

local world = {}
world.event = {
	["S_EVENT_INVALID"]           = 0,
	["S_EVENT_SHOT"]              = 1,
	["S_EVENT_HIT"]               = 2,
	["S_EVENT_TAKEOFF"]           = 3,
	["S_EVENT_LAND"]              = 4,
	["S_EVENT_CRASH"]             = 5,
	["S_EVENT_EJECTION"]          = 6,
	["S_EVENT_REFUELING"]         = 7,
	["S_EVENT_DEAD"]              = 8,
	["S_EVENT_PILOT_DEAD"]        = 9,
	["S_EVENT_BASE_CAPTURED"]     = 10,
	["S_EVENT_MISSION_START"]     = 11,
	["S_EVENT_MISSION_END"]       = 12,
	["S_EVENT_TOOK_CONTROL"]      = 13,
	["S_EVENT_REFUELING_STOP"]    = 14,
	["S_EVENT_BIRTH"]             = 15,
	["S_EVENT_HUMAN_FAILURE"]     = 16,
	["S_EVENT_DETAILED_FAILURE"]  = 17,
	["S_EVENT_ENGINE_STARTUP"]    = 18,
	["S_EVENT_ENGINE_SHUTDOWN"]   = 19,
	["S_EVENT_PLAYER_ENTER_UNIT"] = 20,
	["S_EVENT_PLAYER_LEAVE_UNIT"] = 21,
	["S_EVENT_PLAYER_COMMENT"]    = 22,
	["S_EVENT_SHOOTING_START"]    = 23,
	["S_EVENT_SHOOTING_END"]      = 24,
	["S_EVENT_MARK_ADDED"]        = 25,
	["S_EVENT_MARK_CHANGE"]       = 26,
	["S_EVENT_MARK_REMOVED"]      = 27,
	["S_EVENT_KILL"]              = 28,
	["S_EVENT_SCORE"]             = 29,
	["S_EVENT_UNIT_LOST"]         = 30,
	["S_EVENT_LANDING_AFTER_EJECTION"] = 31,
	["S_EVENT_RESERVED1"]         = 32,
	["S_EVENT_MAX"]               = 33,
}
function world.addEventHandler(_)
end
_G.world = world

-- DCS Classes
--

local objdefaults = {
	["name"] = "obj1",
	["exists"] = false,
	["category"] = objectcat.UNIT,
	["desc"] = {
		["massEmpty"] = 34000,
		["riverCrossing"] = true,
		["maxSlopeAngle"] = 0.27000001072884,
		["RCS"] = 5,
		["box"] = {
			["min"] = {
				["y"] = 0.039917565882206,
				["x"] = -4.5607042312622,
				["z"] = -1.7571629285812,
			},
			["max"] = {
				["y"] = 3.610570192337,
				["x"] = 4.5179929733276,
				["z"] = 1.7558742761612,
			},
		},
		["speedMax"] = 18.055599212646,
		["life"] = 3,
		["attributes"] = {
			["SAM TR"] = true,
			["Vehicles"] = true,
			["SAM elements"] = true,
			["NonArmoredUnits"] = true,
			["SAM SR"] = true,
			["Air Defence"] = true,
			["Ground vehicles"] = true,
			["RADAR_BAND1_FOR_ARM"] = true,
		},
		["category"] = 2,
		["speedMaxOffRoad"] = 18.055599212646,
		["Kmax"] = 0.050000000745058,
		["typeName"] = "Tor 9A331",
		["displayName"] = "SAM SA-15 Tor 9A331",
	},
	["position"] = {
		["p"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["x"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["y"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
		["z"] = {["x"] = 1, ["y"] = 1, ["z"] = 1},
	},
	["vel"] = {["x"] = 1, ["y"] = 0, ["z"] = 1},
	["inair"] = false,
	["id"] = 123,
}

local objects = {}
for _,v in pairs(objectcat) do
	objects[v] = {}
end

local Object = class()

function Object.printObjects()
	for k,v in pairs(objects) do
		for name, obj in pairs(v) do
			print("objects["..k.."]["..name.."] = "..tostring(obj))
		end
	end
end

function Object:__init(objdata)
	local data = objdata or {}
	for k,v in pairs(objdefaults) do
		self[k] = data[k]
		if self[k] == nil then
			self[k] = utils.deepcopy(v)
		end
	end
	objects[self.category][self.name] = self
end
Object.Category = objectcat
function Object:isExist()
	return self.exists
end

function Object:destroy()
	objects[self.category][self.name] = nil
end

function Object:getCategory()
	return self.category
end

function Object:getTypeName()
	return self.desc.typeName
end

function Object:getDesc()
	return self.desc
end

function Object:hasAttribute(attribute)
	return self.desc.attribute[attribute]
end

function Object:getName()
	return self.name
end

function Object:getPoint()
	return self.position.p
end

function Object:getPosition()
	return self.position
end

function Object:getVelocity()
	return self.vel
end

function Object:inAir()
	return self.inair
end

function Object:getID()
	return self.id
end
_G.Object = Object

local Coalition = class(Object)
function Coalition:__init(objdata)
	Object.__init(self, objdata)
	self.coalition = objdata.coalition
	if self.coalition == nil then
		self.coalition = coalition.side.RED
	end

	self.country = objdata.country
	if self.country == nil then
		self.country = 18
	end
end
function Coalition:getCoalition()
	return self.coalition
end

function Coalition:getCountry()
	return self.country
end
_G.Coalition = Coalition


local Airbase = class(Coalition)
function Airbase:__init(objdata)
	objdata.category = Object.Category.BASE
	Coalition.__init(self, objdata)
	self.group = nil
	self.callsign = objdata.callsign
	self.parking = objdata.parking
	if self.desc.airbaseCategory == nil then
		self.desc.airbaseCategory = Airbase.Category.AIRDROME
	end
end
Airbase.Category = {
	["AIRDROME"] = 0,
	["HELIPAD"]  = 1,
	["SHIP"]     = 2,
}

function Airbase.getByName(name)
	return objects[Object.Category.BASE][name]
end

function Airbase:getParking(_ --[[available]])
	return self.parking
end

function Airbase:getCallsign()
	return self.callsign
end

function Airbase:getUnit(num)
	if self.group == nil then
		return nil
	end
	return self.group:getUnit(num)
end

function Airbase:_addGroup(obj)
	assert(obj.isa(Group), "no a Group object")
	self.group = obj
end
_G.Airbase = Airbase


local Unit = class(Coalition)
function Unit:__init(objdata, group, pname)
	objdata.category = Object.Category.UNIT
	Coalition.__init(self, objdata)
	self.clife = self.desc.life
	self.group = group
	if group ~= nil then
		group:_addUnit(self)
	end
	self.pname = pname
end
Unit.Category = {
	["AIRPLANE"]    = 0,
	["HELICOPTER"]  = 1,
	["GROUND_UNIT"] = 2,
	["SHIP"]        = 3,
	["STRUCTURE"]   = 4,
}
Unit.RefuelingSystem = {
	["BOOM_AND_RECEPTACLE"] = 1,
	["PROBE_AND_DROGUE"]    = 2,
}

function Unit.getByName(name)
	return objects[Object.Category.UNIT][name]
end

function Unit:getLife()
	return self.clife
end

function Unit:getLife0()
	return self.desc.life
end

function Unit:getGroup()
	return self.group
end

function Unit:getPlayerName()
	return self.pname
end

function Unit:getCallsign()
	return "foo"
end
_G.Unit = Unit

local StaticObject = class(Coalition)
function StaticObject:__init(objdata)
	objdata.category = Object.Category.STATIC
	Coalition.__init(self, objdata)
	self.clife = self.desc.life
end

StaticObject.Category = {
	["VOID"]    = 0,
	["UNIT"]    = 1,
	["WEAPON"]  = 2,
	["STATIC"]  = 3,
	["BASE"]    = 4,
	["SCENERY"] = 5,
	["CARGO"]   = 6,
}

function StaticObject.getByName(name)
	return objects[Object.Category.STATIC][name]
end

function StaticObject:getLife()
	return self.clife
end
_G.StaticObject = StaticObject

local Group = class(Coalition)
function Group:__init(unitcnt, objdata)
	objdata.category = Object.Category.GROUP
	Coalition.__init(self, objdata)
	self.units = {}
	self.unitcnt = unitcnt
	self.groupCategory = objdata.groupCategory
	if self.groupCategory == nil then
		self.groupCategory = Unit.Category.AIRPLANE
	end
	self.desc = nil
	self.getTypeName = nil
	self.getDesc = nil
	self.hasAttribute = nil
	self.position = nil
	self.getPoint = nil
	self.getPosition = nil
	self.vel = nil
	self.getVelocity = nil
	self.inair = nil
	self.inAir = nil
end

function Group.getByName(name)
	return objects[Object.Category.GROUP][name]
end

function Group:destroy()
	for _, unit in pairs(self.units) do
		unit:destroy()
	end
	Object.destory(self)
end

function Group:getCategory()
	return self.groupCategory
end

function Group:getInitialSize()
	return self.unitcnt
end

function Group:getSize()
	return #self.units
end

function Group:getUnit(num)
	return self.units[num]
end

function Group:getUnits()
	return self.units
end

function Group:_addUnit(obj)
	table.insert(self.units, obj)
end
_G.Group = Group

local missionCommands = {}
function missionCommands.addCommand(_, _, _, _)
end

function missionCommands.addSubMenu(_, _)
end

function missionCommands.removeItem(_)
end

function missionCommands.addCommandForCoalition(_, _, _, _, _)
end

function missionCommands.addSubMenuForCoalition(_, _, _)
end

function missionCommands.removeItemForCoalition(_, _)
end

function missionCommands.addCommandForGroup(_, _, _, _, _)
end

function missionCommands.addSubMenuForGroup(_, _, _)
end

function missionCommands.removeItemForGroup(_, _)
end
_G.missionCommands = missionCommands

local coord = {}
function coord.LOtoLL(pos)
	return 88.123, -63.456, pos.y
end

function coord.LLtoLO(lat, long, alt)
	return {
		["x"] = 1000*lat/2,
		["y"] = alt,
		["z"] = 1000*long/2
	}
end

function coord.LLtoMGRS(_, _)
	return {
		["UTMZone"] = "DD",
		["MGRSDigraph"] = "GJ",
		["Easting"] = 01234,
		["Northing"] = 56789,
	}
end
_G.coord = coord

local trigger = {}
trigger.action = {}

local chkbuffer  = ""
local msgbuffer  = ""
local enabletest = false
function trigger.action.setmsgbuffer(msg)
	chkbuffer = msg
end

function trigger.action.setassert(val)
	enabletest = val
end

function trigger.action.chkmsgbuffer()
	assert(msgbuffer == chkbuffer,
		"generated output not as expected;\ngot '"..
		msgbuffer.."';\n expected '"..chkbuffer.."'")
end

function trigger.action.outTextForGroup(grpid, msg, time, bool)
	assert(type(grpid) == "number", "value error: grpid must be a number")
	assert(type(msg) == "string", "value error: msg must be a string")
	assert(type(time) == "number", "value error: time must be a number")
	assert(type(bool) == "boolean", "value error: bool must be a boolean")
	msgbuffer = msg
	if enabletest == true then
		assert(msgbuffer == chkbuffer,
			"generated output not as expected;\ngot '"..
			msg.."';\n expected '"..chkbuffer.."'")
	end
end

function trigger.action.markToGroup(
	_, _, _, _, _, _
	--[[id, title, pos, grpid, readonly, msg]])
end
_G.trigger = trigger

local land = {}
land.SurfaceType = {
	["LAND"]          = 1,
	["SHALLOW_WATER"] = 2,
	["WATER"]         = 3,
	["ROAD"]          = 4,
	["RUNWAY"]        = 5,
}

function land.getHeight(_ --[[vec2]])
	return 10
end
_G.land = land

local AI = {}
AI.Task = {
	["OrbitPattern"]     = {
		["RACE_TRACK"] = "Race-Track",
		["CIRCLE"]     = "Circle",
	},
	["Designation"]      = {
		["NO"]         = "No",
		["WP"]         = "WP",
		["IR_POINTER"] = "IR-Pointer",
		["LASER"]      = "Laser",
		["AUTO"]       = "Auto",
	},
	["TurnMethod"]       = {
		["FLY_OVER_POINT"] = "Fly Over Point",
		["FIN_POINT"]      = "Fin Point",
	},
	["VehicleFormation"] = {
		["VEE"]           = "Vee",
		["ECHELON_RIGHT"] = "EchelonR",
		["OFF_ROAD"]      = "Off Road",
		["RANK"]          = "Rank",
		["ECHELON_LEFT"]  = "EchelonL",
		["ON_ROAD"]       = "On Road",
		["CONE"]          = "Cone",
		["DIAMON"]        = "Diamond",
	},
	["AltitudeType"]     = {
		["RADIO"] = "RADIO",
		["BARO"]  = "BARO",
	},
	["WaypointType"]     = {
		["TAKEOFF"]             = "TakeOff",
		["TAKEOFF_PARKING"]     = "TakeOffParking",
		["TURNING_POINT"]       = "Turning Point",
		["TAKEOFF_PARKING_HOT"] = "TakeOffParkingHot",
		["LAND"]                = "Land",
	},
	["WeaponExpend"]     = {
		["QUARTER"] = "Quarter",
		["TWO"]     = "Two",
		["ONE"]     = "One",
		["FOUR"]    = "Four",
		["HALF"]    = "Half",
		["ALL"]     = "All",
	},
}

AI.Skill = {
	"PLAYER",
	"CLIENT",
	"AVERAGE",
	"GOOD",
	"HIGH",
	"EXCELLENT",
}

AI.Option = {
	["Air"] = {
		["id"] = {
			["ROE"]                     = 0,
			["REACTION_ON_THREAT"]      = 1,
			["RADAR_USING"]             = 3,
			["FLARE_USING"]             = 4,
			["FORMATION"]               = 5,
			["RTB_ON_BINGO"]            = 6,
			["SILENCE"]                 = 7,
			["RTB_ON_OUT_OF_AMMO"]      = 10,
			["ECM_USING"]               = 13,
			["PROHIBIT_AA"]             = 14,
			["PROHIBIT_JETT"]           = 15,
			["PROHIBIT_AB"]             = 16,
			["PROHIBIT_AG"]             = 17,
			["MISSILE_ATTACK"]          = 18,
			["PROHIBIT_WP_PASS_REPORT"] = 19,
		},
		["val"] = {
			["ROE"] = {
				["WEAPON_FREE"]           = 0,
				["OPEN_FIRE_WEAPON_FREE"] = 1,
				["OPEN_FIRE"]             = 2,
				["RETURN_FIRE"]           = 3,
				["WEAPON_HOLD"]           = 4,
			},
			["REACTION_ON_THREAT"] = {
				["NO_REACTION"]         = 0,
				["PASSIVE_DEFENCE"]     = 1,
				["EVADE_FIRE"]          = 2,
				["BYPASS_AND_ESCAPE"]   = 3,
				["ALLOW_ABORT_MISSION"] = 4,
			},
			["RADAR_USING"] = {
				["NEVER"]                  = 0,
				["FOR_ATTACK_ONLY"]        = 1,
				["FOR_SEARCH_IF_REQUIRED"] = 2,
				["FOR_CONTINUOUS_SEARCH"]  = 3,
			},
			["FLARE_USING"] = {
				["NEVER"]                    = 0,
				["AGAINST_FIRED_MISSILE"]    = 1,
				["WHEN_FLYING_IN_SAM_WEZ"]   = 2,
				["WHEN_FLYING_NEAR_ENEMIES"] = 3,
			},
			["ECM_USING"] = {
				["NEVER_USE"]                     = 0,
				["USE_IF_ONLY_LOCK_BY_RADAR"]     = 1,
				["USE_IF_DETECTED_LOCK_BY_RADAR"] = 2,
				["ALWAYS_USE"]                    = 3,
			},
			["MISSILE_ATTACK"] = {
				["MAX_RANGE"]         = 0,
				["NEZ_RANGE"]         = 1,
				["HALF_WAY_RMAX_NEZ"] = 2,
				["TARGET_THREAT_EST"] = 3,
				["RANDOM_RANGE"]      = 4,
			},
		},
	},
	["Ground"] = {
		["id"] = {
			["ROE"]                = 0,
			["FORMATION"]          = 5,
			["DISPERSE_ON_ATTACK"] = 8,
			["ALARM_STATE"]        = 9,
			["ENGAGE_AIR_WEAPONS"] = 20,
		},
		["val"] = {
			["ALARM_STATE"] = {
				["AUTO"]  = 0,
				["GREEN"] = 1,
				["RED"]   = 2,
			},
			["ROE"] = {
				["OPEN_FIRE"]   = 2,
				["RETURN_FIRE"] = 3,
				["WEAPON_HOLD"] = 4,
			},
		},
	},
	["Naval"] = {
		["id"] = {
			["ROE"] = 0,
		},
		["val"] = {
			["ROE"] = {
				["OPEN_FIRE"]   = 2,
				["RETURN_FIRE"] = 3,
				["WEAPON_HOLD"] = 4,
			},
		},
	},
}
_G.AI = AI
