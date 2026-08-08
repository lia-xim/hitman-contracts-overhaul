local config = require("hco/config")
local english = require("hco/localization/english")
local feedback = require("hco/feedback")
local objective = require("hco/contracts/objective")
local persistence = require("hco/contracts/persistence")
local profiles = require("hco/contracts/profiles")
local util = require("hco/util")

local controller = {}

local combatStates = {
	goon_combat = true,
	goon_startled_combat = true,
	goon_alert = true
}

local THREAT_STATES = {
	goon_alert = true,
	goon_combat = true,
	goon_startled_combat = true,
	goon_fear = true,
	goon_fear_run_to_cover = true,
	goon_run_from_grenade = true
}

local UNEASY_STATES = {
	goon_suspicion = true,
	goon_investigate_body = true,
	goon_look_around = true
}

local function getStateID(target)
	local ok, stateObject = util.call(target, "getState")

	if ok and stateObject then
		return stateObject.id or stateObject.ID
	end

	return nil
end

local function getRoutePoints(route)
	local points = {}
	local ok, indexes = util.call(route, "getIndexes")

	if not ok or type(indexes) ~= "table" then
		return points
	end

	for index, point in ipairs(indexes) do
		local okPos, x, y = util.call(point, "getPos")

		if okPos and tonumber(x) and tonumber(y) then
			table.insert(points, {
				x = tonumber(x),
				y = tonumber(y),
				index = index,
				point = point,
				source = "routine"
			})
		end
	end

	return points
end

local function pointDistance(a, b)
	local dx, dy = a.x - b.x, a.y - b.y
	return math.sqrt(dx * dx + dy * dy)
end

local function addRoutineCandidate(candidates, point, source, home)
	local okPos, x, y = util.call(point, "getPos")
	x, y = tonumber(x), tonumber(y)
	if not okPos or not x or not y then return end

	local spacing = config.TARGET_ROUTINE_NODE_SPACING or 160
	for _, existing in ipairs(candidates) do
		local dx, dy = x - existing.x, y - existing.y
		if dx * dx + dy * dy < spacing * spacing then
			-- Preserve the principal's own authored node when it overlaps a generic
			-- map-sector candidate. It is the safest anchor for the expanded route.
			if home and not existing.home then
				existing.point = point
				existing.x, existing.y = x, y
				existing.source = source
				existing.home = true
			end
			return
		end
	end

	table.insert(candidates, {point = point, x = x, y = y, source = source, home = home == true})
end

local function collectRoutineCandidates(state, report, originalRoute)
	local candidates = {}
	local _, originalPoints = util.call(originalRoute, "getIndexes")
	if type(originalPoints) == "table" then
		for _, point in ipairs(originalPoints) do
			addRoutineCandidate(candidates, point, state.targetID or "principal", true)
		end
	end

	-- Every candidate below is an authored patrol node belonging to a Goon that
	-- already passed HCO's story/objective/state safety filter. We reuse those
	-- native points rather than inventing arbitrary coordinates or teleporting.
	for _, entry in ipairs(report and report.eligible or {}) do
		local okRoute, route = util.call(entry.npc, "getActivePatrolRoute")
		local okPoints, points = util.call(route, "getIndexes")
		if okRoute and okPoints and type(points) == "table" then
			for _, point in ipairs(points) do
				addRoutineCandidate(candidates, point, entry.data and entry.data.id or util.getID(entry.npc), entry.npc == state.target)
			end
		end
	end

	return candidates
end

