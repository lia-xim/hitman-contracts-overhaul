local config = require("hco/config")
local audio = require("hco/audio")
local feedback = require("hco/feedback")
local airframes = require("hco/security/drone_airframe")
local droneTypes = require("hco/security/drone_types")
local flight = require("hco/security/drone_flight")
local droneWeapons = require("hco/security/drone_weapons")
local util = require("hco/util")

local drones = {}
local CLASS_ID = "hco_search_drone"
local registered = false
local droneClass

local function centerOffset(drone)
	return drone and drone.hcoCenterOffset or 13
end

local function bodyIsUsable(body)
	if not body then return false end
	if type(body.isDestroyed) == "function" then
		local ok, destroyed = pcall(body.isDestroyed, body)
		if not ok or destroyed then return false end
	end
	return type(body.setPosition) == "function"
end

local function fixtureIsUsable(fixture)
	if not fixture then return false end
	if type(fixture.isDestroyed) == "function" then
		local ok, destroyed = pcall(fixture.isDestroyed, fixture)
		if not ok or destroyed then return false end
	end
	return type(fixture.setFilterData) == "function"
end

local function syncPhysicalBody(drone)
	local body = drone and drone.body
	if not bodyIsUsable(body) then return false end
	-- Generic objects store x/y at their top-left corner, while a Box2D
	-- rectangle is centered on its body position. Keeping the body at x/y left
	-- half of the visible sprite without a hit target and put the aim point on
	-- the fixture edge. The fixture must follow the visible/aim center.
	local offset = centerOffset(drone)
	local ok = pcall(body.setPosition, body, (drone.x or 0) + offset, (drone.y or 0) + offset)
	if ok and type(body.setAwake) == "function" then pcall(body.setAwake, body, true) end
	return ok
end

local function ensurePhysicalHitbox(drone, hitbox)
	drone.hitboxW, drone.hitboxH = hitbox, hitbox
	-- Runtime cameras are created after the map's static obstacle setup. Rebuild
	-- the fixture explicitly so the moving carrier always owns a bullet target of
	-- the intended size instead of inheriting an absent/stale camera fixture.
	if type(drone.initHitbox) ~= "function" or not drone.physics then return false end
	local initialized = pcall(drone.initHitbox, drone, drone.physics, hitbox, hitbox)
	if not initialized or not bodyIsUsable(drone.body) or not fixtureIsUsable(drone.fixture) then return false end
	local fixture = drone.fixture
	pcall(fixture.setFilterData, fixture, drone.P_CATEGORY, drone.P_MASK, drone.P_GROUP)
	return syncPhysicalBody(drone)
end

local function maintainPhysicalHitbox(drone)
	local hitbox = drone and drone.hcoHitboxSize or math.max(drone and drone.hitboxW or 0, drone and drone.hitboxH or 0)
	if hitbox <= 0 then return false end
	if not bodyIsUsable(drone.body) or not fixtureIsUsable(drone.fixture) then
		drone.hcoHitboxRepairs = (drone.hcoHitboxRepairs or 0) + 1
		local repaired = ensurePhysicalHitbox(drone, hitbox)
		if repaired then util.log(config, "drone hitbox repaired model=" .. tostring(drone.hcoType and drone.hcoType.id) .. " count=" .. tostring(drone.hcoHitboxRepairs)) end
		drone.hcoHitboxReady = repaired
		return repaired
	end
	drone.hcoHitboxReady = syncPhysicalBody(drone)
	return drone.hcoHitboxReady
end

local function segmentHitsCircle(x1, y1, x2, y2, cx, cy, radius)
	local dx, dy = x2 - x1, y2 - y1
	local lengthSquared = dx * dx + dy * dy
	local t = 0
	if lengthSquared > 0.0001 then
		t = math.max(0, math.min(1, ((cx - x1) * dx + (cy - y1) * dy) / lengthSquared))
	end
	local hitX, hitY = x1 + dx * t, y1 + dy * t
	local offX, offY = hitX - cx, hitY - cy
	return offX * offX + offY * offY <= radius * radius, hitX, hitY
end

local function readBulletNumber(bullet, methodName, fieldName)
	if not bullet then return 0 end
	local method = bullet[methodName]
	if type(method) == "function" then
		local ok, value = pcall(method, bullet)
		if ok and tonumber(value) then return math.max(0, tonumber(value)) end
	end
	return math.max(0, tonumber(bullet[fieldName]) or 0)
end

local function getArmorDamage(bullet)
	local damage = readBulletNumber(bullet, "getDamage", "damage")
	local penetration = readBulletNumber(bullet, "getArmorPenetration", "armorPenetration")
	-- The Model 700, high-caliber rifles and similarly penetrating weapons must
	-- feel materially stronger than a pistol. Heavy describes the drone's weapon
	-- package, not a large health pool: ordinary rounds take 2–3 hits, while a
	-- powerful rifle compresses a three-hit airframe to two clean hits.
	if damage >= 55 or penetration >= 9 then return 2, damage, penetration end
	if damage >= 35 or penetration >= 6 then return 2, damage, penetration end
	return 1, damage, penetration
end

