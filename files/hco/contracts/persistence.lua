local config = require("hco/config")
local util = require("hco/util")

local persistence = {}

local KEY_PREFIX = "__hco_contract_v3::"
local V2_KEY_PREFIX = "__hco_contract_v2::"
local LEGACY_KEY_PREFIX = "__hco_contract_v1::"

local terminalStatuses = {
	completed = true,
	failed_escaped = true,
	failed_invalid = true
}

local replayableFailureStatuses = {
	failed_escaped = true,
	failed_invalid = true
}

local function getKey(prefix, mapID)
	return prefix .. tostring(mapID)
end

local function copyCondition(source)
	if type(source) ~= "table" or not source.id then
		return nil
	end

	return {
		id = tostring(source.id),
		bonus = tonumber(source.bonus) or 0,
		result = source.result,
		settled = source.settled == true
	}
end

local function copyMetrics(source)
	source = type(source) == "table" and source or {}

	return {
		alarmRaised = source.alarmRaised == true,
		usedDisguise = source.usedDisguise == true,
		initialEscortCount = tonumber(source.initialEscortCount) or 0,
		livingEscortCount = tonumber(source.livingEscortCount) or 0,
		bodyDiscoveries = tonumber(source.bodyDiscoveries) or 0
	}
end

local function copyRecord(record)
	local reward = tonumber(record.reward) or config.BASE_REWARD

	return {
		version = 3,
		attempt = math.max(1, tonumber(record.attempt) or 1),
		slot = tonumber(record.slot) or 1,
		contractID = record.contractID and tostring(record.contractID) or "hco:" .. tostring(record.mapID) .. ":" .. tostring(record.targetID),
		mapID = tostring(record.mapID),
		targetID = record.targetID and tostring(record.targetID) or nil,
		seed = tonumber(record.seed) or 0,
		profileID = record.profileID and tostring(record.profileID) or nil,
		archetype = record.archetype and tostring(record.archetype) or nil,
		status = record.status or "active",
		baseReward = tonumber(record.baseReward) or reward,
		reward = reward,
		resolvedReward = tonumber(record.resolvedReward),
		rewardPaid = record.rewardPaid == true,
		resolution = record.resolution and tostring(record.resolution) or nil,
		condition = copyCondition(record.condition),
		metrics = copyMetrics(record.metrics),
		secureSwitches = tonumber(record.secureSwitches) or 0,
		targetPhase = record.targetPhase and tostring(record.targetPhase) or "ROUTINE",
		intelStatus = record.intelStatus and tostring(record.intelStatus) or "clue",
		intelX = tonumber(record.intelX),
		intelY = tonumber(record.intelY),
		safePointIndex = tonumber(record.safePointIndex),
		disguiseGroup = record.disguiseGroup and tostring(record.disguiseGroup) or nil,
		disguiseSourceID = record.disguiseSourceID and tostring(record.disguiseSourceID) or nil,
		disguiseKeycard = record.disguiseKeycard,
		disguiseKeychain = record.disguiseKeychain,
		disguiseTier = record.disguiseTier and tostring(record.disguiseTier) or nil,
		disguiseAccess = tonumber(record.disguiseAccess),
		disguiseWeaponType = record.disguiseWeaponType,
		disguiseWeaponID = record.disguiseWeaponID and tostring(record.disguiseWeaponID) or nil,
		disguiseOriginalAnimVar = record.disguiseOriginalAnimVar and tostring(record.disguiseOriginalAnimVar) or nil,
		disguiseAcquiredTime = tonumber(record.disguiseAcquiredTime),
		disguiseSourceWasDead = record.disguiseSourceWasDead == true,
		disguiseBloodied = record.disguiseBloodied == true,
		disguiseFactionVisual = tonumber(record.disguiseFactionVisual),
		usedDisguiseSources = util.copyStringMap(record.usedDisguiseSources),
		compromisedDisguises = util.copyStringMap(record.compromisedDisguises)
	}
end

