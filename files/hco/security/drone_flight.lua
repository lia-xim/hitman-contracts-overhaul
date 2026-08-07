local config = require("hco/config")
local util = require("hco/util")

local flight = {}
local TAU = math.pi * 2
local MAP_MARGIN = 48
local MIN_SEPARATION = 84
local OUTDOOR_CLEARANCE = 22
local LOCAL_SEARCH_RADII = {64, 128, 192, 256, 336, 424}
local LOCAL_SEARCH_RAYS = 16
local deterministicAngle

local function centerOffset(drone)
	return drone and drone.hcoCenterOffset or 13
end

local function normalize(angle)
	return (angle + math.pi) % TAU - math.pi
end

function flight.angleDifference(a, b)
	return math.abs(normalize(a - b))
end

function flight.approachAngle(current, target, maximum)
	local delta = normalize(target - current)
	if math.abs(delta) <= maximum then return target end
	return normalize(current + (delta < 0 and -maximum or maximum))
end

function flight.worldBounds()
	local world = game and game.worldObject
	if world and type(world.getSize) == "function" then
		local ok, width, height = pcall(world.getSize, world)
		if ok and tonumber(width) and tonumber(height) and width > MAP_MARGIN * 2 and height > MAP_MARGIN * 2 then
			return MAP_MARGIN, MAP_MARGIN, width - MAP_MARGIN, height - MAP_MARGIN
		end
	end
	return -100000, -100000, 100000, 100000
end

function flight.clampToWorld(x, y)
	local minX, minY, maxX, maxY = flight.worldBounds()
	return util.clamp(x, minX, maxX), util.clamp(y, minY, maxY)
end

local function getFloorAccess()
	local worldObject = game and game.worldObject
	if not worldObject or type(worldObject.getFloorTileGrid) ~= "function" then return worldObject end
	local okGrid, grid = pcall(worldObject.getFloorTileGrid, worldObject)
	if not okGrid or not grid then return worldObject end
	return worldObject, grid
end

function flight.roofMapReady()
	if envController and type(envController.getRoofReady) == "function" then
		local ok, ready = pcall(envController.getRoofReady, envController)
		return ok and ready == true
	end
	return true
end

local function getRoofState(grid, index, x, y)
	local function normalizeRoof(value)
		return value == true or tonumber(value) == 1
	end
	if envController and type(envController.getPosUnderRoof) == "function" then
		local ok, roofed = pcall(envController.getPosUnderRoof, envController, x, y)
		if ok then return normalizeRoof(roofed), true end
	end
	if grid and grid.tiles then
		local ok, roofed = pcall(function()
			local tile = grid.tiles[index]
			return tile and tile.roofObstructed
		end)
		if ok and roofed ~= nil then return normalizeRoof(roofed), true end
	end
	return false, false
end

local function isPlayableSample(worldObject, grid, x, y, requireOutdoor)
	if not grid or type(grid.worldToIndex) ~= "function" or type(worldObject.getPFGridValue) ~= "function" then
		return true
	end
	local okIndex, index = pcall(grid.worldToIndex, grid, x, y)
	if not okIndex or index == nil then return false end
	local okValue, value = pcall(worldObject.getPFGridValue, worldObject, index)
	value = okValue and tonumber(value) or nil
	local states = world and world.PATHFIND_TILE_STATE
	local walkable = states and states.WALKABLE or 1
	local lowObstacle = states and states.OBSTRUCTED_LOW
	if value == nil or value > walkable and value ~= lowObstacle then return false end
	if requireOutdoor then
		local roofed, roofKnown = getRoofState(grid, index, x, y)
		if roofed then return false end
		-- Once the native roof map reports ready, a failed roof lookup must not
		-- silently turn an unknown cell into an armed-drone position.
		if envController and type(envController.getRoofReady) == "function" and not roofKnown then return false end
	end
	return true
end