local function selectRoutineCandidates(state, candidates, seed)
	local minimum = config.TARGET_ROUTINE_MIN_NODES or 5
	local maximum = math.max(minimum, config.TARGET_ROUTINE_MAX_NODES or 8)
	local maxLeg = config.TARGET_ROUTINE_MAX_LEG_DISTANCE or 1250
	if #candidates < minimum then return nil end

	local targetX, targetY = util.getPos(state.target)
	targetX, targetY = targetX or candidates[1].x, targetY or candidates[1].y
	local first
	for index, candidate in ipairs(candidates) do
		if candidate.home then
			local dx, dy = candidate.x - targetX, candidate.y - targetY
			local distance = math.sqrt(dx * dx + dy * dy)
			local jitter = util.stableHash(tostring(seed) .. ":routine-start:" .. tostring(index)) % 24
			local score = distance + jitter
			if not first or score < first.score then first = {candidate = candidate, score = score} end
		end
	end
	if not first then first = {candidate = candidates[1], score = 0} end

	local selected = {first.candidate}
	local used = {[first.candidate] = true}
	while #selected < maximum do
		local previous = selected[#selected]
		local best
		for index, candidate in ipairs(candidates) do
			if not used[candidate] then
				local leg = pointDistance(previous, candidate)
				if leg <= maxLeg then
					local separation = math.huge
					for _, chosen in ipairs(selected) do
						separation = math.min(separation, pointDistance(chosen, candidate))
					end
					local jitter = util.stableHash(table.concat({tostring(seed), "routine", tostring(#selected), tostring(index), tostring(candidate.source)}, ":")) % 90
					local score = separation * 1.35 + leg * 0.35 + jitter
					if not best or score > best.score then best = {candidate = candidate, score = score} end
				end
			end
		end

		if not best then break end
		used[best.candidate] = true
		table.insert(selected, best.candidate)
	end

	if #selected < minimum then return nil end
	return selected
end

local function createRoutineRoute(selected, seed)
	local points = {}
	local sourceMap = {}
	local coverage = 0
	for _, candidate in ipairs(selected) do
		table.insert(points, candidate.point)
		sourceMap[tostring(candidate.source)] = true
		for _, other in ipairs(selected) do coverage = math.max(coverage, pointDistance(candidate, other)) end
	end

	local maxLeg = config.TARGET_ROUTINE_MAX_LEG_DISTANCE or 1250
	local circular = #selected > 2 and pointDistance(selected[#selected], selected[1]) <= maxLeg
	local route
	if type(patrolRoute) == "table" and type(patrolRoute.new) == "function" then
		local ok, nativeRoute = pcall(patrolRoute.new)
		if ok and nativeRoute then
			route = nativeRoute
			route.indexes = points
			route.indexesMap = {}
			route.indexCoords = {}
			route.paths = {}
			route.pathMap = {}
			for _, point in ipairs(points) do
				local okIndex, index = util.call(point, "getIndex")
				local okPos, x, y = util.call(point, "getPos")
				if okIndex and index ~= nil then route.indexesMap[index] = point end
				if okIndex and okPos and index ~= nil then route.indexCoords[index] = {x, y} end
			end
			util.call(route, "setID", "hco-principal-" .. tostring(seed))
			util.call(route, "setCircular", circular)
		end
	end

	if not route then
		route = {id = "hco-principal-" .. tostring(seed), indexes = points, circular = circular, paths = {}, inUse = false}
		function route:getID() return self.id end
		function route:getIndexes() return self.indexes end
		function route:getCircular() return self.circular end
		function route:setCircular(value) self.circular = value == true end
		function route:setInUse(value) self.inUse = value == true end
		function route:getInUse() return self.inUse end
		function route:getPaths() return self.paths end
		function route:getPath() return nil end
	end

	local sourceCount = 0
	for _ in pairs(sourceMap) do sourceCount = sourceCount + 1 end
	return route, coverage, sourceCount, circular
end

local function buildRoutineRoute(state, report, originalRoute, seed)
	if not originalRoute then return nil, {}, false, 0, 0 end
	local originalPoints = getRoutePoints(originalRoute)
	local selected = selectRoutineCandidates(state, collectRoutineCandidates(state, report, originalRoute), seed)
	if not selected then return originalRoute, originalPoints, false, 1, 0 end

	local route, coverage, sources, circular = createRoutineRoute(selected, seed)
	local points = getRoutePoints(route)
	util.log(config, table.concat({
		"target routine expanded nodes=" .. tostring(#points),
		"sources=" .. tostring(sources),
		"coverage=" .. tostring(math.floor(coverage)),
		"circular=" .. tostring(circular)
	}, " "))
	return route, points, true, sources, coverage
end

local function getEvacuationPoints(state)
	local points = {}
	local worldObject = game and game.worldObject

	if worldObject and type(worldObject.getObjectsByClass) == "function" and objects and type(objects.getClassID) == "function" then
		local ok, extractionAreas = pcall(worldObject.getObjectsByClass, worldObject, objects.getClassID("extraction_area"))

		if ok and type(extractionAreas) == "table" then
			for index, area in ipairs(extractionAreas) do
				local okPos, x, y = util.call(area, "getCenter")

				if okPos and tonumber(x) and tonumber(y) then
					table.insert(points, {x = x, y = y, index = 1000 + index, source = "extraction"})
				end
			end
		end
	end

	local route = state.targetAI and state.targetAI.routePoints or {}

	if #route > 0 then
		for _, routeIndex in ipairs({1, #route, math.max(1, math.floor(#route * 0.5))}) do
			local point = route[routeIndex]

			if point then
				table.insert(points, {x = point.x, y = point.y, index = point.index, source = "routine-exit"})
			end
		end
	end

	return points
end

local function livingEscortCount(state)
	local count = 0

	for _, escortData in ipairs(state.escorts or {}) do
		if util.isAlive(escortData.actor) then
			count = count + 1
		end
	end

	if state.contract and state.contract.metrics then
		state.contract.metrics.livingEscortCount = count
	end

	return count
end

local function guardDensity(state, x, y)
	local count = 0

	for _, escortData in ipairs(state.escorts or {}) do
		if util.isAlive(escortData.actor) and util.distanceToPoint(escortData.actor, x, y) <= 280 then
			count = count + 1
		end
	end

	return count
end

local function evidencePenalty(state, x, y)
	local penalty = 0

	for _, evidence in ipairs(state.security and state.security.evidencePositions or {}) do
		local dx, dy = x - evidence.x, y - evidence.y

		if math.sqrt(dx * dx + dy * dy) <= 240 then
			penalty = penalty + 650
		end
	end

	return penalty
end

local function recentlyUsed(ai, point)
	for _, index in ipairs(ai.recentPoints or {}) do
		if index == point.index then
			return true
		end
	end

	return false
end

local function pickSecurePoint(state, avoidCurrent)
	local ai = state.targetAI
	local player = game and game.playerActor
	local target = state.target
	local ranked = {}

	for _, point in ipairs(ai.routePoints or {}) do
		if (not avoidCurrent or not ai.safePoint or point.index ~= ai.safePoint.index) and not recentlyUsed(ai, point) then
			local playerDistance = player and util.distanceToPoint(player, point.x, point.y) or 0
			local targetDistance = util.distanceToPoint(target, point.x, point.y)
			local density = guardDensity(state, point.x, point.y)
			local variation = util.stableHash(tostring(ai.seed) .. ":" .. tostring(ai.secureSwitches) .. ":" .. tostring(point.index)) % 200
			local score = playerDistance * 1.5 - targetDistance * 0.2 + density * 220 + variation - evidencePenalty(state, point.x, point.y)

			table.insert(ranked, {
				x = point.x,
				y = point.y,
				index = point.index,
				score = score,
				source = point.source
			})
		end
	end

	if #ranked == 0 and #ai.routePoints > 0 then
		ai.recentPoints = {}

		return pickSecurePoint(state, avoidCurrent)
	end

	table.sort(ranked, function(a, b)
		if a.score == b.score then
			return a.index < b.index
		end

		return a.score > b.score
	end)

	if #ranked == 0 then
		return nil
	end

	local topCount = math.min(3, #ranked)
	local selectedIndex = util.stableHash(tostring(ai.seed) .. ":secure:" .. tostring(ai.secureSwitches)) % topCount + 1

	return ranked[selectedIndex]
end

local function pickEvacuationPoint(state)
	local ai = state.targetAI
	local player = game and game.playerActor
	local target = state.target
	local ranked = {}

	for _, point in ipairs(ai.evacuationPoints or {}) do
		local playerDistance = player and util.distanceToPoint(player, point.x, point.y) or 0
		local targetDistance = util.distanceToPoint(target, point.x, point.y)
		local score = playerDistance * 1.7 - targetDistance * 0.15 + (point.source == "extraction" and 180 or 0)

		table.insert(ranked, {
			x = point.x,
			y = point.y,
			index = point.index,
			source = point.source,
			score = score
		})
	end

	table.sort(ranked, function(a, b)
		if a.score == b.score then
			return a.index < b.index
		end

		return a.score > b.score
	end)

	return ranked[1]
end

local function persistPhase(state)
	if not state.contract or not state.targetAI then
		return
	end

	state.contract.targetPhase = state.targetAI.phase
	state.contract.safePointIndex = state.targetAI.safePoint and state.targetAI.safePoint.index or nil
	state.contract.secureSwitches = state.targetAI.secureSwitches
	persistence.save(state.contract)
end

local function transition(state, phase)
	local ai = state.targetAI

	if ai.phase == phase then
		return
	end

	ai.phase = phase
	ai.phaseTime = 0
	persistPhase(state)
	objective.updateHUD(state)
	util.log(config, "target phase=" .. tostring(phase))
end

local function setNativeMovementState(target, phase)
	local stateID = phase == "UNEASY" and "goon_suspicion" or "goon_fear_run_to_cover"
	local okState, stateObject = util.call(target, "getStateObject", stateID)

	if okState and stateObject then
		util.call(target, "setState", stateObject)

		return true
	end

	return false
end

local function activateRoutinePatrol(state, routeIndex)
	local target = state.target
	local ai = state.targetAI
	local route = ai and (ai.routineRoute or ai.originalRoute)
	if not target or not ai or not route or #(ai.routePoints or {}) < 2 then return false end
	local index = math.max(1, math.min(#ai.routePoints, tonumber(routeIndex) or ai.originalRouteIndex or 1))
	local okIdle, idleState = util.call(target, "getStateObject", target.IDLE_STATE or "goon_idle")
	if okIdle and idleState then util.call(target, "setState", idleState, true) end
	util.call(target, "usePatrolSpeed")

	-- The native idle callback advances from the supplied index, writes the new
	-- route index and owns the path it creates. The old RC49 order wrote `index`
	-- back after this callback, desynchronizing the path from the route cursor. The
	-- principal consequently walked at most once and then kept requesting its
	-- current node. Prime the cursor before activation and never rewind it after.
	util.call(target, "setPatrolRouteIndex", index)
	local activated = util.call(target, "setActivePatrolRoute", route, index)
	local _, activeIndex = util.call(target, "getPatrolRouteIndex")
	activeIndex = tonumber(activeIndex) or index
	ai.routineVisited[activeIndex] = true
	ai.routineStuckTime = 0
	ai.routineLastIndex = activeIndex
	return activated == true
end

local function issueMove(state, point, phase, countSwitch)
	local target = state.target
	local ai = state.targetAI

	if not point or not target or not target.grid or type(target.grid.worldToGrid) ~= "function" then
		return false
	end

	local gridX, gridY = target.grid:worldToGrid(point.x, point.y)

	if gridX == nil or gridY == nil then
		return false
	end

	util.call(target, "setActivePatrolRoute", nil)
	util.call(target, "setDestPos", gridX, gridY)
	util.call(target, "setTargetPos", nil, nil)
	util.call(target, "setPath", nil)
	setNativeMovementState(target, phase)

	ai.safePoint = point
	ai.stuckTime = 0
	ai.lastDistance = util.distanceToPoint(target, point.x, point.y)

	if countSwitch then
		ai.secureSwitches = ai.secureSwitches + 1
		table.insert(ai.recentPoints, point.index)

		while #ai.recentPoints > 2 do
			table.remove(ai.recentPoints, 1)
		end
	end

	transition(state, phase)
	persistPhase(state)
	util.log(config, "target destination phase=" .. tostring(phase) .. " point=" .. tostring(point.index) .. " source=" .. tostring(point.source))

	return true
end

local function issueSecureMove(state, phase, avoidCurrent)
	return issueMove(state, pickSecurePoint(state, avoidCurrent), phase, true)
end

local function enterUneasy(state)
	local ai = state.targetAI

	ai.clearTime = 0
	ai.recoveries = 0
	issueSecureMove(state, "UNEASY", false)
end

local function enterThreat(state)
	local target = state.target
	local ai = state.targetAI
	local profile = profiles.resolve(state.contract and state.contract.seed or 0, state.contract and state.contract.archetype)

	if profile.dropsWeapon and not ai.weaponDropped then
		local okWeapon, weapon = util.call(target, "getWeapon")

		if okWeapon and weapon then
			util.call(target, "dropWeapon", false, true)
		end

		ai.weaponDropped = true
	end

	ai.clearTime = 0
	ai.recoveries = 0
	issueSecureMove(state, "THREATENED", false)
end

local function enterEvacuation(state)
	local ai = state.targetAI
	local point = pickEvacuationPoint(state)

	if not point or not issueMove(state, point, "EVACUATING", true) then
		transition(state, "CORNERED")

		return false
	end

	ai.evacuationWarningTime = 0
	feedback.show(english.TARGET_ESCAPING)
	objective.updateHUD(state)

	return true
end

local function failEscaped(state)
	local ai = state.targetAI

	transition(state, "ESCAPED")
	state.targetStatus = "escaped"
	state.contract.status = "failed_escaped"
	state.contract.resolution = "escaped"
	state.contract.rewardPaid = false
	persistence.save(state.contract)
	objective.failActive(state)
	feedback.show(english.TARGET_ESCAPED)
	ai.safePoint = nil
	util.log(config, "contract failed: target physically reached evacuation")
end

local function threatLevel(state)
	local target = state.target
	local stateID = getStateID(target)
	local securityLevel = state.security and tonumber(state.security.targetThreatLevel) or 0
	local aiPhase = state.targetAI and state.targetAI.phase or "ROUTINE"
	local player = game and game.playerActor
	local nativeThreatIsPlayerSpecific = util.observerKnowsPlayerIdentity(state, target, player)

	if (nativeThreatIsPlayerSpecific and (stateID == "goon_alert" or stateID == "goon_combat" or stateID == "goon_startled_combat" or stateID == "goon_run_from_grenade" or aiPhase == "ROUTINE" and THREAT_STATES[stateID])) or securityLevel >= 0.75 then
		return 2
	end

	if (nativeThreatIsPlayerSpecific and aiPhase == "ROUTINE" and UNEASY_STATES[stateID]) or securityLevel >= 0.25 then
		return 1
	end

	local okAlert, alertness = util.call(target, "getAlertnessStateID")
	local states = npcAlertnessStates and npcAlertnessStates.STATES

	if nativeThreatIsPlayerSpecific and okAlert and states then
		if alertness >= states.ALERT then
			return 2
		elseif alertness >= states.SUSPICION then
			return 1
		end
	end

	return 0
end

local function restoreRoutine(state)
	local target = state.target
	local ai = state.targetAI

	if not ai.originalRoute then
		transition(state, "CORNERED")

		return
	end

	activateRoutinePatrol(state, ai.originalRouteIndex or 1)
	transition(state, "ROUTINE")
	ai.safePoint = nil
	ai.stuckTime = 0
	ai.recoveries = 0
	ai.clearTime = 0
	persistPhase(state)
end

local function adjustCurrentDestination(state)
	local okDest, destObject = util.call(state.target, "getDestPosObj")

	if okDest and destObject and type(destObject.adjust) == "function" then
		local ok, adjusted = pcall(destObject.adjust, destObject)

		if ok and adjusted then
			util.call(state.target, "setPath", nil)

			return true
		end
	end

	return false
end

local function adjustWithOccupancy(state)
	local point = state.targetAI.safePoint
	local target = state.target
	local worldObject = game and game.worldObject

	if not point or not worldObject or type(worldObject.getActorTileOccupancy) ~= "function" then
		return false
	end

	local okOccupancy, occupancy = util.call(worldObject, "getActorTileOccupancy")
	local gridX, gridY = target.grid:worldToGrid(point.x, point.y)

	if not okOccupancy or not occupancy or type(occupancy.adjustDestinationCoords) ~= "function" then
		return false
	end

	local ok, finalX, finalY = pcall(occupancy.adjustDestinationCoords, occupancy, gridX, gridY)

	if ok and finalX ~= nil and finalY ~= nil then
		util.call(target, "setDestPos", finalX, finalY)
		util.call(target, "setPath", nil)

		return true
	end

	return false
end

local function enterCornered(state)
	local target = state.target
	local okFear, fearState = util.call(target, "getStateObject", target.FEAR_STATE or "goon_fear")

	if okFear and fearState then
		util.call(target, "setState", fearState, true)
	end

	state.targetAI.safePoint = nil
	state.targetAI.corneredRetryTime = 0
	transition(state, "CORNERED")
end

local function recoverPath(state)
	local ai = state.targetAI

	ai.recoveries = ai.recoveries + 1
	ai.stuckTime = 0

	if ai.recoveries <= 1 and adjustCurrentDestination(state) then
		util.log(config, "path watchdog adjusted native destination")
		return
	end

	if ai.recoveries <= 2 and ai.safePoint and issueMove(state, ai.safePoint, ai.phase, false) then
		ai.recoveries = math.max(ai.recoveries, 2)
		util.log(config, "path watchdog recomputed current route")
		return
	end

	if ai.recoveries <= 3 and issueSecureMove(state, ai.phase == "EVACUATING" and "EVACUATING" or "THREATENED", true) then
		ai.recoveries = math.max(ai.recoveries, 3)
		util.log(config, "path watchdog selected alternate node")
		return
	end

	if ai.recoveries <= 4 and adjustWithOccupancy(state) then
		ai.recoveries = 4
		util.log(config, "path watchdog selected nearest pathfinding tile")
		return
	end

	enterCornered(state)
	util.log(config, "path watchdog entered defensive hold")
end

local function updateStuckWatchdog(state, dt)
	local target = state.target
	local ai = state.targetAI

	if not ai.safePoint then
		return
	end

	ai.sampleTime = ai.sampleTime + dt

	if ai.sampleTime < config.STUCK_SAMPLE_INTERVAL then
		return
	end

	local x, y = util.getPos(target)
	local moved = x and ai.lastX and math.sqrt((x - ai.lastX) ^ 2 + (y - ai.lastY) ^ 2) or math.huge
	local distance = util.distanceToPoint(target, ai.safePoint.x, ai.safePoint.y)
	local progress = ai.lastDistance and ai.lastDistance - distance or math.huge

	ai.sampleTime = 0
	ai.lastX, ai.lastY = x, y
	ai.lastDistance = distance

	if moved <= config.STUCK_DISTANCE_EPSILON and progress <= config.STUCK_DISTANCE_EPSILON and distance > config.SECURE_ARRIVAL_DISTANCE then
		ai.stuckTime = ai.stuckTime + config.STUCK_SAMPLE_INTERVAL
	else
		ai.stuckTime = 0
	end

	if ai.stuckTime >= config.STUCK_TIMEOUT then
		recoverPath(state)
	end
end

local function reassertRoutinePatrol(state)
	local target = state.target
	local ai = state.targetAI
	if not (ai.routineRoute or ai.originalRoute) or #(ai.routePoints or {}) < 2 then return false end
	local _, currentIndex = util.call(target, "getPatrolRouteIndex")
	-- setActivePatrolRoute invokes idle:onPatrolRouteSet, which advances once. Feed
	-- it the current cursor rather than pre-advancing and skipping another node.
	local activated = activateRoutinePatrol(state, tonumber(currentIndex) or ai.originalRouteIndex or 1)
	ai.routineRecoveries = (ai.routineRecoveries or 0) + 1
	util.log(config, "target routine watchdog advanced patrol index=" .. tostring(ai.routineLastIndex))
	return activated
end

local function updateRoutineWatchdog(state, dt)
	local target = state.target
	local ai = state.targetAI
	ai.routineSampleTime = (ai.routineSampleTime or 0) + dt
	if ai.routineSampleTime < config.STUCK_SAMPLE_INTERVAL then return end
	local x, y = util.getPos(target)
	local moved = x and ai.routineLastX and math.sqrt((x - ai.routineLastX)^2 + (y - ai.routineLastY)^2) or math.huge
	ai.routineSampleTime = 0
	ai.routineLastX, ai.routineLastY = x, y
	if moved <= config.STUCK_DISTANCE_EPSILON then
		ai.routineStuckTime = (ai.routineStuckTime or 0) + config.STUCK_SAMPLE_INTERVAL
	else
		ai.routineStuckTime = 0
	end
	if ai.routineStuckTime >= (config.TARGET_ROUTINE_STUCK_TIMEOUT or 9) then reassertRoutinePatrol(state) end
end

local function consumeNearbyIncident(state)
	local ai = state.targetAI
	local incident = state.security and state.security.protectionIncident
	if not incident or (tonumber(incident.time) or 0) <= (ai.lastIncidentTime or -1) then return false end
	ai.lastIncidentTime = tonumber(incident.time) or 0
	local x, y = util.getPos(state.target)
	if not x then return false end
	local dx, dy = x - incident.x, y - incident.y
	return dx * dx + dy * dy <= (config.TARGET_INCIDENT_AWARENESS_RANGE or 1050)^2
end

local function shouldEvacuate(state)
	local ai = state.targetAI
	local profile = profiles.resolve(state.contract.seed, state.contract.archetype)
	local initial = math.max(1, state.contract.metrics.initialEscortCount or #state.escorts)
	local living = livingEscortCount(state)
	local lossRatio = 1 - living / initial

	return ai.threatTime >= (profile.evacuationDelay or config.EVACUATION_BASE_DELAY) or lossRatio >= (profile.escortLossThreshold or 0.66)
end

local function safeAreaBreached(state)
	local point = state.targetAI.safePoint

	if not point then
		return false
	end

	return evidencePenalty(state, point.x, point.y) > 0
end

function controller.attach(state, report)
	local target = state.target
	local okRoute, route = util.call(target, "getActivePatrolRoute")
	local okIndex, routeIndex = util.call(target, "getPatrolRouteIndex")
	local okState, originalState = util.call(target, "getState")
	local _, originalExperience = util.call(target, "getExperienceLevel")
	local _, originalAnimVar = util.call(target, "getAnimVariant")
	local _, originalHealth = util.call(target, "getHealth")
	local _, originalMaxHealth = util.call(target, "getMaxHealth")
	local x, y = util.getPos(target)
	local seed = state.contract and state.contract.seed or util.stableHash(state.targetID)
	local originalRoutePoints = okRoute and getRoutePoints(route) or {}
	local originalRouteIndex = tonumber(routeIndex) or 1
	if #originalRoutePoints > 0 then originalRouteIndex = math.max(1, math.min(#originalRoutePoints, originalRouteIndex)) end
	local routineRoute, routinePoints, routineExpanded, routineSources, routineCoverage = buildRoutineRoute(state, report, okRoute and route or nil, seed)

	state.targetAI = {
		phase = "ROUTINE",
		resumePhase = state.contract and state.contract.targetPhase or "ROUTINE",
		seed = seed,
		secureSwitches = state.contract and state.contract.secureSwitches or 0,
		originalRoute = okRoute and route or nil,
		originalRouteIndex = okIndex and originalRouteIndex or 1,
		routineRoute = routineRoute,
		routineExpanded = routineExpanded,
		routineSources = routineSources,
		routineCoverage = routineCoverage,
		originalState = okState and originalState or nil,
		originalExperience = originalExperience,
		originalAnimVar = originalAnimVar,
		originalHealth = originalHealth,
		originalMaxHealth = originalMaxHealth,
		routePoints = routinePoints,
		evacuationPoints = {},
		recentPoints = {},
		lastX = x,
		lastY = y,
		lastDistance = nil,
		sampleTime = 0,
		stuckTime = 0,
		recoveries = 0,
		phaseTime = 0,
		threatTime = 0,
		clearTime = 0,
		weaponDropped = false,
		safePoint = nil,
		routineVisited = {},
		routineSampleTime = 0,
		routineStuckTime = 0,
		routineRecoveries = 0,
		routineLastX = x,
		routineLastY = y,
		lastIncidentTime = -1,
		corneredRetryTime = 0,
		evacuationWarningTime = 0
	}
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE
	local profile = profiles.resolve(state.contract and state.contract.seed or 0, state.contract and state.contract.archetype)
	if profile.targetVariant then util.call(target, "setAnimVariant", profile.targetVariant) end
	target._hcoFactionVisual = profile.visualIndex
	if elite then util.call(target, "setExperienceLevel", elite) end
	util.call(target, "maxOutHealth")

	state.targetAI.evacuationPoints = getEvacuationPoints(state)

	if #state.targetAI.routePoints > 1 then
		local startIndex = state.targetAI.seed % #state.targetAI.routePoints + 1
		activateRoutinePatrol(state, startIndex)
	end
end

function controller.detach(state)
	local target = state.target
	local ai = state.targetAI

	if target and ai and util.isAlive(target) then
		util.call(target, "setPath", nil)

		if ai.originalState then
			util.call(target, "setState", ai.originalState)
		end

		if ai.originalRoute then
			util.call(target, "setActivePatrolRoute", ai.originalRoute, ai.originalRouteIndex or 1)
		end
		if ai.originalExperience then util.call(target, "setExperienceLevel", ai.originalExperience) end
		if ai.originalAnimVar then util.call(target, "setAnimVariant", ai.originalAnimVar) end
		if ai.originalMaxHealth then util.call(target, "setMaxHealth", ai.originalMaxHealth) end
		if ai.originalHealth then util.call(target, "setHealth", math.min(ai.originalHealth, ai.originalMaxHealth or ai.originalHealth)) end
	end
	if target then target._hcoFactionVisual = nil end

	state.targetAI = nil
end

function controller.update(state, dt)
	local target = state.target
	local ai = state.targetAI

	if not target or not ai or persistence.isTerminal(state.contract) then
		return
	end

	if not util.isValid(target) or not util.worldMatches(state, target) then
		state.targetStatus = "invalid"
		state.contract.status = "failed_invalid"
		state.contract.resolution = "target-removed-by-vanilla"
		persistence.save(state.contract)
		objective.failActive(state)
		util.log(config, "contract failed closed: target reference became invalid")

		return
	end

	if not util.isAlive(target) then
		return
	end

	ai.phaseTime = ai.phaseTime + dt

	if ai.resumePhase and ai.resumePhase ~= "ROUTINE" then
		local resume = ai.resumePhase
		ai.resumePhase = nil

		if resume == "EVACUATING" then
			enterEvacuation(state)
		else
			enterThreat(state)
		end
	else
		ai.resumePhase = nil
	end

	local level = threatLevel(state)
	local nearbyIncident = consumeNearbyIncident(state)
	if nearbyIncident and (ai.phase == "SHELTERED" or ai.phase == "CORNERED") then
		ai.recoveries = 0
		issueSecureMove(state, "THREATENED", true)
	elseif nearbyIncident and ai.phase == "THREATENED" and ai.safePoint then
		local incident = state.security and state.security.protectionIncident
		local dx, dy = ai.safePoint.x - incident.x, ai.safePoint.y - incident.y
		if dx * dx + dy * dy <= (config.TARGET_INCIDENT_RELOCATE_RANGE or 520)^2 then
			ai.recoveries = 0
			issueSecureMove(state, "THREATENED", true)
		end
	end

	-- Native combat perception can replace the flight state after the player
	-- fires. A protected principal must never join the assault: reassert the
	-- current safe destination and fear-run state when combat AI takes over.
	if ai.phase ~= "ROUTINE" and ai.safePoint and combatStates[getStateID(target)] then
		ai.flightReassertTime = math.max(0, (ai.flightReassertTime or 0) - dt)
		if ai.flightReassertTime == 0 then
			issueMove(state, ai.safePoint, ai.phase == "EVACUATING" and "EVACUATING" or "THREATENED", false)
			ai.flightReassertTime = 0.6
		end
	else
		ai.flightReassertTime = 0
	end

	if ai.phase == "ROUTINE" then
		local _, patrolIndex = util.call(target, "getPatrolRouteIndex")

		if patrolIndex then
			ai.routineVisited[patrolIndex] = true
		end

		if level >= 2 then
			enterThreat(state)
		elseif level == 1 then
			enterUneasy(state)
		else
			updateRoutineWatchdog(state, dt)
		end
	elseif ai.phase == "UNEASY" then
		if level >= 2 then
			enterThreat(state)
		elseif level == 0 then
			ai.clearTime = ai.clearTime + dt

			if ai.clearTime >= config.UNEASY_CLEAR_DELAY then
				restoreRoutine(state)
			end
		else
			ai.clearTime = 0
		end

		updateStuckWatchdog(state, dt)
	elseif ai.phase == "THREATENED" then
		ai.threatTime = ai.threatTime + dt

		if ai.safePoint and util.distanceToPoint(target, ai.safePoint.x, ai.safePoint.y) <= config.SECURE_ARRIVAL_DISTANCE then
			transition(state, "SHELTERED")
		elseif shouldEvacuate(state) then
			enterEvacuation(state)
		end

		updateStuckWatchdog(state, dt)
	elseif ai.phase == "SHELTERED" then
		ai.threatTime = ai.threatTime + dt

		if shouldEvacuate(state) then
			enterEvacuation(state)
		elseif safeAreaBreached(state) or game.playerActor and util.distance(target, game.playerActor) <= config.SECURE_RESELECT_DISTANCE then
			ai.recoveries = 0
			issueSecureMove(state, "THREATENED", true)
		elseif level == 0 then
			ai.clearTime = ai.clearTime + dt

			if ai.clearTime >= config.THREAT_CLEAR_DELAY then
				restoreRoutine(state)
			end
		else
			ai.clearTime = 0
		end
	elseif ai.phase == "EVACUATING" then
		ai.evacuationWarningTime = ai.evacuationWarningTime + dt

		if ai.safePoint and util.distanceToPoint(target, ai.safePoint.x, ai.safePoint.y) <= config.EVACUATION_ARRIVAL_DISTANCE then
			failEscaped(state)
		elseif ai.evacuationWarningTime >= config.EVACUATION_WARNING_INTERVAL then
			ai.evacuationWarningTime = 0
			feedback.show(english.TARGET_ESCAPING)
		end

		updateStuckWatchdog(state, dt)
	elseif ai.phase == "CORNERED" then
		if level == 0 then
			ai.clearTime = ai.clearTime + dt

			if ai.clearTime >= config.THREAT_CLEAR_DELAY then
				restoreRoutine(state)
			end
		else
			-- CORNERED is a recovery phase, never a permanent AFK state. Pressure
			-- keeps the evacuation clock running and periodically retries a different
			-- authored safe node while native fear AI continues looking for cover.
			ai.clearTime = 0
			ai.threatTime = ai.threatTime + dt
			ai.corneredRetryTime = math.max(0, (ai.corneredRetryTime or 0) - dt)
			if shouldEvacuate(state) then
				enterEvacuation(state)
			elseif ai.corneredRetryTime <= 0 then
				ai.recoveries = 0
				if not issueSecureMove(state, "THREATENED", true) then
					ai.corneredRetryTime = config.TARGET_CORNERED_RETRY_INTERVAL or 3
				end
			end
		end
	end
end

return controller
