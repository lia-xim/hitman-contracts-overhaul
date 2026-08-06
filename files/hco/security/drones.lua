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

local function syncPhysicalBody(drone)
	local body = drone and drone.body
	if not bodyIsUsable(body) then return false end
	local ok = pcall(body.setPosition, body, drone.x or 0, drone.y or 0)
	if ok and type(body.setAwake) == "function" then pcall(body.setAwake, body, true) end
	return ok
end

local function ensurePhysicalHitbox(drone, hitbox)
	drone.hitboxW, drone.hitboxH = hitbox, hitbox
	-- Runtime cameras are created after the map's static obstacle setup. Rebuild
	-- the fixture explicitly so the moving carrier always owns a bullet target of
	-- the intended size instead of inheriting an absent/stale camera fixture.
	if type(drone.initHitbox) == "function" and drone.physics then
		pcall(drone.initHitbox, drone, drone.physics, hitbox, hitbox)
	end
	local fixture = drone.fixture
	if fixture and type(fixture.setFilterData) == "function" then
		pcall(fixture.setFilterData, fixture, drone.P_CATEGORY, drone.P_MASK, drone.P_GROUP)
	end
	return syncPhysicalBody(drone)
end

local function chooseDestination(self)
	local security = self.hcoContext and self.hcoContext.security
	local aggressive = security and security.droneMode == "AGGRESSIVE"
	return flight.destination(self, game and game.playerActor, aggressive)
end

local function hasPlayerLineOfSight(self, player, requireCone)
	local px, py = util.getPos(player)
	if not px then return false end
	local offset = centerOffset(self)
	local sx, sy = (self.x or 0) + offset, (self.y or 0) + offset
	local dx, dy = px - sx, py - sy
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance > (self.radius or config.DRONE_SCAN_RADIUS) then return false end
	if requireCone then
		local heading = self.hcoSensorAngle or self.curViewAngRad or 0
		if flight.angleDifference(math.atan2(dy, dx), heading) > math.rad((self.lightFOV or config.DRONE_FOV) * 0.5) then return false end
	end

	-- Geometry is authoritative. A failed/unsupported raycast falls back to the
	-- cone result; a real blocking fixture still prevents wall vision.
	if type(self.runGenericRaycast) ~= "function" then return true end
	local ok, hitData = pcall(self.runGenericRaycast, self, sx, sy, px, py, player)
	if not ok or not hitData then return true end
	local fixture = hitData.fixture
	if not fixture then return true end
	local okFixture, playerFixture = util.call(player, "getFixture")
	return hitData.fraction == 1 or okFixture and fixture == playerFixture
end

local function canSeePlayer(self, player)
	return hasPlayerLineOfSight(self, player, true)
end

