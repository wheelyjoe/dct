--[[
-- SPDX-License-Identifier: LGPL-3.0
--
-- UI Commands
--]]

require("os")
local class    = require("libs.class")
local utils    = require("libs.utils")
local enum     = require("dct.enum")
local dctutils = require("dct.utils")
local human    = require("dct.ui.human")
local Command  = require("dct.Command")
local Logger   = dct.Logger.getByName("UI")
local loadout  = require("dct.systems.loadouts")

local UICmd = class(Command)
function UICmd:__init(theater, data)
	assert(theater ~= nil, "value error: theater required")
	assert(data ~= nil, "value error: data required")
	local asset = theater:getAssetMgr():getAsset(data.name)
	assert(asset, "runtime error: asset was nil, "..data.name)

	self.theater      = theater
	self.asset        = asset
	self.type         = data.type
	self.displaytime  = 30
	self.displayclear = true
end

function UICmd:isAlive()
	return dctutils.isalive(self.asset.name)
end

function UICmd:execute(time)
	-- only process commands from live players unless they are abort
	-- commands
	if not self:isAlive() and
	   self.type ~= enum.uiRequestType.MISSIONABORT then
		Logger:debug("UICmd thinks player is dead, ignore cmd; "..
			debug.traceback())
		self.asset.cmdpending = false
		return nil
	end

	local cmdr = self.theater:getCommander(self.asset.owner)
	local msg  = self:_execute(time, cmdr)
	assert(msg ~= nil and type(msg) == "string", "msg must be a string")
	trigger.action.outTextForGroup(self.asset.groupId, msg,
		self.displaytime, self.displayclear)
	self.asset.cmdpending = false
	return nil
end

local ScratchPadDisplay = class(UICmd)
function ScratchPadDisplay:__init(theater, data)
	UICmd.__init(self, theater, data)
end

function ScratchPadDisplay:_execute(_, _)
	local msg = string.format("Scratch Pad: '%s'",
		tostring(self.asset.scratchpad))
	return msg
end

local ScratchPadSet = class(UICmd)
function ScratchPadSet:__init(theater, data)
	UICmd.__init(self, theater, data)
end

function ScratchPadSet:_execute(_, _)
	local mrkid = human.getMarkID()
	local pos   = Group.getByName(self.asset.name):getUnit(1):getPoint()
	local title = "SCRATCHPAD "..tostring(self.asset.groupId)

	self.theater.scratchpad[mrkid] = self.asset.name
	trigger.action.markToGroup(mrkid, title, pos, self.asset.groupId,
		false, "edit me")
	local msg = "Look on F10 MAP for user mark with title: "..
		title.."\n"..
		"Edit body with your scratchpad information. "..
		"Click off the mark when finished. "..
		"The mark will automatically be deleted."
	return msg
end

local TheaterUpdateCmd = class(UICmd)
function TheaterUpdateCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
end

function TheaterUpdateCmd:_execute(_, cmdr)
	local update = cmdr:getTheaterUpdate()
	local msg =
		string.format("== Theater Threat Status ==\n") ..
		string.format("  Sea:    %s\n", human.threat(update.enemy.sea)) ..
		string.format("  Air:    %s\n", human.airthreat(update.enemy.air)) ..
		string.format("  ELINT:  %s\n", human.threat(update.enemy.elint))..
		string.format("  SAM:    %s\n", human.threat(update.enemy.sam)) ..
		string.format("\n== Current Active Air Missions ==\n")
	if next(update.missions) ~= nil then
		for k,v in pairs(update.missions) do
			msg = msg .. string.format("  %6s:  %2d\n", k, v)
		end
	else
		msg = msg .. "  No Active Missions\n"
	end
	local ato = enum.missionType
	if self.asset.squadron then
		ato = self.theater:getAssetMgr():
			getAsset(self.asset.squadron).planedata.ato
	end
	msg = msg .. string.format("\nRecommended Mission Type: %s\n",
		utils.getkey(enum.missionType,
			cmdr:recommendMissionType(ato)) or "None")
	return msg
end

local CheckPayloadCmd = class(UICmd)
function CheckPayloadCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
end

function CheckPayloadCmd:_execute(_ --[[time]], _ --[[cmdr]])
	local msg = loadout.check(self.asset)
	return msg
end


local MissionCmd = class(UICmd)
function MissionCmd:__init(theater, data)
	UICmd.__init(self, theater, data)
	self.erequest = true
end

function MissionCmd:_execute(time, cmdr)
	local msg
	local msn = cmdr:getAssigned(self.asset)
	if msn == nil then
		msg = "You do not have a mission assigned"
		if self.erequest == true then
			msg = msg .. ", use the F10 menu to request one first."
		end
		return msg
	end
	msg = self:_mission(time, cmdr, msn)
	return msg
end


local function briefingmsg(msn, asset)
	local tgtinfo = msn:getTargetInfo()
	local msg = string.format("Package: #%s\n", msn:getID())..
		string.format("IFF Codes: M1(%02o), M3(%04o)\n",
			msn.iffcodes.m1, msn.iffcodes.m3)..
		string.format("%s: %s (%s)\n",
			human.locationhdr(msn.type),
			human.grid2actype(asset.unittype,
				tgtinfo.location, tgtinfo.intellvl),
			tgtinfo.callsign)..
		"Briefing:\n"..msn:getDescription(asset.unittype,
			tgtinfo.intellvl)
	return msg
