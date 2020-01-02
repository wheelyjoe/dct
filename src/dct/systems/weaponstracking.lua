--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Suppression system - will "suppress" ground groups for a period
-- of time.
--]]

local class    = require("libs.class")
local dctutils = require("dct.utils")
local vec3Dmag = dctutils.threeD.vector.magnitude
local vec3Dscalarmul = dctutils.threeD.vector.scalarmul
local vec3Dadd = dctutils.threeD.vector.add
local Command  = require("dct.Command")

local TRACKED_WEAPON_FREQ = 1.0 -- seconds

local function isWpnValid(wpn)
	return true
end

-- is the weapon an anti-radiation missile
local function isWpnARM(wpn)
	local wpndesc = wpn:getDesc()
	return (wpndesc.category == Weapon.Category.MISSILE and
		wpndesc.missileCategory == Weapon.MissileCategory.OTHER and
		wpndesc.guidance == Weapon.GuidanceType.RADAR_PASSIVE)
end

local function updateWpnEntry(entry)
	local wpn = entry.weapon
	local pos = wpn:getPosition()

	entry.pos  = pos.p
	entry.dir  = pos.x
	entry.vel  = wpn:getVelocity()
	entry.time = timer.getTime()
end

local function createWpnStruct(wpn, initiator, time)
	local tbl = {
		["weapon"]        = wpn,
		["type"]          = wpn:getTypeName(),
		["initiatorname"] = initiator:getName(),
		["desc"]          = wpn:getDesc(),
	}

	tbl.maxradius = calcRadiusFromMass(tbl.desc.warhead.explosiveMass)
	updateWpnEntry(tbl)
	return tbl
end

local function createVolumeStruct(t, shapedesc)
	assert(dctutils.getkey(world.VolumeType, t) ~= nil,
		"value error: t must be a value from world.VolumeType")
	local tbl = {}
	tbl.id     = t
	tbl.params = shapedesc
	return tbl
end

local function handleobject(obj, wpndata)
	-- only process if the object matches a specific set of critera
	--
	-- verify if the impact point and the unit's location can see
	--  eachother, make sure to raise the y axis by 1 meter so
	--  that we don't immediatly run into land
	--
	-- determine distance from impact point
	-- determine Pk, probability of kill
	-- draw random number and determine if the unit should be
	--  killed or suppressed/stunned
	--
	-- killing uses
	--    trigger.action.explosion(point1, power)
	--  and can be applied per unit. The power of the explosion is
	--  defined as the kilogram TNT equivalent, so we should just be able
	--  to take the explosive mass in the weapon's description table.
	--
	-- suppression is really just turning off the AI and can only
	--  be done at the group level. Since it affects the entire
	--  group we shouldn't turn off the entire group's AI until
	--  some percentage of the group is affected. Also simply
	--  queuing up to turn a group AI on after a period of time
	--  doesn't account for the AI already being off/on. Instead
	--  a moral and hold-down timer can be used to prevent flapping
	--  of the AI.
end


local tracked = {}
local TrackWeaponsCmd = class(Command)
function TrackWeaponsCmd:execute(time)
	for id, wdata in pairs(tracked) do
		if wdata.weapon:isExist() then
			updateWpnEntry(wdata)
		else
			tracked[id] = nil
			local timediff = time-wdata.time

			-- find impact point
			local impactpt = land.getIP(wdata.pos, wdata.dir,
				vec3Dmag(wdata.vel)*timediff)
			if impactpt == nil then
				-- use the velocity vector to translate the last
				-- sampled point to where the point would have been
				-- half-way between the last sample and now
				impactpt = vec3Dadd(wdata.pos,
					vec3Dscalarmul(timediff/2, wdata.vel))
			end
			wdata.pos = impactpt

			-- may want to consider generating events and letting other
			-- systems handle and do events instead of doing it here,
			-- something to thing about.

			local vol = createVolumeStruct(world.VolumeType.SPHERE,
				{
					point = impactpt,
					radius = wdata.maxradius,
				})
			local objs = {
				Object.Category.UNIT,
				Object.Category.STATIC,
			}
			world.searchObjects(objs, vol, handleobject, wdata)
		end
	end
	return TRACKED_WEAPON_FREQ
end

-- only handle HE warheads as anything else we don't want to simulate
-- Also only limit weapons ground attack weapons
local function suppressionEventHandler(theater, event)
	if not (event.id == world.event.S_EVENT_SHOT and
	   event.weapon and event.initiator) then
		Logger:debug("suppressionEventHandler - not handling event: "..
			tostring(event.id).."; weapon: "..tostring(event.weapon)..
			"; initiator: "..tostring(event.initiator))
		return
	end

	if not isValidWeapon(event.weapon) then
		Logger:debug("suppressionEventHandler - weapon not valid "..
			"typename: "..event.weapon:getTypeName())
			return
	end

	local wpntbl = createWpnStruct(event.weapon, event.initiator,
		timer.getTime())

	if isWpnARM(event.weapon) then
		-- TODO: post launch event to the commander of the weapon's
		-- target if weapon has no target post launch even to the
		-- initiator's enemy coalition commander
	end

	tracked[event.weapon.id_] = wpntbl
end

local function init(theater)
	assert(theater ~= nil, "value error: theater must be a non-nil value")
	Logger:debug("init suppression event handler")
	theater:registerHandler(suppressionEventHandler, theater)
	theater:queueCommand(TRACKED_WEAPON_FREQ, TrackWeaponsCmd)
end

return init
