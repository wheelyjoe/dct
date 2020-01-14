--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Defines the accounting of a ticket system where pilots
-- cost one ticket.
--]]

local enum        = require("dct.enum")
local dctutils    = require("dct.utils")
local Logger      = require("dct.Logger").getByName("Tickets")

--[[ Ticket system

exhaustion:
	tickets lost > goal

* occupiying an aircraft costs 1 ticket (moves to outstanding pool)
    events: birth
* loss of ticket
	- KIA, dead pilot
	    events: dead, crash
	- MIA, pilot is not recovered
	- MIA, player disconnects without meeting recovery conditions
		- recovery conditions:
			* not inAir()
			* at authorized airbase
			* mag(velocity) < .5 m/s
--]]

local function ticketLost(theater, unit)
	local stats = theater:getStats(unit:getCoalition())
	stats:dec(enum.statID.TICKETS_OUTSTANDING)
	stats:inc(enum.statID.TICKETS_LOST)
end

local function ticketReturned(theater, unit)
	local stats = theater:getStats(unit:getCoalition())
	stats:dec(enum.statID.TICKETS_OUTSTANDING)
end

local function onBirth(theater, event, tracked)
	local side = event.initiator:getCoalition()
	theater:getStats(side):inc(enum.statID.TICKETS_OUTSTANDING)
	tracked[event.initiator:getName()] = {}
end

local function onCrash(theater, event, tracked)
	if tracked[event.initiator:getName()] == nil then
		return
	end
	ticketLost(theater, event.initiator)
	tracked[event.initiator:getName()] = nil
end

local function onDead(theater, event, tracked)
	if tracked[event.initiator:getName()] == nil then
		return
	end
	ticketLost(theater, event.initiator)
	tracked[event.initiator:getName()] = nil
end

local function onLand(_, event, tracked)
	if tracked[event.initiator:getName()] == nil or
	   event.place == nil or event.place.getCoalition == nil then
		return
	end

	tracked[event.initiator:getName()].validairbase =
		(event.initiator:getCoalition() == event.place:getCoalition())
end

local function onPlayerLeave(theater, event, tracked)
	if tracked[event.initiator:getName()] == nil then
		return
	end
	local unit  = event.initiator
	local trked = tracked[unit:getName()]

	tracked[unit:getName()] = nil

	if unit:inAir() or trked.validairbase ~= true or
	   dctutils.vector.mag(unit:getVelocity()) > 0.5 then
		ticketLost(theater, unit)
	else
		ticketReturned(theater, unit)
	end
end


local trackedunits = {}

local function sysTicketsEventHandler(theater, event)
	local relevents = {
		[world.event.S_EVENT_BIRTH]    = onBirth,
		[world.event.S_EVENT_CRASH]    = onCrash,
		[world.event.S_EVENT_DEAD]     = onDead,
		[world.event.S_EVENT_LAND]     = onLand,
		[world.event.S_EVENT_PLAYER_LEAVE_UNIT] = onPlayerLeave,
	}

	if relevents[event.id] == nil then
		Logger:debug("sysTicketsEventHandler - not relevent event: "..
			tostring(event.id))
		return
	end

	-- is a valid unit, only care about helos and planes
	local category = event.initiator:getCategory()
	if not (category == Unit.Category.AIRPLANE or
	   category == Unit.Category.HELICOPTER) then
		Logger:debug("sysTicketsEventHandler - not helo or plane, skipping")
		return
	end
	relevents[event.id](theater, event, trackedunits)
end

local function init(theater)
	assert(theater ~= nil, "value error: theater must be a non-nil value")
	Logger:debug("init system.Tickets event handler")
	theater:registerHandler(sysTicketsEventHandler, theater)
end

return init