local function processPlayerBulletFallback(drone, dt)
	-- The native fixture is authoritative. This narrow fallback covers runtime
	-- builds/mod combinations that fail to expose a late-created generic-object
	-- fixture to the bullet raycast. A weapon advances a fresh projectile once
	-- before inserting it into activeBullets, so the first sweep must begin at the
	-- recorded muzzle position instead of reconstructing only the latest frame.
	-- A bullet present here has already survived native world collision handling,
	-- so walls remain authoritative.
	local bullets = game and game.activeBullets
	if type(bullets) ~= "table" then return false end
	local centerX, centerY = drone:getAimPos()
	local definition = drone.hcoType or {}
	local spriteRadius = 96 * (definition.renderScale or 0.34) * 0.72
	local radius = math.max(math.max(drone.hitboxW or 0, drone.hitboxH or 0) * 0.5, spriteRadius)
	if radius <= 0 then return false end

	local consumed = false
	for index = #bullets, 1, -1 do
		local bullet = bullets[index]
		if bullet and not bullet.stored then
			-- Native bullets are pooled. Never let a consumed-hit flag or sweep map
			-- survive when the same table is retrieved for a later shot.
			local shotNumber = bullet.shotNumber
			local shootX, shootY = tonumber(bullet.shootX), tonumber(bullet.shootY)
			if not bullet._hcoDroneSweepInitialized
				or bullet._hcoDroneSweepShotNumber ~= shotNumber
				or bullet._hcoDroneSweepShootX ~= shootX
				or bullet._hcoDroneSweepShootY ~= shootY then
				bullet._hcoDroneSweeps = nil
				bullet._hcoDroneHit = nil
				bullet._hcoDroneSweepInitialized = true
				bullet._hcoDroneSweepShotNumber = shotNumber
				bullet._hcoDroneSweepShootX, bullet._hcoDroneSweepShootY = shootX, shootY
			end
		end
		if bullet and not bullet.stored and not bullet._hcoDroneHit then
			local firer = bullet.firer
			if type(bullet.getFirer) == "function" then
				local ok, value = pcall(bullet.getFirer, bullet)
				if ok then firer = value end
			end
			if firer and (firer == game.playerActor or firer.PLAYER) and tonumber(bullet.x) and tonumber(bullet.y) then
				local sweeps = bullet._hcoDroneSweeps
				if type(sweeps) ~= "table" then sweeps = {} bullet._hcoDroneSweeps = sweeps end
				local previous = sweeps[drone]
				local startX, startY
				if previous then
					startX, startY = previous.x, previous.y
				else
					startX, startY = tonumber(bullet.shootX), tonumber(bullet.shootY)
					if (not startX or not startY) and type(bullet.getShootPos) == "function" then
						local ok, x, y = pcall(bullet.getShootPos, bullet)
						if ok then startX, startY = tonumber(x), tonumber(y) end
					end
					if not startX or not startY then
						local frameTravelX, frameTravelY = tonumber(bullet.travelX) or 0, tonumber(bullet.travelY) or 0
						startX, startY = bullet.x - frameTravelX * dt, bullet.y - frameTravelY * dt
					end
				end
				sweeps[drone] = {x = bullet.x, y = bullet.y}
				local hit, hitX, hitY = segmentHitsCircle(startX, startY, bullet.x, bullet.y, centerX, centerY, radius)
				if hit then
					bullet._hcoDroneHit = true
					drone:onHitBullet(bullet, {x = hitX, y = hitY, fraction = 1})
					if type(bullet.makeInactive) == "function" then pcall(bullet.makeInactive, bullet) end
					consumed = true
					if drone.broken then return true end
				end
			end
		end
	end

	return consumed
end

local function chooseDestination(self)
	local security = self.hcoContext and self.hcoContext.security
	local aggressive = security and security.droneMode == "AGGRESSIVE"
	return flight.destination(self, game and game.playerActor, aggressive)
end

local function hasLineOfSight(self, target, requireCone, maximumRange, requireRaycast)
	local px, py = util.getPos(target)
	if not px then return false end
	local offset = centerOffset(self)
	local sx, sy = (self.x or 0) + offset, (self.y or 0) + offset
	local dx, dy = px - sx, py - sy
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance > (maximumRange or self.radius or config.DRONE_SCAN_RADIUS) then return false end
	if requireCone then
		local heading = self.hcoSensorAngle or self.curViewAngRad or 0
		if flight.angleDifference(math.atan2(dy, dx), heading) > math.rad((self.lightFOV or config.DRONE_FOV) * 0.5) then return false end
	end

	-- Geometry is authoritative. Player tracking may fall back to the cone when
	-- a runtime omits the raycast API; body evidence deliberately requests the
	-- strict path and is never accepted without a completed geometry query.
	if type(self.runGenericRaycast) ~= "function" then return not requireRaycast end
	local ok, hitData = pcall(self.runGenericRaycast, self, sx, sy, px, py, target)
	if not ok or not hitData then return not requireRaycast end
	local fixture = hitData.fixture
	if not fixture then return true end
	local okFixture, targetFixture = util.call(target, "getFixture")
	return hitData.fraction == 1 or okFixture and fixture == targetFixture
end

local function hasPlayerLineOfSight(self, player, requireCone)
	-- Armed drones are never allowed to infer visibility. A completed native
	-- geometry trace is mandatory so a roof/wall can never protect the drone
	-- from player bullets while its weapon still damages the player.
	return hasLineOfSight(self, player, requireCone, nil, true)
end

local function canSeePlayer(self, player)
	return hasPlayerLineOfSight(self, player, true)
end

local function semanticDetectionFactor(self, aggressive)
	local root = self.hcoContext and (self.hcoContext.root or self.hcoContext)

	if not root or not root.disguise then
		return 1
	end

	local risk = util.clamp(tonumber(root.disguiseRisk) or 1, 0, 1)
	local minimum = config.DRONE_DISGUISE_MIN_DETECTION_FACTOR
	local factor = minimum + risk * (1 - minimum)

	if aggressive then
		factor = math.max(config.DRONE_AGGRESSIVE_MIN_DETECTION_FACTOR, factor)
	end

	return factor
end

