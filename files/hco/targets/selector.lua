local config = require("hco/config")
local diagnostics = require("hco/diagnostics")
local mapRegistry = require("hco/maps/registry")
local util = require("hco/util")

local selector = {}

local actorReferenceKeys = {
	npc = true,
	npcID = true,
	objectID = true,
	targetID = true,
	actorID = true
}

local unsafeStates = {
	goon_cutscene = true,
	goon_dummy = true,
	goon_scene = true
}

local function collectReferences(value, output, seen, depth)
	if type(value) ~= "table" or seen[value] or depth > 8 then
		return
	end

	seen[value] = true

	for key, child in pairs(value) do
		if actorReferenceKeys[key] and (type(child) == "string" or type(child) == "number") then
			output[tostring(child)] = true
		elseif type(child) == "table" then
			collectReferences(child, output, seen, depth + 1)
		end
	end
end

local function collectObjectiveActorIDs()
	local result = {}

	if not objectiveHandler then
		return result
	end

	local ok, objectives = util.call(objectiveHandler, "getObjectives")

	if ok and type(objectives) == "table" then
		for _, objectiveObject in ipairs(objectives) do
			collectReferences(objectiveObject.config, result, {}, 0)

			local okTask, task = util.call(objectiveObject, "getTask")

			if okTask then
				collectReferences(task and task.config, result, {}, 0)
			end
		end
	end

	return result
end

local function inspect(npc, mapID, objectiveActorIDs, profile)
	local data = diagnostics.snapshot(npc)
	local reasons = {}

	if data.class ~= "goon" then
		table.insert(reasons, "not-goon")
	end

	if data.id == "missing" then
		table.insert(reasons, "missing-id")
	end

	if not util.isValid(npc) then
		table.insert(reasons, "invalid")
	end

	if data.dead then
		table.insert(reasons, "dead")
	end

	if data.unconscious then
		table.insert(reasons, "unconscious")
	end

	if config.REQUIRE_PATROL_ROUTE and not data.hasPatrol then
		table.insert(reasons, "no-patrol")
	elseif data.patrolPointCount < config.MIN_ROUTE_POINTS then
		table.insert(reasons, "insufficient-route-nodes")
	end

	if config.EXCLUDE_NAMED_NPCS and (data.mapNameKey ~= "" or data.mapName ~= "") then
		table.insert(reasons, "named-story-risk")
	end

	if objectiveActorIDs[data.id] then
		table.insert(reasons, "vanilla-objective-reference")
	end

	if unsafeStates[data.stateID] then
		table.insert(reasons, "scripted-state")
	end

	if data.follower ~= "none" then
		table.insert(reasons, "existing-follow-chain")
	end

	if profile.excludedActorIDs and profile.excludedActorIDs[data.id] then
		table.insert(reasons, "profile-excluded")
	end

	if profile.eligibleActorIDs and not profile.eligibleActorIDs[data.id] then
		table.insert(reasons, "not-profile-whitelisted")
	end

	local score = data.experience * 100 + data.patrolPointCount * 8

	if data.radio then
		score = score + 25
	end

	if data.keycard ~= "none" then
		score = score + 10
	end

	score = score + util.stableHash(tostring(mapID) .. ":" .. data.id) % 100

	return {
		npc = npc,
		data = data,
		reasons = reasons,
		eligible = #reasons == 0,
		score = score
	}
end

function selector.select(worldObject)
	local mapID = "unknown"
	local okMap, value = util.call(worldObject, "getMapID")

	if okMap and value ~= nil then
		mapID = tostring(value)
	end

	local profile, profileError = mapRegistry.resolve(mapID)
	local report = {
		mapID = mapID,
		profile = profile,
		total = 0,
		entries = {},
		eligible = {},
		selected = nil,
		selectedEntries = {}
	}

	if not profile then
		return report, profileError
	end

	local okNPCs, npcs = util.call(worldObject, "getNPCs")

	if not okNPCs or type(npcs) ~= "table" then
		return report, "world-npc-list-unavailable"
	end

	local objectiveActorIDs = collectObjectiveActorIDs()

	for _, npc in ipairs(npcs) do
		local entry = inspect(npc, mapID, objectiveActorIDs, profile)
		report.total = report.total + 1
		table.insert(report.entries, entry)

		if entry.eligible then
			table.insert(report.eligible, entry)
		end
	end

	table.sort(report.eligible, function(a, b)
		if a.score == b.score then
			return a.data.id < b.data.id
		end

		return a.score > b.score
	end)

	if #report.eligible < config.MIN_CONTRACT_ACTORS then
		return report, "insufficient-safe-contract-actors"
	end

	local wanted = 1
	if #report.eligible >= config.THREE_CONTRACT_ACTOR_THRESHOLD then
		wanted = math.min(3, config.MAX_SIMULTANEOUS_CONTRACTS)
	elseif #report.eligible >= config.TWO_CONTRACT_ACTOR_THRESHOLD then
		wanted = math.min(2, config.MAX_SIMULTANEOUS_CONTRACTS)
	end

	-- Spread targets across the ranked candidate list rather than selecting a
	-- cluster of neighboring high-score actors. Escort assignment reserves its
	-- actors later, so every selected target remains exclusive to one contract.
	for slot = 1, wanted do
		local index = math.floor((slot - 1) * #report.eligible / wanted) + 1
		local entry = report.eligible[index]
		if entry then table.insert(report.selectedEntries, entry) end
	end

	report.selected = report.selectedEntries[1]

	if report.selected then
		return report, nil
	end

	return report, "no-safe-candidate"
end

return selector
