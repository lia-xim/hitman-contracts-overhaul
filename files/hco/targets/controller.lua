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

	local okIdle, idleState = util.call(target, "getStateObject", target.IDLE_STATE or "goon_idle")

	if okIdle and idleState then
		util.call(target, "setState", idleState)
	end

	util.call(target, "setActivePatrolRoute", ai.originalRoute, ai.originalRouteIndex or 1)
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
		util.call(target, "setState", fearState)
	end

	state.targetAI.safePoint = nil
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

function controller.attach(state)
	local target = state.target
	local okRoute, route = util.call(target, "getActivePatrolRoute")
	local okIndex, routeIndex = util.call(target, "getPatrolRouteIndex")
	local okState, originalState = util.call(target, "getState")
	local _, originalExperience = util.call(target, "getExperienceLevel")
	local _, originalAnimVar = util.call(target, "getAnimVariant")
	local _, originalHealth = util.call(target, "getHealth")
	local _, originalMaxHealth = util.call(target, "getMaxHealth")
	local x, y = util.getPos(target)

	state.targetAI = {
		phase = "ROUTINE",
		resumePhase = state.contract and state.contract.targetPhase or "ROUTINE",
		seed = state.contract and state.contract.seed or util.stableHash(state.targetID),
		secureSwitches = state.contract and state.contract.secureSwitches or 0,
		originalRoute = okRoute and route or nil,
		originalRouteIndex = okIndex and routeIndex or 1,
		originalState = okState and originalState or nil,
		originalExperience = originalExperience,
		originalAnimVar = originalAnimVar,
		originalHealth = originalHealth,
		originalMaxHealth = originalMaxHealth,
		routePoints = okRoute and getRoutePoints(route) or {},
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
		util.call(target, "setPatrolRouteIndex", startIndex)
		state.targetAI.routineVisited[startIndex] = true
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
	elseif ai.phase == "CORNERED" and level == 0 then
		ai.clearTime = ai.clearTime + dt

		if ai.clearTime >= config.THREAT_CLEAR_DELAY then
			restoreRoutine(state)
		end
	end
end

return controller