local function scanBodyEvidence(self, dt)
	local context = self.hcoContext
	local security = context and context.security

	if not security or not game or not game.worldObject then return false end
	self.hcoEvidenceScanTime = (self.hcoEvidenceScanTime or ((self.hcoIndex or 1) * 0.09)) - dt
	if self.hcoEvidenceScanTime > 0 then return false end
	self.hcoEvidenceScanTime = config.DRONE_EVIDENCE_SCAN_INTERVAL
	security.droneSeenBodies = security.droneSeenBodies or {}
	security.seenBodies = security.seenBodies or {}

	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		local bodyID = util.getID(body)
		local _, dead = util.call(body, "isDead")
		local _, unconscious = util.call(body, "isUnconscious")
		if body ~= context.target and bodyID and not security.droneSeenBodies[bodyID] and (dead == true or unconscious == true)
			and hasLineOfSight(self, body, true, math.min(self.radius or config.DRONE_SCAN_RADIUS, config.DRONE_EVIDENCE_SCAN_RANGE), true) then
			security.droneSeenBodies[bodyID] = true
			security.seenBodies[bodyID] = true
			self.hcoEvidencePulse = 1.2
			if type(security.reportDroneBodyEvidence) == "function" then
				local ok, err = pcall(security.reportDroneBodyEvidence, self, body)
				if not ok then util.log(config, "drone body-evidence report failed: " .. tostring(err)) end
			else
				local x, y = util.getPos(body)
				security.bodyEvidence = x and {x=x, y=y, time=curTime or 0, observer=self} or security.bodyEvidence
			end
			local now = curTime or 0
			if not security.lastDroneEvidenceNotice or now - security.lastDroneEvidenceNotice >= 5 then
				security.lastDroneEvidenceNotice = now
				feedback.show("DRONE EVIDENCE SCAN — BODY DETECTED")
			end
			return true
		end
	end

	return false
end

local function notifyConfirmedSighting(self, player)
	local context = self.hcoContext
	if not context or not context.security then return end
	local x, y = util.getPos(player)
	if not x then return end
	local now = curTime or 0
	local root = context.root or context
	local contexts = type(root.contracts) == "table" and #root.contracts > 0 and root.contracts or {context}
	for _, networkContext in ipairs(contexts) do
		local security = networkContext.security
		if security then
			security.knowledge = security.knowledge or {}
			security.droneSighting = {x=x,y=y,time=now,drone=self}
			security.lastKnown = {x=x,y=y,confidence=1,source="search-drone-network",time=now,actor=self}
			security.targetThreatLevel = 1
			security.huntPhase = "PRESSURE"
			security.droneMode = "AGGRESSIVE"
			security.droneRaidAnnounced = true
			for _, networkDrone in ipairs(security.drones or {}) do
				if networkDrone and not networkDrone.broken then
					networkDrone.hcoDestX, networkDrone.hcoDestY = nil, nil
					networkDrone.hcoDestRefreshAt = 0
					networkDrone.hcoNextSearchAt = 0
					networkDrone.hcoNetworkAlertAt = now
				end
			end
			for _, guard in ipairs(security.guards or {}) do
				if guard.role ~= "close_protection" and util.isAlive(guard.actor) then
					local guardID = util.getID(guard.actor)
					if guardID then security.knowledge[guardID] = {x=x,y=y,confidence=1,source="search-drone-network",time=now,actor=guard.actor} end
					util.call(guard.actor, "setSightPos", x, y, true)
					util.call(guard.actor, "setSightTime", 0)
					util.call(guard.actor, "setEnemyInSight", true, player)
					local okState, guardState = util.call(guard.actor, "getState")
					if okState and guardState and type(guardState.goToCombat) == "function" then
						pcall(guardState.goToCombat, guardState, true)
					elseif okState and guardState and type(guardState.goToAlert) == "function" then
						pcall(guardState.goToAlert, guardState)
					end
				end
			end
			local targetID = networkContext.target and util.getID(networkContext.target)
			if targetID then security.knowledge[targetID] = {x=x,y=y,confidence=1,source="search-drone-network",time=now,actor=networkContext.target} end
		end
	end
	if not root.hcoDroneRaidAnnounced then
		root.hcoDroneRaidAnnounced = true
		if sound and type(sound.play) == "function" then pcall(sound.play, sound, "nvg_on") end
		feedback.show("DRONE CONTACT — RESPONSE TEAMS ARE MOVING ON YOUR POSITION")
	end
end

