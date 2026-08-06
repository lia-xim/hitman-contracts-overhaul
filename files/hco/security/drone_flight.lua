local util = require("hco/util")

local flight = {}
local TAU = math.pi * 2
local MAP_MARGIN = 48
local MIN_SEPARATION = 84
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

function flight.snapToPlayable(x, y, referenceX, referenceY)
	x, y = flight.clampToWorld(x, y)
	local world = game and game.worldObject
	if not world or type(world.getBestPFPoint) ~= "function" or type(world.getFloorTileGrid) ~= "function" then return x, y end
	local okIndex, index = pcall(world.getBestPFPoint, world, referenceX or x, referenceY or y, x, y, 4)
	if not okIndex or not index then return nil, nil end
	local okGrid, grid = pcall(world.getFloorTileGrid, world)
	if not okGrid or not grid or type(grid.indexToWorld) ~= "function" then return x, y end
	local okPos, playableX, playableY = pcall(grid.indexToWorld, grid, index)
	if not okPos or not tonumber(playableX) or not tonumber(playableY) then return nil, nil end
	return flight.clampToWorld(playableX, playableY)
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
	return flight.snapToPlayable(candidateX, candidateY, anchorX, anchorY)
end

function flight.beginTracking(drone, player)
	local px, py = util.getPos(player)
	if not px then return end
	local offset = centerOffset(drone)
	local cx, cy = (drone.x or 0) + offset, (drone.y or 0) + offset
	drone.hcoTrackSlotAngle = math.atan2(cy - py, cx - px)
	drone.hcoTracking = 2.2
end

local function trackingDestination(drone, player)
	local px, py = util.getPos(player)
	if not px then return nil, nil end
	local definition = drone.hcoType or {}
	local baseAngle = drone.hcoTrackSlotAngle or deterministicAngle(drone.hcoContext, drone.hcoIndex or 1, "slot")
	-- A very small breathing motion keeps formations alive without orbiting past
	-- the player or dropping the sensor lock.
	local sway = math.sin((curTime or 0) * 0.42 + (drone.hcoIndex or 1) * 1.7) * 0.12
	local range = definition.preferredRange or 320
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
	if bestPoint then return bestPoint.x, bestPoint.y end
	local offset = centerOffset(drone)
	return (drone.x or 0) + offset, (drone.y or 0) + offset
end

local function sectorDestination(drone, anchorX, anchorY)
	local security = drone.hcoContext and drone.hcoContext.security
	local points = security and security.sectorPoints or {}
	drone.hcoSearchStep = (drone.hcoSearchStep or 0) + 1
	if #points > 0 then
		local stride = 1 + (util.stableHash(tostring(drone.hcoIndex or 1) .. ":stride") % math.max(1, #points - 1))
		local point = points[((drone.hcoSearchStep * stride + (drone.hcoIndex or 1) * 3) - 2) % #points + 1]
		return flight.snapToPlayable(point.x, point.y, anchorX, anchorY)
	end
	local angle = deterministicAngle(drone.hcoContext, (drone.hcoIndex or 1) + drone.hcoSearchStep, "search")
	local radius = 170 + ((drone.hcoIndex or 1) % 4) * 45
	return flight.snapToPlayable(anchorX + math.cos(angle) * radius, anchorY + math.sin(angle) * radius, anchorX, anchorY)
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
	local velocityAngle
	if distance > 1 then
		local step = math.min(distance, speed * dt)
		local nextX, nextY = flight.clampToWorld(centerX + dx / distance * step, centerY + dy / distance * step)
		nextX, nextY = separateFromWing(drone.hcoContext, nextX, nextY, drone.hcoIndex)
		drone:setPos(nextX - offset, nextY - offset)
		velocityAngle = math.atan2(dy, dx)
	end
	return distance, velocityAngle
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