function flight.isSafeCombatPoint(x, y, clearance)
	if not tonumber(x) or not tonumber(y) or not flight.roofMapReady() then return false end
	local worldObject, grid = getFloorAccess()
	if not worldObject then return true end
	if not grid then
		-- A live roof controller without its matching floor grid is incomplete
		-- geometry, not permission to attack. Harnesses without either API retain
		-- the compatibility fallback.
		return not (envController and type(envController.getRoofReady) == "function")
	end
	local radius = clearance == nil and OUTDOOR_CLEARANCE or math.max(0, clearance)
	for _, sample in ipairs({
		{0, 0}, {radius, 0}, {-radius, 0}, {0, radius}, {0, -radius},
		{radius * 0.7, radius * 0.7}, {-radius * 0.7, radius * 0.7},
		{radius * 0.7, -radius * 0.7}, {-radius * 0.7, -radius * 0.7}
	}) do
		if not isPlayableSample(worldObject, grid, x + sample[1], y + sample[2], true) then return false end
	end
	return true
end

local function resolvePlayableCandidate(x, y, referenceX, referenceY, scanRange)
	local worldObject, grid = getFloorAccess()
	x, y = flight.clampToWorld(x, y)
	if not worldObject or not grid or type(worldObject.getBestPFPoint) ~= "function" or type(grid.indexToWorld) ~= "function" then
		return flight.isSafeCombatPoint(x, y) and x or nil, y
	end
	local okIndex, index = pcall(worldObject.getBestPFPoint, worldObject, referenceX or x, referenceY or y, x, y, scanRange or 1)
	if not okIndex or not index then return nil, nil end
	local okPos, playableX, playableY = pcall(grid.indexToWorld, grid, index)
	if not okPos or not tonumber(playableX) or not tonumber(playableY) then return nil, nil end
	playableX, playableY = flight.clampToWorld(playableX, playableY)
	if not flight.isSafeCombatPoint(playableX, playableY) then return nil, nil end
	return playableX, playableY
end

function flight.snapToPlayable(x, y, referenceX, referenceY)
	if not flight.roofMapReady() then return nil, nil end
	x, y = flight.clampToWorld(x, y)
	local playableX, playableY = resolvePlayableCandidate(x, y, referenceX, referenceY, 1)
	if playableX then return playableX, playableY end
	-- Patrol routes also run through interiors. Search a deterministic outdoor
	-- ring around the requested point rather than accepting the nearest indoor
	-- path tile returned by the native pathfinder.
	for _, radius in ipairs(LOCAL_SEARCH_RADII) do
		for ray = 0, LOCAL_SEARCH_RAYS - 1 do
			local angle = ray / LOCAL_SEARCH_RAYS * TAU
			local candidateX = x + math.cos(angle) * radius
			local candidateY = y + math.sin(angle) * radius
			playableX, playableY = resolvePlayableCandidate(candidateX, candidateY, candidateX, candidateY, 1)
			if playableX then return playableX, playableY end
		end
	end
	return nil, nil
end

local function nearestOutdoorGridPoint(x, y)
	local worldObject, grid = getFloorAccess()
	if not worldObject or not grid or type(grid.getIndexCount) ~= "function" or type(grid.indexToWorld) ~= "function" or type(worldObject.getPFGridValue) ~= "function" then return nil, nil end
	local okCount, count = pcall(grid.getIndexCount, grid)
	count = okCount and tonumber(count) or nil
	if not count or count < 1 then return nil, nil end
	local states = world and world.PATHFIND_TILE_STATE
	local walkable = states and states.WALKABLE or 1
	local lowObstacle = states and states.OBSTRUCTED_LOW
	local bestX, bestY, bestDistance
	for index = 1, count do
		local okValue, value = pcall(worldObject.getPFGridValue, worldObject, index)
		value = okValue and tonumber(value) or nil
		if value and (value <= walkable or value == lowObstacle) then
			local okPos, candidateX, candidateY = pcall(grid.indexToWorld, grid, index)
			local roofed = okPos and getRoofState(grid, index, candidateX, candidateY) or true
			if okPos and roofed == false and tonumber(candidateX) and tonumber(candidateY) then
				local dx, dy = candidateX - x, candidateY - y
				local distance = dx * dx + dy * dy
				if (not bestDistance or distance < bestDistance) and flight.isSafeCombatPoint(candidateX, candidateY) then
					bestX, bestY, bestDistance = candidateX, candidateY, distance
				end
			end
		end
	end
	if bestX then return flight.clampToWorld(bestX, bestY) end
	return nil, nil