function drones.initialize()
	if registered then return true end
	if not objects or type(objects.create) ~= "function" or not objects.getClassData then return false end
	local nativeCameraClass = objects.getClassData("security_camera")
	if not nativeCameraClass then return false end
	if not airframes.initialize() then return false end
	local drone = {
		class = CLASS_ID,
		QUADLIST = {"Camera_1"},
		lightColor = color(70, 190, 255, 255) * 2,
		lightColorInactive = color(255, 80, 50, 255) * 2,
		radius = config.DRONE_SCAN_RADIUS,
		lightFOV = config.DRONE_FOV,
		castOff = 0,
		z = 360,
		depth = 72,
		breakNoise = 900
	}

	function drone:init()
		drone.baseClass.init(self)
		self:setSize(26, 26)
		self.hcoDetect = 0
		self.hcoFrameTime = 0
		self.hcoFrame = 1
		self.hcoSearchStep = 0
		self.hcoBodyAngle = self.curViewAngRad or 0
		self.hcoSensorAngle = self.curViewAngRad or 0
		self.hcoTracking = 0
		self.hcoWeaponCooldown = 0
		self.hcoWeaponState = "IDLE"
		self.hcoRotorSound = audio.startRotor(self)
		if not self.hcoRotorSound and sound and type(sound.playWorld) == "function" then
			local ok, container = pcall(sound.playWorld, sound, "light_malfunctioning", self, self.x, self.y, 0.24, 1.55)
			if ok then self.hcoRotorSound = container end
		end
	end

	function drone:getDrawColor()
		return 255, 255, 255, 0
	end

	-- Runtime cameras have no sprite-batch quadStruct because the map has
	-- already finalized its native sprite batches. Custom drone rendering owns
	-- the visuals, so the native sprite update must be bypassed entirely.
	function drone:getDrawPosition() return self.x, self.y end
	function drone:getAimPos()
		local offset = centerOffset(self)
		return (self.x or 0) + offset, (self.y or 0) + offset
	end
	function drone:setPos(x, y)
		drone.baseClass.setPos(self, x, y)
		local synced = syncPhysicalBody(self)
		if self.hcoHitboxSize then self.hcoHitboxReady = synced end
	end
	function drone:updateSprite() return end
	function drone:drawOutline()
		-- The native generic-object outline expects quadStruct dimensions. Runtime
		-- camera carriers have none, so delegate the aim pass to the real airframe.
		if self.hcoAirframe then pcall(airframes.drawOutline, self.hcoAirframe) end
	end
	function drone:rawDraw() return self:drawOutline() end

	function drone:postDraw()
		-- The sensor carrier stays invisible; hco_drone_airframe owns rendering.
	end

	function drone:update(dt)
		if self.broken then return false end
		local hitboxReady = maintainPhysicalHitbox(self)
		self.hcoHitFlash = math.max(0, (self.hcoHitFlash or 0) - dt)
		self.hcoImpactPulse = math.max(0, (self.hcoImpactPulse or 0) - dt)
		self.hcoArmorDisplay = math.max(0, (self.hcoArmorDisplay or 0) - dt)
		self.hcoEvidencePulse = math.max(0, (self.hcoEvidencePulse or 0) - dt)
		processPlayerBulletFallback(self, dt)
		if self.broken then return false end
		audio.updateRotor(self.hcoRotorSound, self)
		self.hcoFrameTime = self.hcoFrameTime + dt
		if self.hcoFrameTime >= 0.09 then self.hcoFrameTime = 0 self.hcoFrame = self.hcoFrame % 4 + 1 end
		local offset = centerOffset(self)
		local centerX, centerY = (self.x or 0) + offset, (self.y or 0) + offset
		local safePosition = flight.isSafeCombatPoint(centerX, centerY, math.max(10, offset * 0.8))
		if not safePosition and (self.hcoNextSafetyRecoveryAt or 0) <= (curTime or 0) then
			self.hcoNextSafetyRecoveryAt = (curTime or 0) + 0.5
			local recoveryX, recoveryY = flight.recoveryPoint(self)
			if recoveryX then
				self:setPos(recoveryX - offset, recoveryY - offset)
				self.hcoDestX, self.hcoDestY = nil, nil
				hitboxReady = maintainPhysicalHitbox(self)
				safePosition = flight.isSafeCombatPoint(recoveryX, recoveryY, math.max(10, offset * 0.8))
			end
		end
		local airframeReady = self.hcoAirframe ~= nil
		if airframeReady and type(self.hcoAirframe.isValid) == "function" then
			local ok, valid = pcall(self.hcoAirframe.isValid, self.hcoAirframe)
			airframeReady = ok and valid == true
		end
		if not hitboxReady or not safePosition or not airframeReady then
			-- Fairness invariant: an invisible, indoor or currently unhittable drone
			-- is inert. It may repair/relocate briefly, but can never acquire or fire.
			self.hcoUnsafeTime = (self.hcoUnsafeTime or 0) + dt
			self.hcoDetect, self.hcoTracking, self.hcoSightGrace = 0, 0, 0
			droneWeapons.update(self, game and game.playerActor, false, math.pi, dt, false)
			local result = drone.baseClass.update(self, dt)
			airframes.sync(self.hcoAirframe, self)
			if self.hcoUnsafeTime >= 0.75 and not self.broken then
				self.hcoSafetyRetired = true
				self:breakCam(nil, true)
			end
			return result
		end
		self.hcoUnsafeTime = 0
		if self.disrupted then
			self.hcoDetect = 0
			self.hcoTracking = 0
			droneWeapons.update(self, game and game.playerActor, false, math.pi, dt, false)
			local result = drone.baseClass.update(self, dt)
			airframes.sync(self.hcoAirframe, self)
			return result
		end
		-- Let the native camera maintain disruption/light-buffer state first.
		-- It also runs its own fixed sweep, so HCO writes the authoritative gimbal
		-- angle afterwards; otherwise the native update silently steals the cone
		-- back every frame and appears to fly past a detected player.
		local result = drone.baseClass.update(self, dt)
		scanBodyEvidence(self, dt)

		local security = self.hcoContext and self.hcoContext.security
		local aggressive = security and security.droneMode == "AGGRESSIVE"
		local modeSpeed = aggressive and config.DRONE_AGGRESSIVE_SPEED_MULTIPLIER or config.DRONE_PATROL_SPEED_MULTIPLIER
		local player = game and game.playerActor
		self.hcoTracking = math.max(0, (self.hcoTracking or 0) - dt)
		local visibleBeforeMove = player and util.isAlive(player) and canSeePlayer(self, player) or false
		local recentLastKnown = security and security.lastKnown and ((curTime or 0) - (security.lastKnown.time or 0)) <= 8
		local pursuitCue = aggressive and recentLastKnown and player and util.isAlive(player) and hasPlayerLineOfSight(self, player, false) or false
		local tacticalContact = visibleBeforeMove or pursuitCue
		if tacticalContact then
			if self.hcoTracking <= 0 then flight.beginTracking(self, player) else self.hcoTracking = 2.2 end
		end
		flight.updateTactics(self, player, aggressive, tacticalContact)
		offset = centerOffset(self)
		centerX, centerY = (self.x or 0) + offset, (self.y or 0) + offset
		local destDistance = math.sqrt(((self.hcoDestX or centerX) - centerX)^2 + ((self.hcoDestY or centerY) - centerY)^2)
		local now = curTime or 0
		local trackingRefresh = self.hcoTracking > 0 and now >= (self.hcoDestRefreshAt or 0)
		if not self.hcoDestX or destDistance < 36 or trackingRefresh then
			self.hcoDestX, self.hcoDestY = chooseDestination(self)
			-- Patrol/search destinations remain stable until reached. Re-rolling
			-- every second made distant goals cancel each other out and looked like
			-- a permanently hovering drone. Only live target tracking refreshes fast.
			self.hcoDestRefreshAt = now + (self.hcoTracking > 0 and 0.3 or 60)
		end
		local requestedSpeed = config.DRONE_SPEED * (self.hcoSpeed or 1) * modeSpeed
		local maximumSpeed = aggressive and config.DRONE_MAX_AGGRESSIVE_SPEED or config.DRONE_MAX_PATROL_SPEED
		local _, velocityAngle, movedDistance = flight.move(self, dt, math.min(requestedSpeed, maximumSpeed))
		if movedDistance < 0.05 then
			self.hcoIdleTime = (self.hcoIdleTime or 0) + dt
		else
			self.hcoIdleTime = math.max(0, (self.hcoIdleTime or 0) - dt * 2)
		end
		if self.hcoIdleTime >= config.DRONE_IDLE_RELOCATE_TIME then
			self.hcoIdleTime = 0
			self.hcoIdleRecoveries = (self.hcoIdleRecoveries or 0) + 1
			self.hcoDestX, self.hcoDestY = nil, nil
			if self.hcoTracking > 0 then
				local direction = self.hcoIdleRecoveries % 2 == 0 and -1 or 1
				self.hcoTrackSlotAngle = (self.hcoTrackSlotAngle or 0) + math.rad(42 * direction)
			else
				self.hcoSearchPhase = (self.hcoSearchPhase or 0) + 1
				self.hcoSearchStep = (self.hcoSearchStep or 0) + 2
				self.hcoNextSearchAt = 0
			end
		end
		flight.updateAim(self, dt, player, visibleBeforeMove or pursuitCue, velocityAngle)
		local visible = player and util.isAlive(player) and canSeePlayer(self, player) or false
		if visible then
			if self.hcoTracking <= 0 then flight.beginTracking(self, player) else self.hcoTracking = 2.2 end
		end
		if visible then self.hcoSightGrace = 0.4 else self.hcoSightGrace = math.max(0, (self.hcoSightGrace or 0) - dt) end
		local detectionVisible = visible or (self.hcoSightGrace or 0) > 0
		if detectionVisible then
			local detectTime = config.DRONE_DETECT_TIME * (self.hcoDetectScale or 1) * (aggressive and 1 or config.DRONE_PATROL_DETECT_MULTIPLIER)
			local semanticFactor = semanticDetectionFactor(self, aggressive)
			self.hcoIdentityFactor = semanticFactor
			self.hcoDetect = math.min(detectTime, self.hcoDetect + dt * semanticFactor)
			self.lightColorCurrent = self.lightColorInactive self:updateCastColor()
			if self.hcoDetect >= detectTime and ((curTime or 0) - (self.hcoLastConfirmedAt or -100)) >= 0.75 then
				self.hcoLastConfirmedAt = curTime or 0
				notifyConfirmedSighting(self, player)
			end
		else
			self.hcoDetect = math.max(0, self.hcoDetect - dt * 0.65)
			self.hcoIdentityFactor = 1
			-- Once any drone confirms the player, the complete network enters a
			-- visibly red search state. An individual armed drone still needs its own
			-- unobstructed view before weapon authority is granted.
			self.lightColorCurrent = aggressive and self.lightColorInactive or self.lightColor self:updateCastColor()
		end
		local px, py = util.getPos(player)
		local aimError = math.pi
		if px then
			local offset = centerOffset(self)
			aimError = flight.angleDifference(math.atan2(py - ((self.y or 0) + offset), px - ((self.x or 0) + offset)), self.hcoSensorAngle or 0)
		end
		local confirmed = aggressive and self.hcoTracking > 0 and ((curTime or 0) - (self.hcoLastConfirmedAt or -100)) < 3
		local attackOffset = centerOffset(self)
		local attackReady = self.hcoHitboxReady == true and flight.isSafeCombatPoint((self.x or 0) + attackOffset, (self.y or 0) + attackOffset, math.max(10, attackOffset * 0.8))
		droneWeapons.update(self, player, visible, aimError, dt, confirmed and attackReady)
		airframes.sync(self.hcoAirframe, self)
		return result
	end

	function drone:breakCam(breaker, quiet)
		if self.broken or self.hcoDestroying then return end
		self.hcoDestroying = true
		local offset = centerOffset(self)
		local crashX, crashY = (self.x or 0) + offset, (self.y or 0) + offset
		-- Set the terminal state before calling any native callback. A failed or
		-- partially overridden setBroken implementation must never leave a carrier
		-- able to finish a burst, detect the player or re-render its cone.
		self.broken = true
		self.hcoDetect, self.hcoTracking, self.hcoSightGrace = 0, 0, 0
		self.hcoIdentityFactor = 1
		droneWeapons.disable(self)
		-- Mirror the native camera destruction lifecycle but omit only the booth
		-- callback, because runtime drones deliberately have no camera booth.
		if type(self.setBroken) == "function" then pcall(self.setBroken, self, true) end
		self.broken = true
		if game and type(game.removeDynamicObject) == "function" then pcall(game.removeDynamicObject, self) end
		if type(self.disableAllInteraction) == "function" then pcall(self.disableAllInteraction, self) end
		if self.lightBuffer then
			local deadBuffer = self.lightBuffer
			if type(deadBuffer.setCasting) == "function" then pcall(deadBuffer.setCasting, deadBuffer, false) end
			if type(deadBuffer.setCanRender) == "function" then pcall(deadBuffer.setCanRender, deadBuffer, false) end
			if type(deadBuffer.setRenderForward) == "function" then pcall(deadBuffer.setRenderForward, deadBuffer, false) end
			if type(self.disableLight) == "function" then pcall(self.disableLight, self) end
			if type(deadBuffer.clearEffects) == "function" then pcall(deadBuffer.clearEffects, deadBuffer) end
			if shadowMapping then
				if type(shadowMapping.removeBuffer) == "function" then pcall(shadowMapping.removeBuffer, shadowMapping, deadBuffer) end
				if type(shadowMapping.stopRenderingBuffer) == "function" then pcall(shadowMapping.stopRenderingBuffer, shadowMapping, deadBuffer) end
				if type(shadowMapping.destroyAtlasBuffer) == "function" then pcall(shadowMapping.destroyAtlasBuffer, shadowMapping, deadBuffer) end
			end
			self.lightBuffer = nil
		end
		if type(self.setDisrupted) == "function" then pcall(self.setDisrupted, self, false) end
		self.disrupted = false
		if type(self.setDisruptTime) == "function" then pcall(self.setDisruptTime, self, nil) end
		local landingX, landingY = airframes.crash(self.hcoAirframe, self, crashX, crashY)
		if tonumber(landingX) and tonumber(landingY) then crashX, crashY = landingX, landingY end
		self.hcoAirframe = nil
		if self.hcoRotorSound then
			if type(self.hcoRotorSound.stop) == "function" then audio.stop(self.hcoRotorSound) elseif sound and sound.manager then pcall(sound.manager.stopSound, sound.manager, self.hcoRotorSound) end
			self.hcoRotorSound = nil
		end
		local security = self.hcoContext and self.hcoContext.security
		if security and not self.hcoSafetyRetired then
			security.dronesDestroyed = (security.dronesDestroyed or 0) + 1
			security.droneCrashEvidence = {x=crashX,y=crashY,time=curTime or 0,breaker=breaker}
			security.droneMode = "AGGRESSIVE"
			if security.huntPhase == "STAND_DOWN" or security.huntPhase == "DECAY" then security.huntPhase = "LOCAL_REACTION" end
			local dispatched = 0
			for _, guard in ipairs(security.guards or {}) do
				if guard.role ~= "close_protection" and util.isAlive(guard.actor) and dispatched < 3 then
					util.call(guard.actor, "setSightPos", crashX, crashY, false)
					local okState, guardState = util.call(guard.actor, "getState")
					if okState and guardState and type(guardState.goToAlert) == "function" then pcall(guardState.goToAlert, guardState) end
					dispatched = dispatched + 1
				end
			end
			local now = curTime or 0
			if not security.lastDroneDownNotice or now - security.lastDroneDownNotice >= 4 then
				security.lastDroneDownNotice = now
				feedback.show("DRONE DOWN — RESPONSE TEAM INVESTIGATING CRASH SITE")
			end
		end
		if not quiet then
			if noise and type(noise.emit) == "function" then pcall(noise.emit, noise, crashX, crashY, self.breakNoise or 700, self, noise.SOUND_TYPES and noise.SOUND_TYPES.OBJECTS) end
			if sound and type(sound.playWorld) == "function" then
				pcall(sound.playWorld, sound, "camera_break", self, crashX, crashY, self.hcoType and self.hcoType.heavy and 0.95 or 0.72, self.hcoType and self.hcoType.heavy and 0.82 or 1.08)
			elseif sound and type(sound.play) == "function" then
				pcall(sound.play, sound, "camera_break", self)
			end
		end
	end

	function drone:onHitBullet(bullet, hitData)
		if self.broken then return end
		local armorDamage, bulletDamage, penetration = getArmorDamage(bullet)
		local currentArmor = self.hcoArmor or 1
		local maximumArmor = self.hcoArmorMax or currentArmor
		-- A heavy drone must always register at least one surviving impact. This
		-- keeps the requested two-hit minimum even for high-caliber rifles while
		-- still allowing those weapons to turn a three-hit heavy into two hits.
		if maximumArmor > 1 and currentArmor == maximumArmor then armorDamage = math.min(armorDamage, currentArmor - 1) end
		self.hcoArmor = math.max(0, currentArmor - armorDamage)
		self.hcoHitFlash = 0.42
		self.hcoImpactPulse = 0.42
		self.hcoArmorDisplay = 0.95
		self.hcoLastArmorDamage = armorDamage
		self.hcoLastBulletDamage = bulletDamage
		self.hcoLastPenetration = penetration
		local offset = centerOffset(self)
		self.hcoImpactX = hitData and tonumber(hitData.x) or (self.x or 0) + offset
		self.hcoImpactY = hitData and tonumber(hitData.y) or (self.y or 0) + offset
		if sound and type(sound.playWorld) == "function" then
			pcall(sound.playWorld, sound, "impact_ricochet", self, self.hcoImpactX, self.hcoImpactY, 0.9, armorDamage >= 2 and 0.82 or 1.08)
		end
		local firer
		if bullet and type(bullet.getFirer) == "function" then local ok, value = pcall(bullet.getFirer, bullet) if ok then firer = value end end
		if self.hcoArmor <= 0 then self:breakCam(firer) end
	end

	function drone:remove()
		airframes.remove(self.hcoAirframe)
		self.hcoAirframe = nil
		droneWeapons.remove(self)
		if self.hcoRotorSound then
			if type(self.hcoRotorSound.stop) == "function" then audio.stop(self.hcoRotorSound) elseif sound and sound.manager then pcall(sound.manager.stopSound, sound.manager, self.hcoRotorSound) end
			self.hcoRotorSound = nil
		end
		return drone.baseClass.remove(self)
	end

	drone.baseClass = nativeCameraClass
	droneClass = drone
	registered = true
	return true
