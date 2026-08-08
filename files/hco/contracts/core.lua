local conditions = require("hco/contracts/conditions")
local balance = require("hco/balance")
local intelligence = require("hco/contracts/intelligence")
local config = require("hco/config")
local disguise = require("hco/social/disguise")
local escort = require("hco/security/escort")
local securityDirector = require("hco/security/director")
local drones = require("hco/security/drones")
local mapRegistry = require("hco/maps/registry")
local objective = require("hco/contracts/objective")
local persistence = require("hco/contracts/persistence")
local profiles = require("hco/contracts/profiles")
local rewards = require("hco/contracts/rewards")
local selector = require("hco/targets/selector")
local stateModule = require("hco/state")
local targetController = require("hco/targets/controller")
local util = require("hco/util")

local core = {}

local function calculateReward(report, profile)
	local base = config.BASE_REWARD + #report.eligible * config.REWARD_PER_ELIGIBLE_GUARD
	local mapMultiplier = report.profile and report.profile.rewardMultiplier or 1
	local tuning = balance.snapshot(profile)

	return math.min(config.MAX_REWARD, math.floor(base * profile.rewardMultiplier * mapMultiplier * tuning.rewardScale))
end

local function findEntry(report, targetID)
	for _, entry in ipairs(report.eligible) do
		if entry.data.id == tostring(targetID) then
			return entry
		end
	end

	return nil
end

local function prepareContextReset(state)
	local cleanupSteps = {
		{"objective-marker", objective.removeMarker},
		{"intelligence", intelligence.detach},
		{"search-drones", drones.detach},
		{"target-controller", targetController.detach},
		{"security-director", securityDirector.detach},
		{"escort", escort.detach},
	}

	for _, step in ipairs(cleanupSteps) do
		local ok, err = pcall(step[2], state)

		if not ok then
			util.log(config, "cleanup step failed name=" .. step[1] .. " error=" .. tostring(err))
		end
	end
	stateModule.assignTarget(state, nil)
end

local function prepareRuntimeReset(state)
	for _, context in ipairs(stateModule.getContexts(state)) do
		prepareContextReset(context)
	end
	pcall(disguise.clear, state, true)
end

local function activateContext(root, context, record, selected, report)
	context.contract = record
	context.mapID = root.mapID
	context.worldToken = root.worldToken
	context.compromisedDisguises = root.compromisedDisguises
	stateModule.assignTarget(context, selected.npc)
	selected.npc._hcoReservedTarget = record.contractID
	escort.attach(context, report)
	securityDirector.attach(context, report)
	targetController.attach(context, report)
	persistence.save(record)

	if not objective.ensureActive(context) then
		error("native objective could not be attached for slot " .. tostring(context.slot))
	end
	intelligence.attach(context)
end