end

local function separateFromWing(context, x, y, index)
	local drones = context and context.security and context.security.drones or {}
	for pass = 1, 3 do
		local moved = false
		for _, other in ipairs(drones) do
			if other and not other.broken and other.hcoIndex ~= index then
				local offset = centerOffset(other)
				local otherX, otherY = (other.x or 0) + offset, (other.y or 0) + offset
				local dx, dy = x - otherX, y - otherY
				local distance = math.sqrt(dx * dx + dy * dy)
				if distance < MIN_SEPARATION then
					local angle = distance > 0.01 and math.atan2(dy, dx) or deterministicAngle(context, index or pass, "separation:" .. tostring(pass))
					local push = MIN_SEPARATION - distance + 18
					x, y = x + math.cos(angle) * push, y + math.sin(angle) * push
					moved = true
				end
			end
		end
		if not moved then break end
	end
	return flight.clampToWorld(x, y)
end

deterministicAngle = function(context, index, salt)
	local seed = context and context.contract and context.contract.seed or context and context.slot or 0
	local generation = context and context.security and context.security.droneGeneration or 0
	local hash = util.stableHash(tostring(seed) .. ":" .. tostring(index) .. ":" .. tostring(generation) .. ":" .. tostring(salt))
	return (hash % 100000) / 100000 * TAU
end

local function farEnough(x, y, anchorX, anchorY, minimum)
	local dx, dy = x - anchorX, y - anchorY
	return dx * dx + dy * dy >= minimum * minimum
end

local function seededRange(context, index, salt, minimum, maximum)
	local seed = context and context.contract and context.contract.seed or context and context.slot or 0
	local hash = util.stableHash(tostring(seed) .. ":" .. tostring(index or 1) .. ":" .. tostring(salt))
	return minimum + (hash % 10000) / 10000 * (maximum - minimum)
end