function persistence.create(mapID, targetID, seed, reward, archetype, profileID, slot, attempt)
	attempt = math.max(1, tonumber(attempt) or 1)
	return copyRecord({
		contractID = "hco:" .. tostring(mapID) .. ":" .. tostring(slot or 1) .. ":a" .. tostring(attempt) .. ":" .. tostring(targetID) .. ":" .. tostring(seed),
		attempt = attempt,
		slot = slot or 1,
		mapID = tostring(mapID),
		targetID = tostring(targetID),
		seed = tonumber(seed) or 0,
		profileID = profileID,
		archetype = archetype,
		status = "active",
		baseReward = tonumber(reward) or config.BASE_REWARD,
		reward = tonumber(reward) or config.BASE_REWARD,
		rewardPaid = false,
		secureSwitches = 0,
		targetPhase = "ROUTINE",
		metrics = {},
		compromisedDisguises = {}
	})
end

local function loadKey(playthrough, key, mapID)
	local ok, record = pcall(playthrough.getPersistentMapData, playthrough, key)

	if not ok or type(record) ~= "table" or tostring(record.mapID) ~= tostring(mapID) then
		return nil
	end

	return copyRecord(record)
end

function persistence.load(mapID)
	local records = persistence.loadAll(mapID)
	return records[1]
end

function persistence.loadAll(mapID)
	local playthrough = game and game.playthrough

	if not playthrough or type(playthrough.getPersistentMapData) ~= "function" then
		return {}
	end

	local ok, bundle = pcall(playthrough.getPersistentMapData, playthrough, getKey(KEY_PREFIX, mapID))
	local result = {}

	if ok and type(bundle) == "table" and type(bundle.records) == "table" then
		for _, record in ipairs(bundle.records) do
			if tostring(record.mapID) == tostring(mapID) then
				table.insert(result, copyRecord(record))
			end
		end
	else
		local legacy = loadKey(playthrough, getKey(V2_KEY_PREFIX, mapID), mapID) or loadKey(playthrough, getKey(LEGACY_KEY_PREFIX, mapID), mapID)

		if legacy then
			legacy.slot = 1
			table.insert(result, legacy)
		end
	end

	table.sort(result, function(a, b) return (a.slot or 1) < (b.slot or 1) end)
	return result
end

function persistence.save(record)
	local playthrough = game and game.playthrough

	if not record or not playthrough or type(playthrough.setPersistentMapData) ~= "function" then
		return false
	end

	local records = persistence.loadAll(record.mapID)
	local replacement = copyRecord(record)
	local replaced = false

	for index, existing in ipairs(records) do
		if existing.contractID == replacement.contractID or existing.slot == replacement.slot then
			records[index] = replacement
			replaced = true
			break
		end
	end

	if not replaced then
		table.insert(records, replacement)
	end

	table.sort(records, function(a, b) return (a.slot or 1) < (b.slot or 1) end)
	local bundle = {version = 3, mapID = tostring(record.mapID), records = records}
	local ok, err = pcall(playthrough.setPersistentMapData, playthrough, getKey(KEY_PREFIX, record.mapID), bundle)

	if not ok then
		util.log(config, "contract persistence failed: " .. tostring(err))
	end

	return ok
end

function persistence.saveAll(mapID, records)
	local playthrough = game and game.playthrough

	if not playthrough or type(playthrough.setPersistentMapData) ~= "function" then
		return false
	end

	local copies = {}
	for _, record in ipairs(records or {}) do table.insert(copies, copyRecord(record)) end
	local ok, err = pcall(playthrough.setPersistentMapData, playthrough, getKey(KEY_PREFIX, mapID), {version = 3, mapID = tostring(mapID), records = copies})
	if not ok then util.log(config, "contract bundle persistence failed: " .. tostring(err)) end
	return ok
end

function persistence.isTerminal(record)
	return record and (record.rewardPaid or terminalStatuses[record.status] == true)
end

function persistence.isReplayableFailure(record)
	return record and record.rewardPaid ~= true and replayableFailureStatuses[record.status] == true
end

return persistence
