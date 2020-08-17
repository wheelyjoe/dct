--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Starts the DCT framework
--]]

local Theater = require("dct.Theater")
local runonce = false

local function init()
	if runonce == true then
		return
	end
	local t = Theater()
	world.addEventHandler(t)
	timer.scheduleFunction(t.exec, t, timer.getTime() + 20)
	_G.dct.theater = t
	runonce = true
end

return init
