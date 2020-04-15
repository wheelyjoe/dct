--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- Implements a Observable interface
--]]

require("os")
local class  = require("libs.class")
local Logger = require("dct.Logger").getByName("Observable")

local Observable = class()
function Observable:__init()
	self._observers = {}
	-- TODO: might need to implement a __mode metatable
	-- to implement weak key & value references
end

function Observable:registerHandler(func, ctx)
	assert(type(func) == "function", "func must be a function")
	-- ctx must be non-nil otherwise upon insertion the index which
	-- is the function address will be deleted.
	assert(ctx ~= nil, "ctx must be a non-nil value")

	if self._observers[func] ~= nil then
		Logger:error("func("..tostring(func)..") already set - skipping")
		return
	end
	Logger:debug("adding handler("..tostring(func)..")")
	self._observers[func] = ctx
end

function Observable:removeHandler(func)
	assert(type(func) == "function", "func must be a function")
	self._observers[func] = nil
end

function Observable:onEvent(event)
	local tstart = os.clock()
	local hdlrcnt = 0
	for observer, ctx in pairs(self._observers) do
		hdlrcnt = hdlrcnt + 1
		Logger:debug("executing handler: "..tostring(observer))
		observer(ctx, event)
	end
	Logger:debug(
		string.format("DCS Event Handlers - time: %6.3fms; count: %d",
			(os.clock() - tstart)*1000, hdlrcnt))
end

return Observable
