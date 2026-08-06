local config = require("hco/config")
local persistence = require("hco/contracts/persistence")
local drones = require("hco/security/drones")
local profiles = require("hco/contracts/profiles")
local util = require("hco/util")

local director = {}
local setKnowledge

local function forceCombatContact(actorObject, player, x, y)
	if not util.isAlive(actorObject) or not player then
		return false
	end

	if not x then x, y = util.getPos(player) end
	if not tonumber(x) or not tonumber(y) then
		return false
	end

	util.call(actorObject, "setSightPos", x, y, true)
	util.call(actorObject, "setSightTime", 0)
	util.call(actorObject, "setEnemyInSight", true, player)
	local okState, stateObject = util.call(actorObject, "getState")

	if okState and stateObject and type(stateObject.goToCombat) == "function" then
		local ok = pcall(stateObject.goToCombat, stateObject, true)
		if ok then return true end
	end

	local okCombat, combatState = util.call(actorObject, "getStateObject", actorObject.COMBAT_STATE or "goon_combat")
	if okCombat and combatState then
		local ok = util.call(actorObject, "setState", combatState)
		return ok == true
	end

	return false
end

local function mobilizeProtection(state, x, y, reason)
	local security = state.security
	local player = game and game.playerActor
	if not security or not player then return end

	if not x then x, y = util.getPos(player) end
	security.lastKnown = {x=x, y=y, confidence=1, source=reason, time=curTime or 0, actor=player}
	security.targetThreatLevel = 1
	security.huntPhase = "PRESSURE"
	forceCombatContact(state.target, player, x, y)

	for _, guard in ipairs(security.guards or {}) do
		forceCombatContact(guard.actor, player, x, y)
		setKnowledge(security, guard.actor, x, y, 1, reason)
	end

	drones.request(state, security.droneDoctrine.count or config.DRONE_DEPLOY_COUNT, reason)
	util.log(config, "protection mobilized slot=" .. tostring(state.slot or 1) .. " reason=" .. tostring(reason))
end

local function addSectorPoint(points, seen, x, y, source)
	if not tonumber(x) or not tonumber(y) then
		return
	end

	local key = tostring(math.floor(x / 24)) .. ":" .. tostring(math.floor(y / 24))

	if seen[key] then
		return
	end

	seen[key] = true
	table.insert(points, {x = x, y = y, source = source})
end

local function buildSectorPoints(report)
	local points, seen = {}, {}

	for _, entry in ipairs(report.eligible or {}) do
		local okRoute, route = util.call(entry.npc, "getActivePatrolRoute")
		local okIndexes, indexes = util.call(route, "getIndexes")

		if okRoute and okIndexes and type(indexes) == "table" then
			for _, point in ipairs(indexes) do
				local okPos, x, y = util.call(point, "getPos")

				if okPos then
					addSectorPoint(points, seen, x, y, entry.data.id)
				end
			end
		end
	end

	return points
end

local function getRadio(actorObject)
	local ok, radio = util.call(actorObject, "getRadio")

	return ok and radio or nil
end

local function radioCanTransmit(actorObject)
	local radio = getRadio(actorObject)

	if not radio then
		return false
	end

	local okOpen, open = util.call(radio, "isOpen")
	local okDisrupted, disrupted = util.call(radio, "isDisrupted")

	return (not okOpen or open == true) and (not okDisrupted or disrupted ~= true)
end

local function directKnowledge(actorObject, player)
	local okSight, enemyInSight = util.call(actorObject, "getEnemyInSight", player)

	if okSight and enemyInSight then
		local okPos, x, y = util.call(actorObject, "getSightPos")

		if not okPos or not tonumber(x) or not tonumber(y) then
			x, y = util.getPos(player)
		end

		return x, y, 1, "direct"
	end

	local okTime, hunchTime = util.call(actorObject, "getBestHunchTime")

	if okTime and tonumber(hunchTime) and hunchTime <= config.KNOWLEDGE_MAX_AGE then
		local okPos, x, y = util.call(actorObject, "getBestHunch")

		if okPos and tonumber(x) and tonumber(y) then
			return x, y, math.max(0.1, 1 - hunchTime / config.KNOWLEDGE_MAX_AGE), "native-hunch"
		end
	end

	return nil
end

