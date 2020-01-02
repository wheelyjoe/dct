--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a Mission within the game and this associates an
-- Objective to as assigned group of units responsible for
-- completing the Objective.
--]]

require("math")
local class    = require("libs.class")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local uihuman  = require("dct.ui.human")

local MISSION_LIMIT = 60*60*3  -- 3 hours in seconds
local MISSION_ID = math.random(1,99)

local function genMissionID(cmdr, msntype)
	local msnid = dctutils.getkey(enum.missionType, msntype)
	local id

	while true do
		MISSION_ID = (MISSION_ID + 1) % 10000
		id = msnid..string.format("%04d", MISSION_ID)
		if cmdr:getMission(id) == nil then
			break
		end
	end
	return id
end

local function interp(s, tab)
	return (s:gsub('(%b%%)', function(w) return tab[w:sub(2,-2)] or w end))
end

local function genLocationMethod()
	local txt = {
		"NATO Reconaissasnce elements have located",
		"A recon flight earlier today discovered",
		"We have reason to believe there is",
		"Aerial photography shows that there is",
		"Satellite Imaging of Iran has found",
		"Ground units operating in Iran have informed us of",
	}
	local idx = math.random(1,#txt)
	return txt[idx]
end

local Mission = class()
function Mission:__init(cmdr, missiontype, grpname, tgtname)
	-- reference to owning commander
	self.cmdr      = cmdr
	self.id        = genMissionID(cmdr, missiontype)
	self.type      = missiontype
	self.target    = tgtname
	self.assigned  = grpname
	self.timestart = timer.getTime()
	self.timeend   = self.timestart + MISSION_LIMIT
	self.onstation = false

	-- compose the briefing at mission creation to represent
	-- known intel the pilots were given before departing
	self.briefing  = self:_composeBriefing()

	-- TODO: setup remaining mission parameters;
	--   * mission world state
end

function Mission:_composeBriefing()
	local tgt = self.cmdr:getAsset(self.target)
	local briefing = tgt:getBriefing()
	local interptbl = {
		["LOCATIONMETHOD"] = genLocationMethod(),
		["TOT"] = "wip-12:45:00",
	}
	return interp(briefing, interptbl)
end

function Mission:getID()
	return self.id
end

--[[
-- Abort - aborts a mission putting the targeted asset back into
--   the pool.
--
-- Things that need to be managed;
--  * removing the mission from the owning commander's mission
--    list(s)
--  * releasing the targeted asset by resetting the asset's targeted
--    bit
--]]
function Mission:abort()
	self.cmdr:removeMission(self.id)
	local tgt = self.cmdr:getAsset(self.target)
	if tgt then
		tgt:setTargeted(false)
	end
	return self.id
end

function Mission:update()
	-- TODO: update the state of the mission
end

function Mission:isComplete()
	-- TODO
end

--[[
-- getTargetInfo - provide target info information
--
-- The target information supplied:
--   * location - centroid of the asset
--   * callsign - a short name the target area can be referenced by
--   * description - short two/three word description of the asset
--       like; factory, ammo bunker, etc.
--   * status - numercal value from 0 to 100 representing percentage
--       completion
--   * intellvl - numercal value representing the amount of 'intel'
--       gathered on the asset, dictates targeting coordinates
--       precision too
--]]
function Mission:getTargetInfo()
	local asset = self.cmdr:getAsset(self.target)
	local tgtinfo = {}
	tgtinfo.location = asset:getLocation()
	tgtinfo.callsign = asset:getCallsign()
	tgtinfo.status   = asset:getStatus()
	tgtinfo.intellvl = asset:getIntelLevel()
	return tgtinfo
end

function Mission:getTimeout()
	return self.timeend
end

function Mission:addTime(time)
	self.timeend = self.timeend + time
	return time
end

function Mission:checkin(time)
	-- TODO: write this
end

function Mission:checkout(time)
	-- TODO: write this
end

function Mission:getDescription(actype, locprecision)
	local tgt = self.cmdr:getAsset(self.target)
	local interptbl = {
		["LOCATION"] = uihuman.grid2actype(actype, tgt:getLocation(),
			locprecision)
	}
	return interp(self.briefing, interptbl)
end

return Mission