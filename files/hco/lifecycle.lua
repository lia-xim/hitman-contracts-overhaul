local config = require("hco/config")
local core = require("hco/contracts/core")
local diagnostics = require("hco/diagnostics")
local stateModule = require("hco/state")
local util = require("hco/util")

local lifecycle = {}

local NON_RETRYABLE = {
	["contract-terminal"] = true,
	["unsupported-map"] = true,
	["unsupported-mission-phase"] = true,
	["saved-target-unavailable"] = true
}

local function scheduleRetry(state, reason, selectionError)
	state.lastContractSkipReason = selectionError

	if NON_RETRYABLE[selectionError] then
		return
	end

	state.pendingContractStart = {
		reason = reason,
		attempt = 1,
		remaining = config.CONTRACT_START_RETRY_DELAYS[1]
	}
end

local function assignTarget(state, reason)
	local worldObject = game and game.worldObject

	if not worldObject then
		stateModule.resetRuntime(state, reason .. ":no-world")
		util.log(config, "target assignment skipped: world is unavailable")

		return false
	end

	local report, selectionError = core.startMap(state, worldObject, reason)
	diagnostics.printReport(report.mapID, report)

	if not state.target then
		util.log(config, "map=" .. tostring(report.mapID) .. " contract skipped: " .. tostring(selectionError))
		scheduleRetry(state, reason, selectionError)

		return false
	end

	state.pendingContractStart = nil
	state.lastContractSkipReason = nil
	state.contractSkipNoticeShown = false

	util.log(config, "target assigned map=" .. tostring(report.mapID) .. " npc=" .. tostring(state.targetID))

	return true
end

local function onTargetNeutralized(state, npc)
	local context = stateModule.findContextByActor(state, npc)
	if not context then
		return
	end

	core.onTargetNeutralized(context, npc)
	util.log(config, "target neutralized npc=" .. tostring(context.targetID))
end

local function onTargetDied(state, npc, attacker)
	local context = stateModule.findContextByActor(state, npc)
	if not context then
		return
	end

	core.onTargetDied(context, npc, attacker)
	util.log(config, "target killed npc=" .. tostring(context.targetID) .. " attacker=" .. tostring(context.targetKillerID or "unknown"))
end

local function dispatchEvent(state, event, ...)
	if event == game.EVENTS.MAP_LOADED then
		local initialLoad = ...
		state.lastMapInitialLoad = initialLoad
		assignTarget(state, initialLoad and "map-loaded-initial" or "map-loaded-save")
	elseif event == game.EVENTS.PLAYER_SET and not state.target and game.worldObject then
		assignTarget(state, "player-set")
	elseif event == game.EVENTS.RESET_FINISHED then
		assignTarget(state, "reset-finished")
	elseif event == game.EVENTS.RESET_STARTED or event == game.EVENTS.GAME_UNLOADED or event == game.EVENTS.RETURNING_TO_MAIN_MENU or event == game.EVENTS.PRE_REMOVE_GAME or event == game.EVENTS.LEVEL_FINISHED then
		core.clearMap(state)
	elseif event == actor.EVENTS.NEUTRALIZED then
		onTargetNeutralized(state, ...)
	elseif event == actor.EVENTS.DIED then
		onTargetDied(state, ...)
	end
end

function lifecycle.start(state)
	if state.listenerInstalled then
		util.log(config, "existing lifecycle listener reused (local/Workshop duplicate prevented)")

		return
	end

	local listener = {}

	function listener:handleEvent(event, ...)
		local ok, err = pcall(dispatchEvent, state, event, ...)

		if not ok then
			util.log(config, "lifecycle event failed event=" .. tostring(event) .. " error=" .. tostring(err))
		end
	end

	state.listener = listener
	state.listenerInstalled = true

	local catchable = {}
	local function addEvent(event)
		if event then
			table.insert(catchable, event)
		end
	end

	addEvent(game.EVENTS.MAP_LOADED)
	addEvent(game.EVENTS.RESET_STARTED)
	addEvent(game.EVENTS.RESET_FINISHED)
	addEvent(game.EVENTS.GAME_UNLOADED)
	addEvent(game.EVENTS.RETURNING_TO_MAIN_MENU)
	addEvent(game.EVENTS.PRE_REMOVE_GAME)
	addEvent(game.EVENTS.LEVEL_FINISHED)
	addEvent(game.EVENTS.PLAYER_SET)
	addEvent(actor.EVENTS.NEUTRALIZED)
	addEvent(actor.EVENTS.DIED)

	events:addDirectReceiver(listener, catchable)

	-- This also makes a developer hot-load useful without changing normal boot.
	if game.worldObject then
		assignTarget(state, "startup-world-present")
	end
end

return lifecycle