setKnowledge = function(security, actorObject, x, y, confidence, source)
	local id = util.getID(actorObject)

	if not id or not x or not y then
		return nil
	end

	local entry = security.knowledge[id]

	if not entry or confidence >= entry.confidence or (curTime or 0) - entry.time > 2 then
		entry = {
			x = x,
			y = y,
			confidence = confidence,
			source = source,
			time = curTime or 0,
			actor = actorObject
		}
		security.knowledge[id] = entry
	end

	return entry
end

local function copyKnowledgeToRecipient(security, sender, recipient, entry, source)
	if not entry or not util.isAlive(recipient) then
		return false
	end

	local existing = security.knowledge[util.getID(recipient)]

	if existing and existing.confidence >= entry.confidence * 0.9 and (curTime or 0) - existing.time < 2 then
		return false
	end

	util.call(recipient, "receiveSightingData", sender)
	util.call(recipient, "setSightPos", entry.x, entry.y)
	setKnowledge(security, recipient, entry.x, entry.y, entry.confidence * 0.9, source)

	return true
end

local function updateHuntPhase(security, maxConfidence)
	local previous = security.huntPhase

	if maxConfidence >= 0.95 then
		security.huntPhase = "PRESSURE"
	elseif maxConfidence >= 0.7 then
		security.huntPhase = "CONTAIN"
	elseif maxConfidence >= 0.3 then
		security.huntPhase = "SEARCH"
	elseif maxConfidence >= 0.15 then
		security.huntPhase = "LOCAL_REACTION"
	elseif maxConfidence > 0.05 then
		security.huntPhase = "DECAY"
	else
		security.huntPhase = "STAND_DOWN"
	end

	if previous ~= security.huntPhase then
		util.log(config, "security hunt phase=" .. tostring(security.huntPhase))
	end
end

local function alertnessThreat(actorObject)
	local ok, alertness = util.call(actorObject, "getAlertnessStateID")
	local states = npcAlertnessStates and npcAlertnessStates.STATES

	if not ok or not states then
		return 0
	end

	if alertness >= states.COMBAT then
		return 1
	elseif alertness >= states.ALERT then
		return 0.75
	elseif alertness >= states.SUSPICION then
		return 0.3
	end

	return 0
end