end

local function spawn(context, index)
	local target = context.target
	local x, y = util.getPos(target)
	if not x then return nil, "target-position-unavailable" end
	if not registered then drones.initialize() end
	if not droneClass and not drones.initialize() then return nil, "native-camera-class-unavailable" end
	if not flight.roofMapReady() then return nil, "native-roof-map-not-ready" end
	local spawnX, spawnY = flight.spawnPoint(context, index)
	if not spawnX then return nil, "outdoor-spawn-point-unavailable" end
	local ok, instance = pcall(objects.create, "security_camera")
	local usedFallback = true
	if not ok or not instance then return nil, "native-camera-create-failed: " .. tostring(instance) end
	if droneClass then
		-- Keep the engine-owned physical camera object and replace only the
		-- behavior of this instance. This avoids relying on late class registration,
		-- which silently failed in the live Workshop/local-mod runtime.
		instance.getDrawColor = droneClass.getDrawColor
		instance.getDrawPosition = droneClass.getDrawPosition
		instance.getAimPos = droneClass.getAimPos
		instance.setPos = droneClass.setPos
		instance.updateSprite = droneClass.updateSprite
		instance.drawOutline = droneClass.drawOutline
		instance.rawDraw = droneClass.rawDraw
		instance.postDraw = droneClass.postDraw
		instance.update = droneClass.update
		instance.breakCam = droneClass.breakCam
		instance.onHitBullet = droneClass.onHitBullet
		instance.remove = droneClass.remove
		instance.hcoDetect = 0
		instance.hcoFrameTime = 0
		instance.hcoFrame = 1
		instance.hcoSearchStep = 0
		instance.hcoTracking = 0
		instance.hcoWeaponCooldown = 0
		instance.hcoWeaponState = "IDLE"
		instance.hcoRotorSound = nil
		util.log(config, "native security-camera drone instance prepared")
	end
	instance.hcoContext = context
	instance.hcoIndex = index
	local aggressive = context.security and context.security.droneMode == "AGGRESSIVE"
	local definition = droneTypes.select(context, index, aggressive)
	instance.hcoType = definition
	local accent = definition.accent or {70, 190, 255}
	if type(color) == "function" then
		instance.lightColor = color(accent[1], accent[2], accent[3], 255) * 2
		instance.lightColorInactive = color(255, 70, 50, 255) * 2
	end
	-- Atlas cells rotate independently from the axis-aligned carrier. These sizes
	-- cover the visible diagonal (including rotors), not merely the unrotated
	-- central fuselage. Drones are intentionally easy, fair targets.
	local hitbox = definition.heavy and 54 or definition.id == "scout" and 44 or 48
	instance.hcoHitboxSize = hitbox
	instance.hcoCenterOffset = hitbox * 0.5
	instance.hcoRotorSound = audio.startRotor(instance)
	local doctrine = context.security and context.security.droneDoctrine or {}
	instance.hcoSpeed = (definition.speed or 1) * (doctrine.speed or 1)
	local tuning = context.security and context.security.balance or context.balance or {}
	instance.hcoDetectScale = (definition.detect or 1) * (doctrine.detect or 1) * (tuning.detectionTimeScale or 1)
	local baseArmor = definition.armor or 1
	local armorCap = definition.heavy and 3 or 1
	instance.hcoArmor = math.min(armorCap, math.max(baseArmor, math.floor(baseArmor * (doctrine.armor or 1) + 0.5)))
	instance.hcoArmorMax = instance.hcoArmor
	instance.hcoFallback = usedFallback
	instance.radius = config.DRONE_SCAN_RADIUS * (definition.scanRadius or 1) * (doctrine.radius or 1) * (tuning.sensorRangeScale or 1)
	instance.lightFOV = definition.fov or config.DRONE_FOV
	instance.hitboxW, instance.hitboxH = hitbox, hitbox
	if type(instance.setSize) == "function" then pcall(instance.setSize, instance, hitbox, hitbox) end
	local initialAngle = math.atan2(y - spawnY, x - spawnX)
	instance.hcoBodyAngle, instance.hcoSensorAngle = initialAngle, initialAngle
	instance:setPos(spawnX - instance.hcoCenterOffset, spawnY - instance.hcoCenterOffset)
	instance:setViewAngle(math.deg(initialAngle))
	instance:setLightAngle(math.deg(initialAngle))
	local placed, placeError = pcall(function()
		instance:onPlacedIntoMap()
		instance.hcoHitboxReady = ensurePhysicalHitbox(instance, hitbox)
		if not instance.hcoHitboxReady then error("physical-hitbox-unavailable") end
		if type(instance.makeAimable) == "function" then instance:makeAimable() end
		game.addDynamicObject(instance)
	end)
	if not placed then
		pcall(game.removeDynamicObject, instance)
		pcall(instance.remove, instance)
		return nil, "placement-failed: " .. tostring(placeError)
	end
	local shell, shellError = airframes.create(instance, instance.x + instance.hcoCenterOffset, instance.y + instance.hcoCenterOffset)
	if not shell then
		pcall(game.removeDynamicObject, instance)
		pcall(instance.remove, instance)
		return nil, shellError
	end
	instance.hcoAirframe = shell
	airframes.sync(shell, instance)
	instance._hcoDrone = true
	util.log(config, "drone spawned slot=" .. tostring(context.slot or 1) .. " model=" .. definition.id .. " armor=" .. tostring(instance.hcoArmor))
	return instance
