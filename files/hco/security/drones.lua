local config = require("hco/config")
local audio = require("hco/audio")
local feedback = require("hco/feedback")
local util = require("hco/util")

local drones = {}
local CLASS_ID = "hco_search_drone"
local registered = false
local sprite, quads
local droneClass

local function loadSprite()
	if sprite or not love or not love.graphics or type(love.graphics.newImage) ~= "function" then return end
	local candidates = {
		"mods/Hitman-Contracts-Overhaul/files/assets/hco/drone-flight-sheet.png",
		"mods/Hitman-Contracts-Overhaul/assets/hco/drone-flight-sheet.png",
		"assets/hco/drone-flight-sheet.png"
	}
	for _, path in ipairs(candidates) do
		local ok, image = pcall(love.graphics.newImage, path)
		if ok and image then
			sprite = image
			image:setFilter("nearest", "nearest")
			quads = {}
			for frame = 0, 3 do quads[frame + 1] = love.graphics.newQuad(frame * 96, 0, 96, 96, 384, 96) end
			return
		end
	end
end

local function chooseDestination(self)
	local security = self.hcoContext and self.hcoContext.security
	local points = security and security.sectorPoints or {}
	local aggressive = security and security.droneMode == "AGGRESSIVE"
	if aggressive and security.lastKnown then
		local angle = (self.hcoIndex * 2.399 + (curTime or 0) * 0.05)
		return security.lastKnown.x + math.cos(angle) * 180, security.lastKnown.y + math.sin(angle) * 180
	elseif aggressive and #points > 0 then
		self.hcoSearchStep = (self.hcoSearchStep or 0) + 1
		local point = points[(self.hcoSearchStep + self.hcoIndex - 2) % #points + 1]
		return point.x, point.y
	end
	local targetX, targetY = util.getPos(self.hcoContext and self.hcoContext.target)
	if targetX then
		self.hcoSearchStep = (self.hcoSearchStep or 0) + 1
		local angle = self.hcoIndex * 2.399 + self.hcoSearchStep * 0.9
		local radius = 150 + (self.hcoIndex % 3) * 55
		return targetX + math.cos(angle) * radius, targetY + math.sin(angle) * radius
	end
	return targetX, targetY
end

local function notifyConfirmedSighting(self, player)
	local context = self.hcoContext
	if not context or not context.security then return end
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
	if context.target then context.security.knowledge[util.getID(context.target)] = {x=x,y=y,confidence=1,source="search-drone",time=curTime or 0,actor=context.target} end
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
		loadSprite()
		self.hcoRotorSound = audio.startRotor(self)
		if not self.hcoRotorSound and sound and type(sound.playWorld) == "function" then
			local ok, container = pcall(sound.playWorld, sound, "light_malfunctioning", self, self.x, self.y, 0.24, 1.55)
			if ok then self.hcoRotorSound = container end
		end
	end

	function drone:getDrawColor()
		-- Keep the native camera body visible as a guaranteed in-engine marker.
		-- The animated flight sheet is layered over it when available.
		return 255, 255, 255, 255
	end

	function drone:postDraw()
		if self.broken or not sprite or not quads then return end
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(sprite, quads[self.hcoFrame], self.x + 13, self.y + 13, self.curViewAngRad or 0, 0.5, 0.5, 48, 48)
	end

	function drone:update(dt)
		if self.broken then return false end
		audio.updateRotor(self.hcoRotorSound, self)
		self.hcoFrameTime = self.hcoFrameTime + dt
		if self.hcoFrameTime >= 0.09 then self.hcoFrameTime = 0 self.hcoFrame = self.hcoFrame % 4 + 1 end

		local security = self.hcoContext and self.hcoContext.security
		local aggressive = security and security.droneMode == "AGGRESSIVE"
		local modeSpeed = aggressive and config.DRONE_AGGRESSIVE_SPEED_MULTIPLIER or config.DRONE_PATROL_SPEED_MULTIPLIER
		local dx, dy = (self.hcoDestX or self.x) - self.x, (self.hcoDestY or self.y) - self.y
		local distance = math.sqrt(dx * dx + dy * dy)
		if distance < 36 or not self.hcoDestX then self.hcoDestX, self.hcoDestY = chooseDestination(self) dx, dy = (self.hcoDestX or self.x) - self.x, (self.hcoDestY or self.y) - self.y distance = math.sqrt(dx * dx + dy * dy) end
		if distance > 1 then
			local step = math.min(distance, config.DRONE_SPEED * (self.hcoSpeed or 1) * modeSpeed * dt)
			self:setPos(self.x + dx / distance * step, self.y + dy / distance * step)
			self:setLightAngle(math.deg(math.atan2(dy, dx)))
		end

		local player = game and game.playerActor
		local visible = false
		if player and util.isAlive(player) then
			local ok, hit = pcall(self.checkVision, self, player)
			visible = ok and hit == true
		end
		if visible then
			local detectTime = config.DRONE_DETECT_TIME * (self.hcoDetectScale or 1) * (aggressive and 1 or config.DRONE_PATROL_DETECT_MULTIPLIER)
			self.hcoDetect = math.min(detectTime, self.hcoDetect + dt)
			self.lightColorCurrent = self.lightColorInactive self:updateCastColor()
			if self.hcoDetect >= detectTime then notifyConfirmedSighting(self, player) end
		else
			self.hcoDetect = math.max(0, self.hcoDetect - dt * 0.65)
			self.lightColorCurrent = self.lightColor self:updateCastColor()
		end
		return drone.baseClass.update(self, dt)
	end

	function drone:breakCam(breaker, quiet)
		if self.broken then return end
		-- Native security cameras report to a booth. Runtime drones deliberately
		-- have no booth, so calling the native breakCam would index nil.
		if type(self.setBroken) == "function" then pcall(self.setBroken, self, true) else self.broken = true end
		if self.hcoRotorSound then
			if type(self.hcoRotorSound.stop) == "function" then audio.stop(self.hcoRotorSound) elseif sound and sound.manager then pcall(sound.manager.stopSound, sound.manager, self.hcoRotorSound) end
			self.hcoRotorSound = nil
		end
		if self.hcoContext and self.hcoContext.security then self.hcoContext.security.dronesDestroyed = (self.hcoContext.security.dronesDestroyed or 0) + 1 end
	end

	function drone:onHitBullet(bullet, hitData)
		self.hcoArmor = (self.hcoArmor or 1) - 1
		if self.hcoArmor <= 0 then self:breakCam(bullet and bullet.getFirer and bullet:getFirer() or nil) end
	end

	function drone:remove()
		if self.hcoRotorSound then
			if type(self.hcoRotorSound.stop) == "function" then audio.stop(self.hcoRotorSound) elseif sound and sound.manager then pcall(sound.manager.stopSound, sound.manager, self.hcoRotorSound) end
			self.hcoRotorSound = nil
		end
		return drone.baseClass.remove(self)
	end

	drone.baseClass = nativeCameraClass
	droneClass = drone
	registered = true
	loadSprite()
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
		instance.postDraw = droneClass.postDraw
		instance.update = droneClass.update
		instance.breakCam = droneClass.breakCam
		instance.onHitBullet = droneClass.onHitBullet
		instance.remove = droneClass.remove
		instance.hcoDetect = 0
		instance.hcoFrameTime = 0
		instance.hcoFrame = 1
		instance.hcoSearchStep = 0
		loadSprite()
		instance.hcoRotorSound = audio.startRotor(instance)
		util.log(config, "native security-camera drone instance prepared")
	end
	local angle = index * math.pi * 2 / math.max(1, config.DRONE_DEPLOY_COUNT)
	instance.hcoContext = context
	instance.hcoIndex = index
	local doctrine = context.security and context.security.droneDoctrine or {}
	instance.hcoSpeed = doctrine.speed or 1
	instance.hcoDetectScale = doctrine.detect or 1
	instance.hcoArmor = doctrine.armor or 1
	instance.hcoFallback = usedFallback
	instance.radius = config.DRONE_SCAN_RADIUS * (doctrine.radius or 1)
	instance:setPos(x + math.cos(angle) * 180, y + math.sin(angle) * 180)
	instance:setViewAngle(math.deg(angle))
	local placed, placeError = pcall(function()
		instance:onPlacedIntoMap()
		game.addDynamicObject(instance)
	end)
	if not placed then return nil, "placement-failed: " .. tostring(placeError) end
	return instance
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
	for index = 1, math.min(wanted, room) do local drone, spawnError = spawn(context, #live + index) if drone then table.insert(security.drones, drone) launched = launched + 1 else lastError = spawnError end end
	security.droneDeploymentRequested = 0
	security.droneCooldown = config.DRONE_REDEPLOY_COOLDOWN
	security.droneRequestNoticeShown = false
	if launched > 0 then
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
		if drone then pcall(game.removeDynamicObject, drone) pcall(drone.remove, drone) end
	end
end

return drones
