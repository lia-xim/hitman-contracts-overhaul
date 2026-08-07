local stateModule = {}
local util = require("hco/util")

local PLAYER_KEY = "_hitmanContractsOverhaulState"

local function clearTargetMarker(state)
	if state.target then
		state.target._hcoContractTarget = nil
		state.target._hcoContractID = nil
		state.target._hcoWorldToken = nil
		state.target._hcoReservedTarget = nil
	end
end

local function newContext(root, slot)
	return {
		root = root,
		slot = slot,
		mapID = root.mapID,
		worldToken = root.worldToken,
		contract = nil,
		target = nil,
		targetID = nil,
		targetStatus = "none",
		targetMarker = nil,
		escorts = {},
		targetAI = nil,
		security = nil,
		subsystemErrors = {}
	}
end

function stateModule.acquire()
	-- Intravenous 2's Workshop/local-mod sandbox intentionally does not expose
	-- Lua's `_G` table. `playerActor` is a stable engine-owned class table and
	-- is also the state owner used successfully by the Cheat Trainer mod.
	local state = playerActor[PLAYER_KEY]

	if not state then
		state = {
			generation = 0,
			mapID = nil,
			contract = nil,
			contracts = {},
			target = nil,
			targetID = nil,
			targetStatus = "none",
			targetMarker = nil,
			escorts = {},
			targetAI = nil,
			disguise = nil,
			disguiseRisk = 1,
			compromisedDisguises = {},
			lastResetReason = "startup",
			listenerInstalled = false,
			listener = nil,
			objectiveTaskRegistered = false,
			objectiveRegistryListenerInstalled = false
		}
	end

	state.escorts = state.escorts or {}
	state.contracts = state.contracts or {}
	state.compromisedDisguises = state.compromisedDisguises or {}
	state.usedDisguiseSources = state.usedDisguiseSources or {}
	state.localCompromisedDisguises = state.localCompromisedDisguises or {}
	state.pendingCompromises = state.pendingCompromises or {}
	state.closeScrutiny = state.closeScrutiny or {}

	playerActor[PLAYER_KEY] = state

	return state
end

function stateModule.createContext(state, slot)
	local context = newContext(state, slot or (#state.contracts + 1))
	table.insert(state.contracts, context)
	return context
end

function stateModule.getContexts(state)
	if state.contracts and #state.contracts > 0 then
		return state.contracts
	end

	-- v2/hot-load compatibility while an old single-contract runtime exists.
	if state.target or state.contract then
		return {state}
	end

	return {}
end

function stateModule.findContextByActor(state, npc)
	for _, context in ipairs(stateModule.getContexts(state)) do
		if context.target == npc and util.worldMatches(context, npc) then
			return context
		end
	end

	return nil
end

function stateModule.findContextByContractID(state, contractID)
	for _, context in ipairs(stateModule.getContexts(state)) do
		if context.contract and tostring(context.contract.contractID) == tostring(contractID) then
			return context
		end
	end

	return nil
end


function stateModule.syncPrimary(state)
	local primary = state.contracts and state.contracts[1]
	state.contract = primary and primary.contract or nil
	state.target = primary and primary.target or nil
	state.targetID = primary and primary.targetID or nil
	state.targetStatus = primary and primary.targetStatus or "none"
	state.targetMarker = primary and primary.targetMarker or nil
	state.escorts = primary and primary.escorts or {}
	state.targetAI = primary and primary.targetAI or nil
	state.security = primary and primary.security or nil
end

function stateModule.resetRuntime(state, reason)
	clearTargetMarker(state)
	state.generation = (state.generation or 0) + 1
	state.worldToken = nil
	state.mapID = nil
	state.contract = nil
	state.contracts = {}
	state.target = nil
	state.targetID = nil
	state.targetStatus = "none"
	state.targetMarker = nil
	state.escorts = {}
	state.targetAI = nil
	state.security = nil
	state.disguise = nil
	state.disguiseRisk = 1
	state.compromisedDisguises = {}
	state.usedDisguiseSources = {}
	state.localCompromisedDisguises = {}
	state.pendingCompromises = {}
	state.closeScrutiny = {}
	state.lastLocalExposureFeedbackTime = nil
	state.hcoDroneRaidAnnounced = nil
	state.targetKillerID = nil
	state.lastResetReason = reason or "unspecified"
	state.lastSelectionReport = nil
	state.pendingContractStart = nil
	state.lastContractSkipReason = nil
	state.contractSkipNoticeShown = false
	state.runtimeDelta = nil
	state.pendingRewardPayment = nil
	state.escortUpdateTime = nil
	state.identityCheckTime = nil
	state.disguiseBodyHintShown = nil
	state.disguiseInteractionRefreshTime = nil
	state.disguiseBindingRefreshTime = 0
	state.subsystemErrors = {}
end

function stateModule.beginMap(state, mapID, reason)
	stateModule.resetRuntime(state, reason or "map-start")
	state.mapID = mapID
	state.worldToken = tostring(state.generation) .. ":" .. tostring(mapID)
end

function stateModule.assignTarget(state, target)
	clearTargetMarker(state)
	state.target = target
	state.targetID = target and util.getID(target) or nil
	state.targetStatus = target and "active" or "none"

	if target then
		target._hcoContractTarget = true
		target._hcoContractID = state.contract and state.contract.contractID or nil
		target._hcoWorldToken = state.worldToken
	end

	if state.root then
		stateModule.syncPrimary(state.root)
	end
end

return stateModule
