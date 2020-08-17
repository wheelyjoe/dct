--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents an Airbase.
--
-- Airbase<BaseAsset>:
--   generates additional assets, tracks the state of an
--   airbase, manages AI flight departures and arrivals
--]]

local class = require("libs.class")
local PriorityQueue = require("libs.containers.pqueue")
local enum  = require("dct.enum")
local dctutils = require("dct.utils.utils")
local Asset = require("dct.assets.Asset")
local BaseAsset = require("dct.assets.BaseAsset")
local Command = require("dct.utils.Command")
local Logger = require("dct.utils.Logger").getByName("Asset")

local allowedtpltypes = {
	[enum.assetType.BASEDEFENSE] = true,
	[enum.assetType.SQUADRON]    = true,
}

--[[
## Airbase States

An airbase can have a few different states, these are:

 * Operational

States Preventing Operation

 * (R) runway out
 * (S) suppressed
 * (E) enemy ground forces
 * (Su) out of supply
 * (!Sp) not Spawned

	Operational = !(R + S + E)

Some of these states do not make sense to clear in a concurrent way.
Implies we need to keep a stack of states and checking for the operational
status is simply a matter of.

	Operational = stack:empty()

## Player Slots

Player slots on the field. Well we need to consider a few things:

 * need to know which player slots are on the field
 * player parking positions need to be tracked

What about airbase objects that are not defined as part of the theater?
 A: These will need to be dynamically created.
--]]

local AirbaseAsset = class(BaseAsset)
function AirbaseAsset:__init(template, region)
	self.__clsname = "AirbaseAsset"
	self._dctobservers = {}
	self._conditions = {}
	self._departures = PriorityQueue()
	self._parking_occupied = {}
	self.updaterate = 60 -- seconds
	-- we have to keep subordinates seperate from observers for spawning
	-- reasons. Subordinates are automatically observers.
	self.subordinates = {}
	BaseAsset.__init(self, template, region)
	self:_addMarshalNames({
		"_dctobservers",
		"_tplnames",
		"subordinates",
	})
end

function AirbaseAsset:_completeinit(template, region)
	BaseAsset._completeinit(self, template, region)
	self._tplnames = template.subordinates
	self.takeofftype = template.takeofftype
end

function AirbaseAsset:_setup()
	local dcsab = Airbase.getByName(self.name)
	assert(dcsab, string.format("runtime error: '%s' is not a DCS "..
		"Airbase", self.name))
	self._abcategory = dcsab:getDesc().category
	self._location = dcsab:getPoint()
	if Airbase.Category.SHIP == self._abcategory then
		self._group = dcsab:getUnit(1):getGroup():getName()
	end
end

function AirbaseAsset:_doConditions()
		-- TODO: handle conditions
end

-- check if we have any departures to do, we only do one departure
-- per run of this function to allow for seperation of flights.
function AirbaseAsset:_doOneDeparture()
	if self._departures:empty() then
		return
	end

	local time = timer.getAbsTime()
	local name, prio = self._departures:peek()
	if time < prio then
		return
	end

	self._departures:pop()
	local flight = _G.dct.theater:getAssetMgr():getAsset(name)
	flight:spawn(false, self)
end

function AirbaseAsset:_update()
	if not self:isSpawned() then
		return nil
	end

	if not self:isOperational() then
		self:_doConditions()
	else
		self:_doOneDeparture()
	end
	return self.updaterate
end

function AirbaseAsset:getObjectNames()
	return {self.name, self._group}
end

function AirbaseAsset:getLocation()
	local dcsab
	if Airbase.Category.SHIP == self._abcategory then
		dcsab = Airbase.getByName(self.name)
		if dcsab then
			self._location = dcsab:getPoint()
		end
	end
	return self._location
end

function AirbaseAsset:checkDead()
	assert(self:isSpawned() == true,
		string.format("runtime error: Asset(%s) must be spawned",
			self.name))

	if self:isDead() or (self._group and
			dctutils.isalive(self._group)) then
		return
	end
	self:setDead(true)
	dctnotify(self, DEATH)
end

-- TODO: we need to handle multiple events some directly related to the
-- airbase or the ship/static supplying the airbase, and some events
-- related objects "generated" from the airbase, for example flights
-- taking off. This could be represented with a departure queue and the
-- a table of "active" flights needing to monitored.
function AirbaseAsset:onDCSEvent(event)
end

function AirbaseAsset:addSubordinate(asset)
	self.subordinates[asset.name] = asset.type
	if asset.type == enum.assetType.PLAYERGROUP and asset.parking then
		self._parking_occupied[asset.parking] = true
	end
	self:addDCTObserver(asset)
end

function AirbaseAsset:removeSubordinate(name)
	self.subordinates[name] = nil
	self:removeDCTObserver(name)
end

-- TODO: write DCT internal event notification system
-- TODO: this DCT observer concept could be moved out to a decorator
function AirbaseAsset:addDCTObserver(asset)
	self._dctobservers[asset.name] = asset.type
end

function AirbaseAsset:removeDCTObserver(name)
	self._dctobservers[name] = nil
end

function AirbaseAsset:notifyDCTObservers(event)
	local theater = _G.dct.theater
	for name, _ in pairs(self._dctobservers) do
		theater:getAssetMgr():getAsset(name):onDCTEvent(event)
	end
end

--[[
function onDCTEvent(event)
end
TODO: We likely want every Asset to have the capability to receive
a DCT event.
In the airbase specific case this will allow us to handle runway bombing
or suppression by simply receiving a "weapon impact" event from the
weapons tracking system.
We will need to expose the dcsobject to asset mapping in the asset manager
so that the weapon tracking system can figure out which assets to notify
--]]

function AirbaseAsset:isOperational()
	return self:isSpawned() and next(self._conditions) == nil
end

function AirbaseAsset:addFlight(delay, flight)
	self._departures:push(timer.getAbsTime() + delay, flight.name)
end

function AirbaseAsset:generate(assetmgr, region)
	for _, tplname in ipairs(self._tplnames or {}) do
		Logger:debug(string.format("%s; subordinate: %s",
			self.name, tplname))
		local tpl = region:getTemplateByName(tplname)
		assert(tpl, string.format("runtime error: airbase(%s) defines "..
			"a subordinate template of name '%s', does not exist",
			self.name, tplname))
		assert(allowedtpltypes[tpl.objtype],
			string.format("runtime error: airbase(%s) defines "..
				"a subordinate template of name '%s' and type: %d ;"..
				"not supported type", self.name, tplname, tpl.objtype))
		tpl.airbase = self.name
		local asset = Asset.factory(tpl, region)
		assetmgr:add(asset)
		self:addSubordinate(asset)
	end
end

-- TODO: for spawning we need to notify that the airbase has been
-- spawned or is otherwise operational, mainly for turning on
-- and off player slots.
local function spawn_despawn(self, action)
	local theater = _G.dct.theater
	for name, _ in pairs(self.subordinates) do
		local asset = theater:getAssetMgr():getAsset(name)
		if asset then
			asset[action](asset)
		else
			self:removeSubordinate(name)
		end
	end
end

function AirbaseAsset:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	spawn_despawn(self, "spawn")
	self._spawned = true
	_G.dct.theater:queueCommand(self.updaterate,
		Command(self._update, self))
end

function AirbaseAsset:despawn()
	spawn_despawn(self, "despawn")
	self._spawned = false
end

return AirbaseAsset
