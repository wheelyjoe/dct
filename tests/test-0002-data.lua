#!/usr/bin/lua

require("os")
require("io")
require("dcttestlibs")
require("dct")
local Command = require("dct.utils.Command")
local Marshallable = require("dct.utils.Marshallable")
local BaseAsset = require("dct.assets.BaseAsset")
local StaticAsset = require("dct.assets.StaticAsset")

local function f(a, b, c, time)
    return a + b + c + time
end

local function main()
    --local m = Marshallable()
    local base = StaticAsset()
    --[[
    local cmd = Command(f, 1, 2, 3)
    local r = cmd:execute(500)
    assert(r == 506, "Command class broken")
    --]]
end

os.exit(main())