function flight.spawnPoint(context, index)
	local anchorX, anchorY = util.getPos(context and context.target)
	if not anchorX then return nil, nil end
	local points = context.security and context.security.sectorPoints or {}
	if #points > 0 then
		local start = util.stableHash(tostring(context.contract and context.contract.seed or context.slot or 0) .. ":spawn:" .. tostring(index)) % #points
		for offset = 1, #points do
			local point = points[(start + offset - 1) % #points + 1]
			if tonumber(point.x) and tonumber(point.y) and farEnough(point.x, point.y, anchorX, anchorY, 180) then
				local separatedX, separatedY = separateFromWing(context, point.x, point.y, index)
				local playableX, playableY = flight.snapToPlayable(separatedX, separatedY, anchorX, anchorY)
				if playableX then return playableX, playableY end
			end
		end
	end
	local angle = deterministicAngle(context, index, "entry")
	local distance = 260 + (util.stableHash(tostring(index) .. ":distance") % 180)
	local candidateX, candidateY = separateFromWing(context, anchorX + math.cos(angle) * distance, anchorY + math.sin(angle) * distance, index)
	local playableX, playableY = flight.snapToPlayable(candidateX, candidateY, anchorX, anchorY)
	if playableX then return playableX, playableY end
	-- The global scan is a last-resort deployment path for large roofed compounds.
	-- It is used only at spawn/recovery time, never in the per-frame movement path.
	local globalX, globalY = nearestOutdoorGridPoint(anchorX, anchorY)
	if not globalX then return nil, nil end
	local separatedX, separatedY = separateFromWing(context, globalX, globalY, index)
	local safeX, safeY = flight.snapToPlayable(separatedX, separatedY, globalX, globalY)
	return safeX or globalX, safeY or globalY
end

function flight.recoveryPoint(drone)
	local context = drone and drone.hcoContext
	if not context then return nil, nil end
	drone.hcoSafetyRecoveries = (drone.hcoSafetyRecoveries or 0) + 1
	local recoveryIndex = (drone.hcoIndex or 1) + drone.hcoSafetyRecoveries * 17
	return flight.spawnPoint(context, recoveryIndex)
end

function flight.beginTracking(drone, player)
	local px, py = util.getPos(player)
	if not px then return end
	local offset = centerOffset(drone)
	local cx, cy = (drone.x or 0) + offset, (drone.y or 0) + offset
	drone.hcoTrackSlotAngle = math.atan2(cy - py, cx - px)
	drone.hcoTracking = 2.2
end

function flight.updateTactics(drone, player, aggressive, tacticalContact)
	if not aggressive then
		drone.hcoNextFlankAt, drone.hcoNextSearchAt = nil, nil
		return nil
	end
	local now = curTime or 0
	if tacticalContact and player and util.isAlive(player) then
		drone.hcoNextSearchAt = nil
		if not drone.hcoNextFlankAt then
			drone.hcoNextFlankAt = now + seededRange(drone.hcoContext, drone.hcoIndex, "flank-delay", config.DRONE_FLANK_INTERVAL_MIN, config.DRONE_FLANK_INTERVAL_MAX)
		elseif now >= drone.hcoNextFlankAt then
			drone.hcoFlankStep = (drone.hcoFlankStep or 0) + 1
			local salt = "flank:" .. tostring(drone.hcoFlankStep)
			local arc = math.rad(seededRange(drone.hcoContext, drone.hcoIndex, salt, config.DRONE_FLANK_ARC_MIN, config.DRONE_FLANK_ARC_MAX))
			local direction = util.stableHash(salt .. ":" .. tostring(drone.hcoIndex or 1)) % 2 == 0 and -1 or 1
			drone.hcoTrackSlotAngle = normalize((drone.hcoTrackSlotAngle or 0) + arc * direction)
			drone.hcoDestX, drone.hcoDestY = nil, nil
			drone.hcoNextFlankAt = now + seededRange(drone.hcoContext, drone.hcoIndex, salt .. ":delay", config.DRONE_FLANK_INTERVAL_MIN, config.DRONE_FLANK_INTERVAL_MAX)
			return "FLANK"
		end
		return "CONTACT"
	end
	drone.hcoNextFlankAt = nil
	if (drone.hcoTracking or 0) <= 0 then
		if not drone.hcoNextSearchAt then drone.hcoNextSearchAt = now end
		if now >= drone.hcoNextSearchAt then
			drone.hcoSearchPhase = (drone.hcoSearchPhase or 0) + 1
			drone.hcoDestX, drone.hcoDestY = nil, nil
			local salt = "search-delay:" .. tostring(drone.hcoSearchPhase)
			drone.hcoNextSearchAt = now + seededRange(drone.hcoContext, drone.hcoIndex, salt, config.DRONE_SEARCH_RELOCATE_MIN, config.DRONE_SEARCH_RELOCATE_MAX)
			return "SEARCH"
		end
	end
	return nil
end

local function trackingDestination(drone, player)
	local px, py = util.getPos(player)
	if not px then return nil, nil end
	local definition = drone.hcoType or {}
	local baseAngle = drone.hcoTrackSlotAngle or deterministicAngle(drone.hcoContext, drone.hcoIndex or 1, "slot")
	-- A very small breathing motion keeps formations alive without orbiting past
	-- the player or dropping the sensor lock.
	local phase = (drone.hcoIndex or 1) * 1.7
	local sway = math.sin((curTime or 0) * 0.55 + phase) * 0.24
	local range = (definition.preferredRange or 320) + math.sin((curTime or 0) * 0.7 + phase * 0.6) * 24
	local desiredX, desiredY = px + math.cos(baseAngle + sway) * range, py + math.sin(baseAngle + sway) * range
	desiredX, desiredY = separateFromWing(drone.hcoContext, desiredX, desiredY, drone.hcoIndex)
	local playableX, playableY = flight.snapToPlayable(desiredX, desiredY, px, py)
	if playableX then return playableX, playableY end
	-- A lost floor destination is never replaced by inaccessible void space.
	local bestPoint, bestDistance
	for _, point in ipairs(drone.hcoContext and drone.hcoContext.security and drone.hcoContext.security.sectorPoints or {}) do
		if tonumber(point.x) and farEnough(point.x, point.y, px, py, 160) then
			local dx, dy = point.x - desiredX, point.y - desiredY
			local distance = dx * dx + dy * dy
			if not bestDistance or distance < bestDistance then bestPoint, bestDistance = point, distance end
		end
	end
	if bestPoint then return flight.snapToPlayable(bestPoint.x, bestPoint.y, desiredX, desiredY) end
	local offset = centerOffset(drone)
	return (drone.x or 0) + offset, (drone.y or 0) + offset
end

local function blocksFlightAt(x, y, clearance)
	return not flight.isSafeCombatPoint(x, y, clearance or 0)
end

local function blocksFlightSegment(startX, startY, finishX, finishY, clearance)
	local dx, dy = finishX - startX, finishY - startY
	local distance = math.sqrt(dx * dx + dy * dy)
	local steps = math.max(1, math.ceil(distance / 16))
	for step = 1, steps do
		local progress = step / steps
		if blocksFlightAt(startX + dx * progress, startY + dy * progress, clearance) then return true end
	end
	return false
end

local function steerAroundBuilding(drone, centerX, centerY, intendedAngle, step)
	local index = drone.hcoIndex or 1
	local recovery = drone.hcoWallRecovery or 0
	local preferLeft = util.stableHash(tostring(index) .. ":wall:" .. tostring(recovery)) % 2 == 0
	local side = preferLeft and 1 or -1
	for _, degrees in ipairs({48, -48, 82, -82, 118, -118, 160}) do
		local angle = intendedAngle + math.rad(degrees * side)
		local candidateX, candidateY = flight.clampToWorld(centerX + math.cos(angle) * step, centerY + math.sin(angle) * step)
		if not blocksFlightSegment(centerX, centerY, candidateX, candidateY, math.max(10, centerOffset(drone) * 0.8)) then
			drone.hcoWallRecovery = recovery + 1
			return candidateX, candidateY, angle, true
		end
	end
	return centerX, centerY, intendedAngle, true
end

local function sectorDestination(drone, anchorX, anchorY)
	local security = drone.hcoContext and drone.hcoContext.security
	local points = security and security.sectorPoints or {}
	drone.hcoSearchStep = (drone.hcoSearchStep or 0) + 1
	local centerX, centerY = (drone.x or 0) + centerOffset(drone), (drone.y or 0) + centerOffset(drone)
	local minimumTravel = config.DRONE_PATROL_MIN_TRAVEL or 96
	local function acceptCandidate(candidateX, candidateY, referenceX, referenceY)
		local playableX, playableY = flight.snapToPlayable(candidateX, candidateY, referenceX, referenceY)
		if playableX and farEnough(playableX, playableY, centerX, centerY, minimumTravel) then
			local separatedX, separatedY = separateFromWing(drone.hcoContext, playableX, playableY, drone.hcoIndex)
			local finalX, finalY = flight.snapToPlayable(separatedX, separatedY, referenceX, referenceY)
			if finalX and farEnough(finalX, finalY, centerX, centerY, minimumTravel * 0.7) then return finalX, finalY end
		end
		return nil, nil
	end
	if security and security.droneMode == "AGGRESSIVE" and security.lastKnown then
		local phase = drone.hcoSearchPhase or drone.hcoSearchStep
		for attempt = 1, 6 do
			local salt = "search-ring:" .. tostring(phase) .. ":" .. tostring(attempt)
			local angle = deterministicAngle(drone.hcoContext, (drone.hcoIndex or 1) + phase * 7 + attempt * 13, salt)
			local radius = seededRange(drone.hcoContext, drone.hcoIndex, salt .. ":radius", config.DRONE_SEARCH_RING_MIN, config.DRONE_SEARCH_RING_MAX)
			local ringX, ringY = acceptCandidate(anchorX + math.cos(angle) * radius, anchorY + math.sin(angle) * radius, anchorX, anchorY)
			if ringX then return ringX, ringY end
		end
	end
	if #points > 0 then
		local start = util.stableHash(tostring(drone.hcoIndex or 1) .. ":sector:" .. tostring(drone.hcoSearchStep)) % #points
		local direction = util.stableHash(tostring(drone.hcoIndex or 1) .. ":sector-direction") % 2 == 0 and 1 or -1
		for offset = 0, #points - 1 do
			local point = points[(start + offset * direction) % #points + 1]
			if tonumber(point.x) and tonumber(point.y) then
				local sectorX, sectorY = acceptCandidate(point.x, point.y, anchorX, anchorY)
				if sectorX then return sectorX, sectorY end
			end
		end
	end
	-- Authored NPC patrol points can all be indoors or collapse back onto the
	-- current airframe cell. Search a deterministic outdoor ring instead of
	-- returning nil/current position forever.
	for attempt = 1, 12 do
		local salt = "patrol-fallback:" .. tostring(drone.hcoSearchStep) .. ":" .. tostring(attempt)
		local angle = deterministicAngle(drone.hcoContext, (drone.hcoIndex or 1) + drone.hcoSearchStep * 11 + attempt * 19, salt)
		local radius = seededRange(drone.hcoContext, drone.hcoIndex, salt .. ":radius", 150, 430)
		local fallbackX, fallbackY = acceptCandidate(anchorX + math.cos(angle) * radius, anchorY + math.sin(angle) * radius, anchorX, anchorY)
		if fallbackX then return fallbackX, fallbackY end
	end
	return nil, nil
end

function flight.destination(drone, player, aggressive)
	if (drone.hcoTracking or 0) > 0 and player and util.isAlive(player) then
		return trackingDestination(drone, player)
	end
	local security = drone.hcoContext and drone.hcoContext.security
	if aggressive and security and security.lastKnown then
		return sectorDestination(drone, security.lastKnown.x, security.lastKnown.y)
	end
	local targetX, targetY = util.getPos(drone.hcoContext and drone.hcoContext.target)
	if targetX then return sectorDestination(drone, targetX, targetY) end
	local offset = centerOffset(drone)
	return flight.snapToPlayable((drone.x or 0) + offset, (drone.y or 0) + offset)
end

function flight.move(drone, dt, speed)
	local offset = centerOffset(drone)
	local centerX, centerY = (drone.x or 0) + offset, (drone.y or 0) + offset
	local dx, dy = (drone.hcoDestX or centerX) - centerX, (drone.hcoDestY or centerY) - centerY
	local distance = math.sqrt(dx * dx + dy * dy)
	local velocityAngle, movedDistance, avoidedBuilding
	if distance > 1 then
		local step = math.min(distance, speed * dt)
		local nextX, nextY = flight.clampToWorld(centerX + dx / distance * step, centerY + dy / distance * step)
		nextX, nextY = separateFromWing(drone.hcoContext, nextX, nextY, drone.hcoIndex)
		-- Separation is a steering influence, never a teleport. Earlier versions
		-- applied the full 84-unit correction after movement and could therefore
		-- appear to accelerate violently when two drones converged.
		local finalDX, finalDY = nextX - centerX, nextY - centerY
		local finalDistance = math.sqrt(finalDX * finalDX + finalDY * finalDY)
		if finalDistance > step and finalDistance > 0 then
			nextX, nextY = centerX + finalDX / finalDistance * step, centerY + finalDY / finalDistance * step
		end
		local intendedAngle = math.atan2(nextY - centerY, nextX - centerX)
		if blocksFlightSegment(centerX, centerY, nextX, nextY, math.max(10, offset * 0.8)) then
			nextX, nextY, intendedAngle, avoidedBuilding = steerAroundBuilding(drone, centerX, centerY, intendedAngle, step)
		else
			drone.hcoWallRecovery = 0
		end
		drone:setPos(nextX - offset, nextY - offset)
		movedDistance = math.sqrt((nextX - centerX)^2 + (nextY - centerY)^2)
		velocityAngle = movedDistance > 0.01 and intendedAngle or math.atan2(dy, dx)
	end
	return distance, velocityAngle, movedDistance or 0, avoidedBuilding == true
end

function flight.updateAim(drone, dt, player, hasVisual, velocityAngle)
	local definition = drone.hcoType or {}
	local body = drone.hcoBodyAngle or drone.curViewAngRad or 0
	local sensor = drone.hcoSensorAngle or body
	local desiredSensor
	if player and (hasVisual or (drone.hcoTracking or 0) > 0) then
		local px, py = util.getPos(player)
		local offset = centerOffset(drone)
		local cx, cy = (drone.x or 0) + offset, (drone.y or 0) + offset
		if px then desiredSensor = math.atan2(py - cy, px - cx) end
	end
	if not desiredSensor then
		local security = drone.hcoContext and drone.hcoContext.security
		local focus = security and security.droneMode == "AGGRESSIVE" and security.lastKnown
		local cx, cy = (drone.x or 0) + centerOffset(drone), (drone.y or 0) + centerOffset(drone)
		local focusAngle
		if focus and tonumber(focus.x) and tonumber(focus.y) then
			focusAngle = math.atan2(focus.y - cy, focus.x - cx)
		elseif drone.hcoDestX and drone.hcoDestY then
			focusAngle = math.atan2(drone.hcoDestY - cy, drone.hcoDestX - cx)
		else
			-- A geometrically boxed-in drone is still an active patrol sensor. Rotate
			-- the whole airframe through a continuous 360-degree search instead of
			-- leaving its gimbal trapped in one narrow arc.
			drone.hcoPatrolSweepAngle = normalize((drone.hcoPatrolSweepAngle or body) + (config.DRONE_PATROL_SWEEP_RATE or 0.52) * dt)
			focusAngle = drone.hcoPatrolSweepAngle
		end
		local sweep = math.sin((curTime or 0) * 0.9 + (drone.hcoIndex or 1) * 1.37) * math.rad((definition.gimbal or 40) * 0.5)
		desiredSensor = normalize((focusAngle or body) + sweep)
	end
	local gimbal = math.rad(definition.gimbal or 40)
	local sensorDelta = normalize(desiredSensor - body)
	if math.abs(sensorDelta) > gimbal then
		body = flight.approachAngle(body, desiredSensor, (definition.turnRate or 3) * dt)
	elseif velocityAngle and not hasVisual then
		body = flight.approachAngle(body, velocityAngle, (definition.turnRate or 3) * dt)
	end
	sensorDelta = util.clamp(normalize(desiredSensor - body), -gimbal, gimbal)
	local clampedTarget = normalize(body + sensorDelta)
	sensor = flight.approachAngle(sensor, clampedTarget, (definition.sensorTurnRate or 5) * dt)
	drone.hcoBodyAngle, drone.hcoSensorAngle = body, sensor
	if type(drone.setLightAngle) == "function" then pcall(drone.setLightAngle, drone, math.deg(sensor)) end
	return sensor
end

return flight