end

function drones.drawAll()
	-- Compatibility shim for older HCO hooks. Native airframes are now drawn by
	-- world:drawActors() through the game's decor quadtree and sprite batches.
	return airframes.diagnostics().airframes > 0
end

local function updateRenderDiagnostic(security, dt)
	if not config.DIAGNOSTICS_ENABLED then security.droneRenderDiagnostic = nil return end
	local diagnostic = security and security.droneRenderDiagnostic
	if not diagnostic then return end
	diagnostic.remaining = diagnostic.remaining - dt
	if diagnostic.remaining > 0 then return end
	security.droneRenderDiagnostic = nil
	local stats = airframes.diagnostics()
	local rendered = stats.drawPasses > diagnostic.startPasses
	feedback.show("HCO RC33 DRONE ROSTER — quadtree " .. (rendered and "ACTIVE" or "NOT DRAWN") .. ", batches " .. (stats.batchReady and stats.wreckBatchReady and "READY" or "MISSING") .. ", live/wreck sprites " .. (stats.spriteReady and stats.wreckSpriteReady and "READY" or "MISSING") .. ", bodies " .. tostring(stats.airframes))
end

function drones.request(context, count, reason, quiet)
	local security = context and context.security
	if not security then return end
	security.droneDeploymentRequested = math.max(security.droneDeploymentRequested or 0, count or (security.droneDoctrine and security.droneDoctrine.count) or config.DRONE_DEPLOY_COUNT)
	security.droneDeploymentReason = reason
	security.droneDeploymentQuiet = quiet == true
	if not quiet then security.droneCooldown = 0 end
	if not quiet and not security.droneRequestNoticeShown then
		security.droneRequestNoticeShown = true
		feedback.show("DRONE SUPPORT INBOUND — " .. tostring(reason or "security escalation"))
	end
	util.log(config, "drone deployment queued slot=" .. tostring(context.slot or 1) .. " count=" .. tostring(security.droneDeploymentRequested) .. " reason=" .. tostring(reason))
