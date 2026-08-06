local conditions = require("hco/contracts/conditions")
local config = require("hco/config")
local english = require("hco/localization/english")
local persistence = require("hco/contracts/persistence")
local profiles = require("hco/contracts/profiles")
local rewards = require("hco/contracts/rewards")
local stateModule = require("hco/state")
local util = require("hco/util")

local contractObjective = {}

local registeredConfigs = {}

local function objectiveID(mapID, slot)
	return "hco_contract_" .. tostring(util.stableHash(mapID)) .. "_" .. tostring(slot or 1)
end

local function getObjective(mapID, slot)
	if not objectiveHandler or type(objectiveHandler.getObjectives) ~= "function" then
		return nil
	end

	local id = objectiveID(mapID, slot)
	local ok, objectives = util.call(objectiveHandler, "getObjectives")

	if not ok or type(objectives) ~= "table" then
		return nil
	end

	for _, objectiveObject in ipairs(objectives) do
		local okID, value = util.call(objectiveObject, "getID")

		if okID and value == id then
			return objectiveObject
		end
	end

	return nil
end

local function removeMarker(state)
	local uid = config.OBJECTIVE_UID .. "_" .. tostring(state.slot or 1)
	if movePosIndicator and movePosIndicator.EVENTS and movePosIndicator.EVENTS.NOTIFY_OBJECTIVE_ID_REMOVE then
		events:fire(movePosIndicator.EVENTS.NOTIFY_OBJECTIVE_ID_REMOVE, uid)
	end

	state.targetMarker = nil
end

local function registerTask(state)
	if state.objectiveTaskRegistered then
		return true
	end

	if not objectiveHandler or type(objectiveHandler.registeredTasksByID) ~= "table" or not objectiveHandler.registeredTasksByID.base_task then
		return false
	end

	if objectiveHandler.registeredTasksByID[config.OBJECTIVE_TASK_ID] then
		state.objectiveTaskRegistered = true

		return true
	end

	local catchable = {}

	if actor and actor.EVENTS then
		if actor.EVENTS.NEUTRALIZED then
			table.insert(catchable, actor.EVENTS.NEUTRALIZED)
		end

		if actor.EVENTS.DIED then
			table.insert(catchable, actor.EVENTS.DIED)
		end
	end

	local task = {
		id = config.OBJECTIVE_TASK_ID,
		LISTED = false,
		CATCHABLE_EVENTS = catchable
	}

	function task:initConfig(cfg)
		task.baseClass.initConfig(self, cfg)
		self.completed = false
		self.mapID = cfg.mapID
		self.contractID = cfg.contractID
	end

	function task:handleEvent(event, object)
		local root = stateModule.acquire()
		local runtime = stateModule.findContextByContractID(root, self.contractID)
		local id = util.getID(object)

		if self.completed or not runtime or runtime.mapID ~= self.mapID or not runtime.targetID or id ~= tostring(runtime.targetID) then
			return
		end

		if object ~= runtime.target or not util.worldMatches(runtime, object) then
			return
		end

		if runtime.contract and not persistence.isTerminal(runtime.contract) then
			local reward = conditions.settle(runtime)

				runtime.contract.resolvedReward = reward
				runtime.contract.status = "resolving"
			runtime.contract.resolution = event == actor.EVENTS.NEUTRALIZED and "neutralized" or "killed"
			persistence.save(runtime.contract)
		end

		self.completed = true
		runtime.targetStatus = event == actor.EVENTS.NEUTRALIZED and "neutralized" or "killed"
	end

	objectiveHandler:registerNewTask(task, "base_task")
	state.objectiveTaskRegistered = true

	return true
end

function contractObjective.getID(mapID, slot)
	return objectiveID(mapID, slot)
end

function contractObjective.wasFinished(mapID, slot)
	local playthrough = game and game.playthrough

	if not playthrough or type(playthrough.hasFinishedObjective) ~= "function" then
		return false
	end

	local ok, result = pcall(playthrough.hasFinishedObjective, playthrough, objectiveID(mapID, slot))

	return ok and result and true or false
end