function core.startMap(state, worldObject, reason)
	prepareRuntimeReset(state)

	local report, selectionError = selector.select(worldObject)
	stateModule.beginMap(state, report.mapID, reason)
	state.lastSelectionReport = report

	if not game.playerActor then
		return report, "player-unavailable"
	end

	if not state.objectiveTaskRegistered or not objectiveHandler or type(objectiveHandler.createObjective) ~= "function" then
		return report, "native-objective-unavailable"
	end

	if not report.profile then
		return report, selectionError
	end

	local records = persistence.loadAll(report.mapID)

	if selectionError and #records == 0 then
		return report, selectionError
	end

	local selections = {}
	local wanted = math.max(#records, #(report.selectedEntries or {}))
	wanted = math.min(config.MAX_SIMULTANEOUS_CONTRACTS, wanted)

	for slot = 1, wanted do
		local record = records[slot]
		local replaySource
		if persistence.isReplayableFailure(record) then
			replaySource = record
			record = nil
		end
		local selected = record and findEntry(report, record.targetID) or report.selectedEntries[slot]

		if record and objective.wasFinished(report.mapID, record.slot or slot) and not record.rewardPaid then
			local payoutContext = {root = state, slot = record.slot or slot, mapID = state.mapID, worldToken = state.worldToken, contract = record, targetStatus = "resolving"}
			record.status = "payout_pending"
			record.resolvedReward = record.resolvedReward or record.reward
			persistence.save(record)
			rewards.pay(payoutContext)
		end

		if record and not persistence.isTerminal(record) and not selected then
			record.status = "failed_invalid"
			record.resolution = "saved-target-unavailable"
			persistence.save(record)
		elseif selected and (not record or not persistence.isTerminal(record)) then
			if not record then
				local attempt = replaySource and math.max(1, tonumber(replaySource.attempt) or 1) + 1 or 1
				local seedInput = tostring(report.mapID) .. ":" .. tostring(slot) .. ":" .. selected.data.id
				if replaySource then seedInput = seedInput .. ":retry:" .. tostring(attempt) end
				local seed = util.stableHash(seedInput)
				local archetype = mapRegistry.chooseArchetype(report.profile, seed)
				local profile = profiles.resolve(seed, archetype)
				local reward = calculateReward(report, profile)
				record = persistence.create(report.mapID, selected.data.id, seed, reward, profile.id, report.profile.id, slot, attempt)
				record.threatRating = balance.snapshot(profile).threatRating
				record.condition = conditions.create(seed, reward)
				if replaySource then
					util.log(config, "failed contract restarted map=" .. tostring(report.mapID) .. " slot=" .. tostring(slot) .. " attempt=" .. tostring(attempt))
				end
			end

			record.slot = slot
			local profile = profiles.resolve(record.seed, record.archetype)
			record.archetype = profile.id
			record.threatRating = record.threatRating or balance.snapshot(profile).threatRating
			record.profileID = record.profileID or report.profile.id
			record.metrics = record.metrics or {}
			record.condition = record.condition or conditions.create(record.seed, record.baseReward or record.reward)
			table.insert(selections, {record = record, selected = selected})
		end
	end

	if #selections == 0 then
		state.contract = records[1]
		state.targetStatus = state.contract and state.contract.status or "none"
		return report, state.contract and state.contract.status == "failed_invalid" and "saved-target-unavailable" or "contract-terminal"
	end

	-- Reserve every target before assigning a single guard, preventing targets
	-- and protection details from leaking into another contract context.
	for _, selection in ipairs(selections) do
		selection.selected.npc._hcoReservedTarget = selection.record.contractID
	end

	local activationOK, activationError = pcall(function()
		local fairEscortLimit = math.max(5, math.floor((#report.eligible - #selections) / #selections))
		for _, selection in ipairs(selections) do
			local context = stateModule.createContext(state, selection.record.slot)
			context.escortLimit = fairEscortLimit
			activateContext(state, context, selection.record, selection.selected, report)
		end
		stateModule.syncPrimary(state)
		state.compromisedDisguises = state.contract and state.contract.compromisedDisguises or {}
		disguise.restore(state)
	end)

	if not activationOK then
		for _, context in ipairs(stateModule.getContexts(state)) do pcall(objective.failActive, context) end
		prepareRuntimeReset(state)
		stateModule.beginMap(state, report.mapID, "contract-activation-failed")
		state.lastSelectionReport = report
		util.log(config, "contract activation rolled back map=" .. tostring(report.mapID) .. " error=" .. tostring(activationError))

		return report, "contract-activation-failed"
	end

	util.log(config, "contracts active map=" .. tostring(report.mapID) .. " count=" .. tostring(#state.contracts))

	return report, nil
end

function core.onTargetNeutralized(state, npc)
	local context = state.root and state or stateModule.findContextByActor(state, npc)
	if context and npc == context.target and util.worldMatches(context, npc) and context.targetStatus == "active" then
		context.targetStatus = "neutralized"

		if context.contract and not persistence.isTerminal(context.contract) then
			context.contract.status = "neutralized"
			context.contract.resolution = "neutralized"
			persistence.save(context.contract)
		end
		if context.root then stateModule.syncPrimary(context.root) end
	end
end

function core.onTargetDied(state, npc, attacker)
	local context = state.root and state or stateModule.findContextByActor(state, npc)
	if not context or npc ~= context.target or not util.worldMatches(context, npc) then
		return
	end

	if context.contract and context.contract.rewardPaid then
		context.targetStatus = "completed"

		return
	end

	context.targetStatus = "killed"
	context.targetKillerID = util.getID(attacker)

	if context.contract and not persistence.isTerminal(context.contract) then
		context.contract.status = "killed"
		context.contract.resolution = "killed"
		persistence.save(context.contract)
	end
	if context.root then stateModule.syncPrimary(context.root) end
end

function core.clearMap(state)
	prepareRuntimeReset(state)
	stateModule.resetRuntime(state, "game-unloaded")
end

return core
