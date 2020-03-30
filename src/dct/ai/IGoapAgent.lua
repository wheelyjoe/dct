--[[
=====================

IGoapAgent:
	attributes(private):
	- dcsgroupname
	- availableActions<HashSet>
	- plan<Queue>
	- worldstate
	- planner
	- fsm{idle, moveto, doaction}

	attributes(public):

	methods(public):
	- setOptions()
	- addAction()
	- getAction()
	- removeAction()
	- setGoal()
	- getGoal()
	- start()
	- update()
	- exec()
--]]

require("math")
local class    = require("libs.class")
local utils    = require("libs.utils")
local dctutils = require("dct.utils")
local STM      = require("dct.STM")
local Goal     = require("dct.Goal")
local Logger   = require("dct.Logger").getByName("Asset")
local settings = _G.dct.settings