function director.attach(state, report)
	local security = {
		guards = {},
		knowledge = {},
		huntPhase = "STAND_DOWN",
		targetThreatLevel = 0,
		sampleTime = 0,
		lastKnown = nil,
		bodyEvidence = nil,
		evidencePositions = {},
		sectorPoints = buildSectorPoints(report),
		searchStep = 0,
		searchOrderTime = 0,
		seenBodies = {},
		drones = {},
		droneCooldown = 0
	}
	local profile = profiles.resolve(state.contract and state.contract.seed or 0, state.contract and state.contract.archetype)
	security.droneDoctrine = profile.drone or {name="Search", count=config.DRONE_DEPLOY_COUNT, speed=1, radius=1, detect=1, armor=1}
	local escortLookup = {}

	for index, escortData in ipairs(state.escorts or {}) do
		escortLookup[escortData.actor] = escortData
	end

	for _, escortData in ipairs(state.escorts or {}) do
		local actorObject = escortData.actor
		actorObject._hcoSecurityRole = escortData.role
		local _, health = util.call(actorObject, "getHealth")
		table.insert(security.guards, {actor = actorObject, id = escortData.id, role = escortData.role, lastHealth = health})
	end

	state.target._hcoSecurityRole = "protected_target"
	state.security = security

	if state.contract and state.contract.metrics then
		state.contract.metrics.initialEscortCount = math.max(state.contract.metrics.initialEscortCount or 0, #state.escorts)
		state.contract.metrics.livingEscortCount = #state.escorts
		persistence.save(state.contract)
	end
end

function director.detach(state)
	if state.security then
		for _, guard in ipairs(state.security.guards or {}) do
			if guard.actor then
				guard.actor._hcoSecurityRole = nil
			end
		end
	end

	if state.target then
		state.target._hcoSecurityRole = nil
	end

	state.security = nil
end

function director.notifyBodyEvidence(state, observer, body)
	local security = state.security

	if not security or not util.isAlive(observer) then
		return
	end

	local x, y = util.getPos(body)

	if not x then
		return
	end

	security.bodyEvidence = {x = x, y = y, time = curTime or 0, observer = observer}
	table.insert(security.evidencePositions, {x = x, y = y, time = curTime or 0, source = "body"})

	while #security.evidencePositions > 6 do
		table.remove(security.evidencePositions, 1)
	end
	setKnowledge(security, observer, x, y, 0.35, "body-evidence")

	if util.distance(observer, state.target) <= config.KNOWLEDGE_NEARBY_RANGE or radioCanTransmit(observer) then
		security.targetThreatLevel = math.max(security.targetThreatLevel, 0.35)
	end

	if state.contract and state.contract.metrics then
		state.contract.metrics.bodyDiscoveries = (state.contract.metrics.bodyDiscoveries or 0) + 1
		persistence.save(state.contract)
	end

	drones.request(state, security.droneDoctrine.count or config.DRONE_DEPLOY_COUNT, "body-evidence")
end

local function scanBodyEvidence(state)
	local security = state.security
	if not security or not game.worldObject then return end
	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		local bodyID = util.getID(body)
		if body ~= state.target and bodyID and not security.seenBodies[bodyID] and not util.isAlive(body) then
			for _, guard in ipairs(security.guards) do
				if util.isAlive(guard.actor) and util.distance(guard.actor, body) <= 260 then
					security.seenBodies[bodyID] = true
					director.notifyBodyEvidence(state, guard.actor, body)
					break
				end
			end
		end
	end
end

local function scanMissionContact(state, player)
	local security = state.security
	if not security or security.dronesTriggeredByContact or not game.worldObject then return end
	for _, observer in ipairs(util.getNPCs(game.worldObject)) do
		if observer ~= state.target and util.isAlive(observer) then
			local okSight, seen = util.call(observer, "getEnemyInSight", player)
			if okSight and seen and (util.distance(observer, state.target) <= 900 or radioCanTransmit(observer)) then
				local x, y = util.getPos(player)
				security.dronesTriggeredByContact = true
				mobilizeProtection(state, x, y, "mission-hostile-contact")
				util.log(config, "drone deployment requested by mission contact slot=" .. tostring(state.slot or 1) .. " observer=" .. tostring(util.getID(observer)))
				return
			end
		end
	end
end

function director.notifySensorEvidence(state, sensor, source)
	local security = state.security
	local x, y = util.getPos(sensor)

	if not security or not x then
		return
	end

	table.insert(security.evidencePositions, {x = x, y = y, time = curTime or 0, source = source or "sensor"})
	security.targetThreatLevel = math.max(security.targetThreatLevel, 0.25)

	while #security.evidencePositions > 6 do
		table.remove(security.evidencePositions, 1)
	end
end

local function rankSearchSectors(security)
	local lastKnown = security.lastKnown
	local ranked = {}

	if not lastKnown then
		return ranked
	end

	for index, point in ipairs(security.sectorPoints) do
		local dx, dy = point.x - lastKnown.x, point.y - lastKnown.y
		table.insert(ranked, {point = point, distance = math.sqrt(dx * dx + dy * dy), index = index})
	end

	table.sort(ranked, function(a, b)
		if a.distance == b.distance then
			return a.index < b.index
		end

		return a.distance < b.distance
	end)

	return ranked
end

local function issueSearchOrders(state, dt)
	local security = state.security

	security.searchOrderTime = security.searchOrderTime - dt

	if security.searchOrderTime > 0 or not security.lastKnown or security.huntPhase == "STAND_DOWN" or security.huntPhase == "DECAY" then
		return
	end

	security.searchOrderTime = security.huntPhase == "PRESSURE" and 2.5 or 5
	local sectors = rankSearchSectors(security)

	if #sectors == 0 then
		return
	end

	security.searchStep = security.searchStep + 1
	local searchers = {}

	for _, guard in ipairs(security.guards) do
		if guard.role ~= "close_protection" and guard.role ~= "camera_operator" and util.isAlive(guard.actor) then
			local _, enemyInSight = util.call(guard.actor, "getEnemyInSight", game.playerActor)

			if not enemyInSight then
				table.insert(searchers, guard)
			end
		end
	end

	for index, guard in ipairs(searchers) do
		local sectorIndex = (security.searchStep + index - 2) % math.min(#sectors, math.max(2, #searchers)) + 1
		local point = sectors[sectorIndex].point
		local actorObject = guard.actor

		if actorObject.grid and type(actorObject.grid.worldToGrid) == "function" then
			local gridX, gridY = actorObject.grid:worldToGrid(point.x, point.y)
			local okState, stateObject = util.call(actorObject, "getState")

			util.call(actorObject, "setDestPos", gridX, gridY)
			util.call(actorObject, "setSightPos", security.lastKnown.x, security.lastKnown.y, true)

			if okState and stateObject and type(stateObject.goToAlert) == "function" then
				pcall(stateObject.goToAlert, stateObject)
			end
		end
	end
end

function director.update(state, dt)
	local security = state.security
	local player = game and game.playerActor

	if not security or not player or not util.isAlive(state.target) then
		return
	end

	security.sampleTime = security.sampleTime + dt

	if security.sampleTime < config.KNOWLEDGE_SAMPLE_INTERVAL then
		return
	end

	local elapsed = security.sampleTime
	security.sampleTime = 0
	local lostGuard = false
	local damagedGuard = false
	for _, guard in ipairs(security.guards or {}) do
		local alive = util.isAlive(guard.actor)
		local _, health = util.call(guard.actor, "getHealth")
		if guard.wasAlive ~= false and not alive then lostGuard = true end
		if alive and tonumber(health) and tonumber(guard.lastHealth) and health < guard.lastHealth then damagedGuard = true end
		guard.wasAlive = alive
		guard.lastHealth = health
	end
	if lostGuard or damagedGuard then
		security.dronesTriggeredByContact = true
		mobilizeProtection(state, nil, nil, lostGuard and "protection-casualty" or "protection-under-fire")
	end
	scanBodyEvidence(state)
	scanMissionContact(state, player)
	local actors = {{actor = state.target, role = "protected_target"}}

	for _, guard in ipairs(security.guards) do
		table.insert(actors, guard)
	end

	local maxConfidence = 0
	local freshSources = {}

	for _, data in ipairs(actors) do
		local actorObject = data.actor

		if util.isAlive(actorObject) then
			local x, y, confidence, source = directKnowledge(actorObject, player)
			local alertThreat = alertnessThreat(actorObject)

			if x then
				local entry = setKnowledge(security, actorObject, x, y, math.max(confidence, alertThreat), source)
				table.insert(freshSources, {actor = actorObject, entry = entry, role = data.role})
				maxConfidence = math.max(maxConfidence, entry.confidence)

				if entry.confidence >= 0.95 and state.contract and state.contract.metrics and not state.contract.metrics.alarmRaised then
					state.contract.metrics.alarmRaised = true
					persistence.save(state.contract)
				end

				if entry.confidence >= 0.95 and not security.dronesTriggeredByContact then
					security.dronesTriggeredByContact = true
					drones.request(state, security.droneDoctrine.count or config.DRONE_DEPLOY_COUNT, "confirmed-hostile-contact")
					util.log(config, "drone deployment requested by confirmed contact slot=" .. tostring(state.slot or 1))
				end
			else
				local entry = security.knowledge[util.getID(actorObject)]

				if entry then
					entry.confidence = math.max(0, entry.confidence - elapsed / config.KNOWLEDGE_MAX_AGE)
					maxConfidence = math.max(maxConfidence, entry.confidence)
				end
			end
		end
	end

	local targetKnowledge = security.knowledge[util.getID(state.target)]
	local targetThreat = targetKnowledge and targetKnowledge.confidence or alertnessThreat(state.target)

	for _, source in ipairs(freshSources) do
		for _, recipient in ipairs(actors) do
			if recipient.actor ~= source.actor and util.isAlive(recipient.actor) then
				local nearby = util.distance(source.actor, recipient.actor) <= config.KNOWLEDGE_NEARBY_RANGE
				local radio = source.entry.confidence >= 0.7 and radioCanTransmit(source.actor)

				if nearby or radio then
					local shared = copyKnowledgeToRecipient(security, source.actor, recipient.actor, source.entry, radio and "radio" or "nearby-warning")

					if shared and recipient.actor == state.target then
						targetThreat = math.max(targetThreat, source.entry.confidence * 0.9)
					end
				end
			end
		end
	end

	security.targetThreatLevel = math.max(0, math.max(targetThreat, security.targetThreatLevel - elapsed / config.KNOWLEDGE_MAX_AGE))
	security.lastKnown = nil

	for _, entry in pairs(security.knowledge) do
		if not security.lastKnown or entry.confidence > security.lastKnown.confidence then
			security.lastKnown = entry
		end
	end

	updateHuntPhase(security, maxConfidence)
	issueSearchOrders(state, elapsed)

	if state.contract and state.contract.metrics then
		local living = 0

		for _, escortData in ipairs(state.escorts or {}) do
			if util.isAlive(escortData.actor) then
				living = living + 1
			end
		end

		state.contract.metrics.livingEscortCount = living
	end
end

return director