local function notifyConfirmedSighting(self, player)
	local context = self.hcoContext
	if not context or not context.security then return end
	context.security.knowledge = context.security.knowledge or {}
	local x, y = util.getPos(player)
	context.security.droneSighting = {x = x, y = y, time = curTime or 0, drone = self}
	context.security.lastKnown = {x = x, y = y, confidence = 1, source = "search-drone", time = curTime or 0, actor = self}
	context.security.targetThreatLevel = 1
	context.security.huntPhase = "PRESSURE"
	context.security.droneMode = "AGGRESSIVE"
	for _, guard in ipairs(context.security.guards or {}) do
		if guard.role ~= "close_protection" and util.isAlive(guard.actor) then
			context.security.knowledge[util.getID(guard.actor)] = {x=x,y=y,confidence=1,source="search-drone",time=curTime or 0,actor=guard.actor}
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
	local targetID = context.target and util.getID(context.target)
	if targetID then context.security.knowledge[targetID] = {x=x,y=y,confidence=1,source="search-drone",time=curTime or 0,actor=context.target} end
	if not context.security.droneRaidAnnounced then
		context.security.droneRaidAnnounced = true
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
		syncPhysicalBody(self)
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
		self.hcoHitFlash = math.max(0, (self.hcoHitFlash or 0) - dt)
		audio.updateRotor(self.hcoRotorSound, self)
		self.hcoFrameTime = self.hcoFrameTime + dt
		if self.hcoFrameTime >= 0.09 then self.hcoFrameTime = 0 self.hcoFrame = self.hcoFrame % 4 + 1 end
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
		local offset = centerOffset(self)
		local centerX, centerY = (self.x or 0) + offset, (self.y or 0) + offset
		local destDistance = math.sqrt(((self.hcoDestX or centerX) - centerX)^2 + ((self.hcoDestY or centerY) - centerY)^2)
		if not self.hcoDestX or destDistance < 36 or self.hcoTracking > 0 then self.hcoDestX, self.hcoDestY = chooseDestination(self) end
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
			self.hcoDetect = math.min(detectTime, self.hcoDetect + dt)
			self.lightColorCurrent = self.lightColorInactive self:updateCastColor()
			if self.hcoDetect >= detectTime and ((curTime or 0) - (self.hcoLastConfirmedAt or -100)) >= 0.75 then
				self.hcoLastConfirmedAt = curTime or 0
				notifyConfirmedSighting(self, player)
			end
		else
			self.hcoDetect = math.max(0, self.hcoDetect - dt * 0.65)
			self.lightColorCurrent = self.lightColor self:updateCastColor()
		end
		local px, py = util.getPos(player)
		local aimError = math.pi
		if px then
			local offset = centerOffset(self)
			aimError = flight.angleDifference(math.atan2(py - ((self.y or 0) + offset), px - ((self.x or 0) + offset)), self.hcoSensorAngle or 0)
		end
		local confirmed = aggressive and self.hcoTracking > 0 and ((curTime or 0) - (self.hcoLastConfirmedAt or -100)) < 3
		droneWeapons.update(self, player, visible, aimError, dt, confirmed)
		airframes.sync(self.hcoAirframe, self)
		return result
	end

	function drone:breakCam(breaker, quiet)
		if self.broken then return end
		local offset = centerOffset(self)
		local crashX, crashY = (self.x or 0) + offset, (self.y or 0) + offset
		-- Mirror the native camera destruction lifecycle but omit only the booth
		-- callback, because runtime drones deliberately have no camera booth.
		if type(self.setBroken) == "function" then pcall(self.setBroken, self, true) else self.broken = true end
		if self.lightBuffer then
			if type(self.disableLight) == "function" then pcall(self.disableLight, self) end
			if type(self.lightBuffer.clearEffects) == "function" then pcall(self.lightBuffer.clearEffects, self.lightBuffer) end
		end
		if type(self.setDisrupted) == "function" then pcall(self.setDisrupted, self, false) end
		if type(self.setDisruptTime) == "function" then pcall(self.setDisruptTime, self, nil) end
		airframes.remove(self.hcoAirframe)
		self.hcoAirframe = nil
		droneWeapons.remove(self)
		if self.hcoRotorSound then
			if type(self.hcoRotorSound.stop) == "function" then audio.stop(self.hcoRotorSound) elseif sound and sound.manager then pcall(sound.manager.stopSound, sound.manager, self.hcoRotorSound) end
			self.hcoRotorSound = nil
		end
		local security = self.hcoContext and self.hcoContext.security
		if security then
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
			feedback.show("DRONE DOWN — RESPONSE TEAM INVESTIGATING CRASH SITE")
		end
		if not quiet then
			if noise and type(noise.emit) == "function" then pcall(noise.emit, noise, crashX, crashY, self.breakNoise or 700, self, noise.SOUND_TYPES and noise.SOUND_TYPES.OBJECTS) end
			if sound and type(sound.play) == "function" then pcall(sound.play, sound, "camera_break", self) end
		end
	end

	function drone:onHitBullet(bullet, hitData)
		self.hcoArmor = (self.hcoArmor or 1) - 1
		self.hcoHitFlash = 0.16
		local offset = centerOffset(self)
		if sound and type(sound.playWorld) == "function" then pcall(sound.playWorld, sound, "impact_ricochet", self, (self.x or 0) + offset, (self.y or 0) + offset, 0.55, 1.15) end
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
	local hitbox = definition.heavy and 38 or definition.id == "scout" and 30 or 34
	instance.hcoCenterOffset = hitbox * 0.5
	instance.hcoRotorSound = audio.startRotor(instance)
	local doctrine = context.security and context.security.droneDoctrine or {}
	instance.hcoSpeed = (definition.speed or 1) * (doctrine.speed or 1)
	instance.hcoDetectScale = (definition.detect or 1) * (doctrine.detect or 1)
	instance.hcoArmor = math.max(definition.armor or 1, math.floor((definition.armor or 1) * (doctrine.armor or 1) + 0.5))
	instance.hcoFallback = usedFallback
	instance.radius = config.DRONE_SCAN_RADIUS * (definition.scanRadius or 1) * (doctrine.radius or 1)
	instance.lightFOV = definition.fov or config.DRONE_FOV
	instance.hitboxW, instance.hitboxH = hitbox, hitbox
	if type(instance.setSize) == "function" then pcall(instance.setSize, instance, hitbox, hitbox) end
	local spawnX, spawnY = flight.spawnPoint(context, index)
	if not spawnX then return nil, "safe-spawn-point-unavailable" end
	local initialAngle = math.atan2(y - spawnY, x - spawnX)
	instance.hcoBodyAngle, instance.hcoSensorAngle = initialAngle, initialAngle
	instance:setPos(spawnX - instance.hcoCenterOffset, spawnY - instance.hcoCenterOffset)
	instance:setViewAngle(math.deg(initialAngle))
	instance:setLightAngle(math.deg(initialAngle))
	local placed, placeError = pcall(function()
		instance:onPlacedIntoMap()
		instance.hcoHitboxReady = ensurePhysicalHitbox(instance, hitbox)
		if not instance.hcoHitboxReady then util.log(config, "WARNING drone physical hitbox unavailable model=" .. tostring(definition.id)) end
		if type(instance.makeAimable) == "function" then instance:makeAimable() end
		game.addDynamicObject(instance)
	end)
	if not placed then return nil, "placement-failed: " .. tostring(placeError) end
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
	local diagnostic = security and security.droneRenderDiagnostic
	if not diagnostic then return end
	diagnostic.remaining = diagnostic.remaining - dt
	if diagnostic.remaining > 0 then return end
	security.droneRenderDiagnostic = nil
	local stats = airframes.diagnostics()
	local rendered = stats.drawPasses > diagnostic.startPasses
	feedback.show("HCO RC25 DRONE ROSTER — quadtree " .. (rendered and "ACTIVE" or "NOT DRAWN") .. ", batch " .. (stats.batchReady and "READY" or "MISSING") .. ", sprite " .. (stats.spriteReady and "READY" or "MISSING") .. ", bodies " .. tostring(stats.airframes))
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
	local security = context.security
	if not security then return end
	updateRenderDiagnostic(security, dt)
	security.droneCooldown = math.max(0, (security.droneCooldown or 0) - dt)
	local wanted = security.droneDeploymentRequested or 0
	if wanted <= 0 or security.droneCooldown > 0 then return end
	security.drones = security.drones or {}
	local live = {}
	for _, drone in ipairs(security.drones) do if drone and not drone.broken then table.insert(live, drone) end end
	security.drones = live
	local room = math.max(0, config.DRONE_MAX_COUNT - #live)
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
end

return drones