end

function drones.update(context, dt)
	-- Wreck animation ownership outlives the destroyed sensor carrier. Tick it
	-- before deployment early-returns so a quiet contract still reaches frame 4.
	airframes.update(context, dt)
	local security = context.security
	if not security then return end
	updateRenderDiagnostic(security, dt)
	security.droneCooldown = math.max(0, (security.droneCooldown or 0) - dt)
	local wanted = security.droneDeploymentRequested or 0
	if wanted <= 0 or security.droneCooldown > 0 then return end
	-- Keep the request queued until Intravenous 2 has finalized roof obstruction
	-- data. Consuming it earlier was the source of indoor/locked-room spawns.
	if not flight.roofMapReady() then return end
	security.drones = security.drones or {}
	local live = {}
	for _, drone in ipairs(security.drones) do if drone and not drone.broken then table.insert(live, drone) end end
	security.drones = live
	local globalActive = airframes.diagnostics().airframes
	local room = math.max(0, math.min(config.DRONE_MAX_COUNT - #live, config.DRONE_GLOBAL_MAX_COUNT - globalActive))
	local launched = 0
	local lastError
	security.droneGeneration = (security.droneGeneration or 0) + 1
	security.droneWaveFirstIndex = #live + 1
	for index = 1, math.min(wanted, room) do local drone, spawnError = spawn(context, #live + index) if drone then table.insert(security.drones, drone) launched = launched + 1 else lastError = spawnError end end
	security.droneDeploymentRequested = 0
	security.droneCooldown = config.DRONE_REDEPLOY_COOLDOWN
	security.droneRequestNoticeShown = false
	if launched > 0 then
		security.droneRenderDiagnostic = {remaining = 1.5, startPasses = airframes.diagnostics().drawPasses}
		if sound and type(sound.play) == "function" then pcall(sound.play, sound, "radio_disrupt_end") end
		if security.droneMode == "PATROL" or security.droneDeploymentQuiet then
			feedback.show(string.upper((security.droneDoctrine and security.droneDoctrine.name) or "WATCH DRONE") .. " PATROL ACTIVE")
		else
			feedback.show(string.upper((security.droneDoctrine and security.droneDoctrine.name) or "SECURITY DRONES") .. " DEPLOYED — Aggressive search active")
		end
		util.log(config, "drone deployment launched slot=" .. tostring(context.slot or 1) .. " count=" .. tostring(launched))
	elseif lastError then
		util.log(config, "drone deployment failed slot=" .. tostring(context.slot or 1) .. " error=" .. tostring(lastError))
		if not security.droneFailureShown then
			security.droneFailureShown = true
			feedback.show("HCO DRONE SUPPORT OFFLINE — " .. tostring(lastError):sub(1, 150))
		end
	end
	security.droneDeploymentQuiet = false
end

function drones.detach(context)
	for _, drone in ipairs(context.security and context.security.drones or {}) do
		if drone then drone._hcoDrone = nil pcall(game.removeDynamicObject, drone) pcall(drone.remove, drone) end
	end
	airframes.clearContext(context)
end

return drones
