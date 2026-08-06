local config = require("hco/config")
local intelligence = require("hco/contracts/intelligence")
local core = require("hco/contracts/core")
local diagnostics = require("hco/diagnostics")
local escort = require("hco/security/escort")
local feedback = require("hco/feedback")
local rewards = require("hco/contracts/rewards")
local securityDirector = require("hco/security/director")
local drones = require("hco/security/drones")
local disguise = require("hco/social/disguise")
local targetController = require("hco/targets/controller")
local stateModule = require("hco/state")
local util = require("hco/util")

local runtime = {}

local SKIP_MESSAGES = {
	["insufficient-safe-contract-actors"] = "HCO: No safe contract target remains in this in-progress mission. Restart the mission or begin another mission.",
	["no-safe-candidate"] = "HCO: No safe contract target was found. Restart the mission or begin another mission.",
	["saved-target-unavailable"] = "HCO: The saved contract target no longer exists in this checkpoint. This contract was disabled safely.",
	["native-objective-unavailable"] = "HCO: The mission objective system is not ready, so no contract was added.",
	["contract-activation-failed"] = "HCO: Contract activation failed safely. No mission actors were changed."
}

local function showFinalSkip(state, reason)
	if state.contractSkipNoticeShown then
		return
	end

	state.contractSkipNoticeShown = true
	state.lastContractSkipReason = reason
	feedback.show(SKIP_MESSAGES[reason] or ("HCO: Contract unavailable (" .. tostring(reason or "unknown") .. ")."))
end

local function retryContractStart(state, dt)
	local pending = state.pendingContractStart

	if not pending or #stateModule.getContexts(state) > 0 then
		return
	end

	pending.remaining = pending.remaining - dt

	if pending.remaining > 0 then
		return
	end

	local report, selectionError = core.startMap(state, game.worldObject, pending.reason .. "-retry-" .. tostring(pending.attempt))
	diagnostics.printReport(report.mapID, report)

	if #stateModule.getContexts(state) > 0 then
		state.pendingContractStart = nil
		state.lastContractSkipReason = nil
		state.contractSkipNoticeShown = false
		feedback.show("HCO: " .. tostring(#state.contracts) .. " contract target(s) active. Check mission objectives.")

		return
	end

	local nextAttempt = pending.attempt + 1
	local nextDelay = config.CONTRACT_START_RETRY_DELAYS[nextAttempt]

	if nextDelay then
		state.pendingContractStart = {
			reason = pending.reason,
			attempt = nextAttempt,
			remaining = nextDelay
		}
	else
		state.pendingContractStart = nil
		showFinalSkip(state, selectionError)
	end
end

local function runSubsystem(state, name, callback, ...)
	state.subsystemErrors = state.subsystemErrors or {}

	if state.subsystemErrors[name] then
		return
	end

	local ok, err = pcall(callback, ...)

	if not ok then
		state.subsystemErrors[name] = tostring(err)
		util.log(config, "subsystem disabled name=" .. name .. " error=" .. tostring(err))
	end
end

function runtime.install(state)
	if state.runtimeInstalled then
		return
	end

	local updateState = {}

	function updateState:update(dt)
		if not game.worldObject then
			return
		end

		local retryOK, retryError = pcall(retryContractStart, state, dt)

		if not retryOK then
			state.pendingContractStart = nil
			state.lastContractSkipReason = "retry-runtime-failed"
			util.log(config, "contract retry disabled error=" .. tostring(retryError))
		end

		local contexts = stateModule.getContexts(state)
		if #contexts == 0 then
			return
		end

		for _, context in ipairs(contexts) do
			if context.pendingRewardPayment and rewards.pay(context) then context.pendingRewardPayment = nil end
			context.runtimeDelta = dt
			runSubsystem(context, "security-director", securityDirector.update, context, dt)
			runSubsystem(context, "target-controller", targetController.update, context, dt)
			runSubsystem(context, "escort", escort.update, context, dt)
			runSubsystem(context, "target-intelligence", intelligence.update, context, dt)
			runSubsystem(context, "search-drones", drones.update, context, dt)
		end

		state.runtimeDelta = dt
		runSubsystem(state, "social-stealth", disguise.update, state, dt)
		stateModule.syncPrimary(state)
	end

	state.runtimeState = updateState
	state.runtimeInstalled = true
	gameStateService:addState(updateState)
end

return runtime
