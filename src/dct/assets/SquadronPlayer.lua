--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Represents a PlayerSquadron.
--
-- PlayerSquadron<Squadron>:
--   tracks and manages players slots associated with this squadron.
--]]

local class = require("libs.class")
local enum  = require("dct.enum")
local Squadron = require("dct.assets.Squadron")
local Logger = dct.Logger.getByName("Asset")

local PlayerSquadron = class(Squadron)
function PlayerSquadron:__init(template, region)
	self.__clsname = "PlayerSquadron"
	Squadron.__init(self, template, region)
end

function PlayerSquadron:_completeinit(template, region)
	require("dct.assets.AssetBase")._completeinit(self, template, region)
	self.planedata = utils.deepcopy(template.planedata)
	self.airbase   = template.airbase

	-- remove player specific APIs if we are not a player
	-- squadron
	if self.type ~= enum.assetType.PLAYERSQUADRON then
		getPlaneInfo(template:copyData())
		self.addPlayer   = nil
		self.getPayloadLimits = nil
	else
		self.getPlaneInfo = nil
	end
end

function PlayerSquadron:getATO()
	return self.planedata.ato
end

function PlayerSquadron:getPayloadLimits()
	return self.planedata.payloadlimits
end

function PlayerSquadron:onDCSEvent(event)
	-- TODO: handle aircraft death messages, aircraft takeoff/landing,
	-- and hit events to track
end

function PlayerSquadron:spawn(ignore)
	if not ignore and self:isSpawned() then
		Logger:error(string.format("runtime bug - %s(%s) already spawned",
			self.__clsname, self.name))
		return
	end
	AssetBase.spawn(self)
end

function PlayerSquadron:despawn()
	for sub, _ pairs(self.subordinates) do
	end
end

return PlayerSquadron

--[[
unit definition

 - onboard_num
 - callsign
 - heading
 - payload
 - name
 - x
 - y
 - ?parking_id
 - psi
 - type
 - speed
 - ?parking
 - skill
 - livery_id
 - alt_type
 - ?hardpoint_racks
 - alt

group definition

 - modulation
 - task
 - uncontrolled
 - route
 - units
 - frequency
 - start_time
 - communication
 - name
 - x
 - y
--]]