function contractObjective.ensureConfig(mapID, slot)
	slot = slot or 1
	local id = objectiveID(mapID, slot)
	local existing = objectiveHandler and objectiveHandler.getObjectiveData and objectiveHandler:getObjectiveData(id)

	if existing then
		registeredConfigs[mapID] = existing

		return existing
	end

	local objectiveConfig = {
		id = id,
		mapID = tostring(mapID),
		slot = slot,
		icon = "quest_getting_started",
		tracked = true,
		-- `registerNewObjective` replaces the literal boolean `true` with the
		-- static `description` field. Keep a truthy string here so the native
		-- objective start indicator calls our dynamic `getStartString` method.
		startString = "OPTIONAL CONTRACT AVAILABLE",
		autoClaim = true,
			-- Do not expose a native funds reward here. The game's generic objective
			-- claimant calls the hideout-only global `studio`, which is nil in normal
			-- campaign missions. HCO settles campaign money through game.playthrough.
			reward = nil,
			baseReward = config.BASE_REWARD,
		task = {
			id = config.OBJECTIVE_TASK_ID,
			uid = config.OBJECTIVE_UID .. "_" .. tostring(slot),
			mapID = tostring(mapID),
			contractID = nil
		}
	}

	function objectiveConfig:getDescription()
		local root = stateModule.acquire()
		local runtime = stateModule.findContextByContractID(root, self.contractID) or root.contracts[self.slot]
		if not runtime or not runtime.contract then return "OPTIONAL CONTRACT — Locate field intelligence" end
		local record = runtime.contract
		local reward = record and record.baseReward or self.baseReward
		local profile = profiles.resolve(record and record.seed or 0, record and record.archetype)
		local conditionText = record and conditions.getDescription(record.condition) or nil
		local phase = runtime.targetAI and runtime.targetAI.phase or "ROUTINE"

		if not runtime.intelligence or runtime.intelligence.status ~= "revealed" then
			return "CONTRACT " .. tostring(self.slot) .. " — Recover marked field intelligence"
		end
		return "CONTRACT " .. tostring(self.slot) .. " — " .. english.contractTrackText(profile.name, phase)
	end

	function objectiveConfig:getStartString()
		local root = stateModule.acquire()
		local runtime = stateModule.findContextByContractID(root, self.contractID) or root.contracts[self.slot]
		if not runtime or not runtime.contract then return "OPTIONAL CONTRACT AVAILABLE" end
		local record = runtime.contract
		local reward = record and record.baseReward or self.baseReward
		local profile = profiles.resolve(record and record.seed or 0, record and record.archetype)
		local conditionText = record and conditions.getDescription(record.condition) or nil

		return english.contractStartText(profile.name, reward, conditionText)
	end

	function objectiveConfig:onFinish()
		local root = stateModule.acquire()
		local runtime = stateModule.findContextByContractID(root, self.contractID) or root.contracts[self.slot]

		if runtime and runtime.contract and runtime.mapID == self.mapID and runtime.contract.status ~= "failed_escaped" then
			if not rewards.pay(runtime) then
				runtime.pendingRewardPayment = true
			end
			removeMarker(runtime)
			util.log(config, "contract completed map=" .. tostring(self.mapID) .. " reward=$" .. tostring(runtime.contract.resolvedReward))
		end
	end

	objectiveHandler:registerNewObjective(objectiveConfig)
	registeredConfigs[mapID] = objectiveConfig

	return objectiveConfig
end

local function registerAllMaps()
	if not maps or type(maps.registered) ~= "table" then
		return
	end

	for _, mapData in ipairs(maps.registered) do
		local ok, mapID = util.call(mapData, "getID")

		if not ok then
			mapID = mapData.id
		end

		if mapID then
			for slot = 1, config.MAX_SIMULTANEOUS_CONTRACTS do contractObjective.ensureConfig(tostring(mapID), slot) end
		end
	end
end

function contractObjective.initialize(state)
	if not registerTask(state) then
		error("native base objective task is unavailable")
	end

	registerAllMaps()

	if not state.objectiveRegistryListenerInstalled and game.EVENTS.POST_MODS_LOADED then
		local listener = {}

		function listener:handleEvent()
			registerAllMaps()
		end

		state.objectiveRegistryListener = listener
		state.objectiveRegistryListenerInstalled = true
		events:addDirectReceiver(listener, {game.EVENTS.POST_MODS_LOADED})
	end
end

function contractObjective.attachMarker(state)
	removeMarker(state)

	if not state.target or not movePosIndicator or type(movePosIndicator.addPosition) ~= "function" then
		return false
	end

	local uid = config.OBJECTIVE_UID .. "_" .. tostring(state.slot or 1)
	local ok, marker = pcall(movePosIndicator.addPosition, movePosIndicator, 0, 0, -1, -1, "objectHandler", nil, state.target, uid)

	if ok then
		state.targetMarker = marker

		return true
	end

	return false
end

function contractObjective.attachIntelMarker(state, anchor)
	removeMarker(state)
	if not anchor or not movePosIndicator or type(movePosIndicator.addPosition) ~= "function" then return false end
	local uid = config.OBJECTIVE_UID .. "_" .. tostring(state.slot or 1)
	local ok, marker = pcall(movePosIndicator.addPosition, movePosIndicator, 0, 0, -1, 72, "objectHandler", nil, anchor, uid)
	if ok then state.targetMarker = marker return true end
	return false
end

function contractObjective.ensureActive(state)
	if not state.contract or persistence.isTerminal(state.contract) then
		return false
	end

	local objectiveConfig = contractObjective.ensureConfig(state.mapID, state.slot)
	objectiveConfig.contractID = state.contract.contractID
	objectiveConfig.task.contractID = state.contract.contractID
	objectiveConfig.baseReward = state.contract.baseReward or state.contract.reward or config.BASE_REWARD

	if not getObjective(state.mapID, state.slot) then
		if not objectiveHandler.objectives then
			return false
		end

		local objectiveObject = objectiveHandler:createObjective(objectiveConfig)

		table.insert(objectiveHandler.objectives, objectiveObject)
		objectiveObject:start()
	end

	return true
end

function contractObjective.updateHUD(state)
	local objectiveObject = state and state.mapID and getObjective(state.mapID, state.slot)

	if objectiveObject then
		util.call(objectiveObject, "updateHUDElement")
	end
end

function contractObjective.failActive(state)
	local objectiveObject = state and state.mapID and getObjective(state.mapID, state.slot)

	removeMarker(state)

	if objectiveObject then
		local ok = util.call(objectiveObject, "remove")

		if not ok then
			util.call(objectiveObject, "fail")
		end
	end
end

function contractObjective.removeMarker(state)
	removeMarker(state)
end

return contractObjective
