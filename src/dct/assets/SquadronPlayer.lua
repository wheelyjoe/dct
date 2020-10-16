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
	Squadron._completeinit(self, template, region)
end

function PlayerSquadron:getATO()
	return self.planedata.ato
end

function PlayerSquadron:getPayloadLimits()
	return self.planedata.payloadlimits
end

return PlayerSquadron