end

local MissionJoinCmd = class(MissionCmd)
function MissionJoinCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionJoinCmd:_execute(_, cmdr)
	local missioncode = self.asset.scratchpad or 0
	local msn = cmdr:getAssigned(self.asset)
	local msg

	if msn then
		msg = string.format("You have mission %s already assigned, "..
			"use the F10 Menu to abort first.", msn:getID())
		return msg
	end

	msn = cmdr:getMission(missioncode)
	if msn == nil then
		msg = string.format("No mission of ID(%s) available, use"..
			" scratch pad to set id.", tostring(missioncode))
	else
		msn:addAssigned(self.asset)
		msg = string.format("Mission %s assigned, use F10 menu "..
			"to see this briefing again\n", msn:getID())
		msg = msg..briefingmsg(msn, self.asset)
	end
	return msg
end

local MissionRqstCmd = class(MissionCmd)
function MissionRqstCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.missiontype = data.value
	self.displaytime = 120
end

function MissionRqstCmd:_execute(_, cmdr)
	local msn = cmdr:getAssigned(self.asset)
	local msg

	if msn then
		msg = string.format("You have mission %s already assigned, "..
			"use the F10 Menu to abort first.", msn:getID())
		return msg
	end

	msn = cmdr:requestMission(self.asset.name, self.missiontype)
	if msn == nil then
		msg = string.format("No %s missions available.",
			human.missiontype(self.missiontype))
	else
		msg = string.format("Mission %s assigned, use F10 menu "..
			"to see this briefing again\n", msn:getID())
		msg = msg..briefingmsg(msn, self.asset)
		human.drawTargetIntel(msn, self.asset.groupId, false)
	end
	return msg
end


local MissionBriefCmd = class(MissionCmd)
function MissionBriefCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.displaytime = 120
end

function MissionBriefCmd:_mission(_, _, msn)
	return briefingmsg(msn, self.asset)
end


local MissionStatusCmd = class(MissionCmd)
function MissionStatusCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionStatusCmd:_mission(time, _, msn)
	local msg
	local tgtinfo  = msn:getTargetInfo()
	local timeout  = msn:getTimeout()
	local minsleft = (timeout - time)
	if minsleft < 0 then
		minsleft = 0
	end
	minsleft = minsleft / 60

	msg = string.format("Package: %s\n", msn:getID()) ..
		string.format("Timeout: %s (in %d mins)\n",
			dctutils.date("%F %Rz", dctutils.zulutime(timeout)),
			minsleft) ..
		string.format("BDA: %d%% complete\n", tgtinfo.status)

	return msg
end


local MissionAbortCmd = class(MissionCmd)
function MissionAbortCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.erequest = false
	self.reason   = data.value
end

function MissionAbortCmd:_mission(_ --[[time]], _, msn)
	local msgs = {
		[enum.missionAbortType.ABORT] =
			"aborted",
		[enum.missionAbortType.COMPLETE] =
			"completed",
		[enum.missionAbortType.TIMEOUT] =
			"timed out",
	}
	local msg = msgs[self.reason]
	if msg == nil then
		msg = "aborted - unknown reason"
	end
	return string.format("Mission %s %s",
		msn:abort(self.asset),
		msg)
end


local MissionRolexCmd = class(MissionCmd)
function MissionRolexCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
	self.rolextime = data.value
end

function MissionRolexCmd:_mission(_, _, msn)
	return string.format("+%d mins added to mission timeout",
		msn:addTime(self.rolextime)/60)
end


local MissionCheckinCmd = class(MissionCmd)
function MissionCheckinCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionCheckinCmd:_mission(time, _, msn)
	msn:checkin(time)
	return string.format("on-station received")
end


local MissionCheckoutCmd = class(MissionCmd)
function MissionCheckoutCmd:__init(theater, data)
	MissionCmd.__init(self, theater, data)
end

function MissionCheckoutCmd:_mission(time, _, msn)
	return string.format("off-station received, vul time: %d",
		msn:checkout(time))
end

local cmds = {
	[enum.uiRequestType.THEATERSTATUS]   = TheaterUpdateCmd,
	[enum.uiRequestType.MISSIONREQUEST]  = MissionRqstCmd,
	[enum.uiRequestType.MISSIONBRIEF]    = MissionBriefCmd,
	[enum.uiRequestType.MISSIONSTATUS]   = MissionStatusCmd,
	[enum.uiRequestType.MISSIONABORT]    = MissionAbortCmd,
	[enum.uiRequestType.MISSIONROLEX]    = MissionRolexCmd,
	[enum.uiRequestType.MISSIONCHECKIN]  = MissionCheckinCmd,
	[enum.uiRequestType.MISSIONCHECKOUT] = MissionCheckoutCmd,
	[enum.uiRequestType.SCRATCHPADGET]   = ScratchPadDisplay,
	[enum.uiRequestType.SCRATCHPADSET]   = ScratchPadSet,
	[enum.uiRequestType.CHECKPAYLOAD]    = CheckPayloadCmd,
	[enum.uiRequestType.MISSIONJOIN]     = MissionJoinCmd,
}

return cmds
