local config = require("hco/config")
local util = require("hco/util")

local airframes = {}
local CLASS_ID = "hco_drone_airframe"
local BATCH_ID = "hco_drone_roster_airframes"
local BATCH_DEPTH = 68
local SPRITE_FORWARD_OFFSET = -math.pi * 0.5
local CELL_SIZE = 96
local FRAME_COUNT = 4
local TYPE_COUNT = 7
local classData
local sprite, quads, batch
local live = {}
local drawPasses = 0

local function loadSprite()
	if sprite or not love or not love.graphics then return sprite ~= nil end
	local candidates = {
		"mods/Hitman-Contracts-Overhaul/files/assets/hco/drone-roster-atlas.png",
		"mods/Hitman-Contracts-Overhaul/assets/hco/drone-roster-atlas.png",
		"assets/hco/drone-roster-atlas.png"
	}
	for _, path in ipairs(candidates) do
		local ok, image = pcall(love.graphics.newImage, path)
		if ok and image then
			sprite = image
			image:setFilter("nearest", "nearest")
			quads = {}
			for typeIndex = 1, TYPE_COUNT do
				quads[typeIndex] = {}
				for frame = 0, FRAME_COUNT - 1 do
					quads[typeIndex][frame + 1] = love.graphics.newQuad(frame * CELL_SIZE, (typeIndex - 1) * CELL_SIZE, CELL_SIZE, CELL_SIZE, FRAME_COUNT * CELL_SIZE, TYPE_COUNT * CELL_SIZE)
				end
			end
			return true
		end
	end
	return false
end

local function ensureBatchRegistered()
	if not batch then return false end
	local registered = priorityRenderer and priorityRenderer.activeRenderMap and priorityRenderer.activeRenderMap[batch]
	if registered and type(priorityRenderer.findObject) == "function" then registered = priorityRenderer:findObject(batch) ~= nil end
	if not registered and priorityRenderer and type(priorityRenderer.add) == "function" then
		if priorityRenderer.activeRenderMap then priorityRenderer.activeRenderMap[batch] = nil end
		priorityRenderer:add(batch, BATCH_DEPTH)
	end
	return true
end

local function ensureBatch()
	if batch and spriteBatchController and spriteBatchController.getContainer then
		local current = spriteBatchController:getContainer(BATCH_ID)
		if current == batch then return true end
		batch = nil
	end
	if not loadSprite() or not spriteBatchController or type(spriteBatchController.newSpriteBatch) ~= "function" then return false end
	-- Three simultaneous contracts may each field seven drones.
	local ok, container = pcall(spriteBatchController.newSpriteBatch, spriteBatchController, BATCH_ID, sprite, 32, "stream", BATCH_DEPTH, false, true, false, true)
	if not ok or not container then return false end
	batch = container
	if type(batch.setShouldSortSprites) == "function" then batch:setShouldSortSprites(false) end
	return true
end

local function releaseSlot(self)
	if not self.hcoSlot or not batch then self.hcoSlot = nil return end
	if type(batch.getAllocatedSlot) ~= "function" or batch:getAllocatedSlot(self.hcoSlot) then
		pcall(batch.deallocateSlot, batch, self.hcoSlot)
		if type(batch.getVisibility) ~= "function" or batch:getVisibility() > 0 then pcall(batch.decreaseVisibility, batch) end
	end
	self.hcoSlot = nil
end

local function ensureSlot(self)
	if not ensureBatch() then return false end
	if self.hcoSlot and type(batch.getAllocatedSlot) == "function" and not batch:getAllocatedSlot(self.hcoSlot) then self.hcoSlot = nil end
	if not self.hcoSlot then
		local ok, slot = pcall(batch.allocateSlot, batch)
		if not ok or not slot then return false end
		self.hcoSlot = slot
		if type(batch.increaseVisibility) == "function" then batch:increaseVisibility() end
	end
	ensureBatchRegistered()
	return true
end

function airframes.initialize()
	if classData then return true end
	if not objects or type(objects.registerNew) ~= "function" then return false end
	local existing = objects.getClassData and objects.getClassData(CLASS_ID)
	if existing then classData = existing return ensureBatch() end

	local visual = {
		class = CLASS_ID,
		ADD_TO_OBJECT_LIST = false,
		QT_DRAWABLE = true,
		MEMORIZE = false,
		AIMABLE = false,
		INTERACT = false,
		REMOVE_PHYSICS = false,
		canSave = false,
		canReset = false,
		width = 96,
		height = 96,
		_HCO_DRONE_AIRFRAME = true
	}

	function visual:init()
		visual.baseClass.init(self)
		self.hcoFrame = 1
		self.hcoBodyAngle = 0
		self.hcoSensorAngle = 0
		self.hcoTypeIndex = 1
		self.hcoRenderScale = 0.34
		self.hcoSlot = nil
		self.hcoMoveX, self.hcoMoveY = 0, 0
		self.hcoPhase = 0
		self.renderTree = game.worldObject:getDecorQuadTree()
	end

	function visual:getQuadTreeBox() return self.x - 48, self.y - 48, 96, 96 end
	function visual:getCenter() return self.x, self.y end
	function visual:getDrawPosition() return self.x, self.y end

	function visual:_onPlacedIntoMap()
		visual.baseClass._onPlacedIntoMap(self)
		game.worldObject:addDecorEntity(self, true)
	end

	function visual:setPose(x, y, bodyAngle, sensorAngle, frame, typeIndex, renderScale)
		local dx, dy = x - (self.x or x), y - (self.y or y)
		self.hcoMoveX = self.hcoMoveX * 0.72 + dx * 0.28
		self.hcoMoveY = self.hcoMoveY * 0.72 + dy * 0.28
		self.x, self.y = x, y
		self.hcoBodyAngle = bodyAngle or self.hcoBodyAngle
		self.hcoSensorAngle = sensorAngle or self.hcoSensorAngle
		self.hcoFrame = frame or self.hcoFrame
		self.hcoTypeIndex = typeIndex or self.hcoTypeIndex
		self.hcoRenderScale = renderScale or self.hcoRenderScale
		if self._placed and self.renderTree then self.renderTree:insert(self) end
	end

	local function drawFlightEffects(self, drawX, drawY, renderAngle)
		local graphics = love.graphics
		local time = curTime or 0
		local speed = math.sqrt(self.hcoMoveX * self.hcoMoveX + self.hcoMoveY * self.hcoMoveY)
		local moveX, moveY = 0, 0
		if speed > 0.01 then moveX, moveY = self.hcoMoveX / speed, self.hcoMoveY / speed end

		-- Soft offset shadow and short pixel wakes make altitude and direction
		-- readable without adding a non-native particle system.
		graphics.setColor(0, 0, 0, 75)
		graphics.circle("fill", drawX + 5, drawY + 7, 9)
		if speed > 0.12 and type(graphics.rectangle) == "function" then
			local sideX, sideY = -moveY, moveX
			for index = 1, 4 do
				local spread = math.sin(time * 9 + self.hcoPhase + index * 1.7) * (1 + index * 0.6)
				local px = drawX - moveX * (10 + index * 6) + sideX * spread
				local py = drawY - moveY * (10 + index * 6) + sideY * spread
				graphics.setColor(70, 195, 225, math.max(25, 125 - index * 24))
				graphics.rectangle("fill", math.floor(px), math.floor(py), index == 1 and 3 or 2, 2)
			end
		end

		local effectScale = self.hcoHeavy and 1.25 or 1
		graphics.push()
		graphics.translate(drawX, drawY)
		graphics.rotate(renderAngle)
		graphics.setLineWidth(1)
		local rotorPulse = 3.2 + math.abs(math.sin(time * 18 + self.hcoPhase)) * 1.4
		local rotorAlpha = self.hcoDisrupted and 65 or 125
		graphics.setColor(125, 225, 245, rotorAlpha)
		for _, rotor in ipairs({{-9,-7},{9,-7},{-9,7},{9,7}}) do graphics.circle("line", rotor[1] * effectScale, rotor[2] * effectScale, rotorPulse * effectScale) end
		graphics.pop()

		-- The airframe follows its flight vector, while the camera/weapon head is
		-- a real gimbal that can look sideways without snapping the whole drone.
		graphics.push()
		graphics.translate(drawX, drawY)
		graphics.rotate((self.hcoSensorAngle or 0) + SPRITE_FORWARD_OFFSET)
		local sensorPulse = 1.8 + math.abs(math.sin(time * 7 + self.hcoPhase)) * 1.2
		if self.hcoDisrupted then
			graphics.setColor(90, 150, 255, 170)
		elseif self.hcoAggressive or self.hcoAcquiring then
			graphics.setColor(255, 70, 55, 230)
		else
			graphics.setColor(65, 245, 255, 220)
		end
		graphics.circle("fill", 0, 9 * effectScale, sensorPulse * effectScale)
		graphics.setLineWidth(1)
		graphics.line(0, 5 * effectScale, 0, 13 * effectScale)
		graphics.pop()

		if self.hcoAimTargetX and self.hcoAimTargetY then
			local charging = self.hcoWeaponState == "CHARGING"
			local pulse = 0.45 + math.abs(math.sin(time * 15 + self.hcoPhase)) * 0.55
			graphics.setLineWidth(self.hcoHeavy and 2 or 1)
			if charging then graphics.setColor(255, 45, 35, 120 + math.floor(pulse * 100)) else graphics.setColor(255, 110, 50, 105) end
			graphics.line(drawX, drawY, self.hcoAimTargetX, self.hcoAimTargetY)
			if self.hcoLaserPulse and self.hcoLaserPulse > 0 then
				graphics.setLineWidth(self.hcoHeavy and 5 or 3)
				graphics.setColor(255, 235, 210, 235)
				graphics.line(drawX, drawY, self.hcoAimTargetX, self.hcoAimTargetY)
			end
		end
		if self.hcoMuzzleFlash and self.hcoMuzzleFlash > 0 then
			local muzzleX = drawX + math.cos(self.hcoSensorAngle or 0) * 14
			local muzzleY = drawY + math.sin(self.hcoSensorAngle or 0) * 14
			graphics.setColor(255, 210, 80, 235)
			graphics.circle("fill", muzzleX, muzzleY, self.hcoHeavy and 4 or 3)
		end
		if self.hcoHitFlash and self.hcoHitFlash > 0 then
			local pulseLife = math.min(1, self.hcoHitFlash / 0.42)
			local expansion = 1 - pulseLife
			graphics.setLineWidth(self.hcoLastArmorDamage and self.hcoLastArmorDamage >= 2 and 3 or 2)
			graphics.setColor(255, 235, 155, 100 + math.floor(pulseLife * 155))
			graphics.circle("line", drawX, drawY, 9 + expansion * 19)
			graphics.setColor(255, 205, 80, 245)
			for index = 1, 9 do
				local angle = self.hcoPhase + index * 1.31
				local distance = 8 + expansion * 20 + index * 0.8
				graphics.rectangle("fill", math.floor(drawX + math.cos(angle) * distance), math.floor(drawY + math.sin(angle) * distance), index % 3 == 0 and 3 or 2, 2)
			end
		end
		if self.hcoArmorDisplay and self.hcoArmorDisplay > 0 and (self.hcoArmorMax or 1) > 1 then
			local maximum = math.min(3, self.hcoArmorMax or 1)
			local width = maximum * 6 - 2
			for index = 1, maximum do
				if index <= (self.hcoArmor or 0) then graphics.setColor(95, 220, 255, 230) else graphics.setColor(255, 85, 55, 175) end
				graphics.rectangle("fill", math.floor(drawX - width * 0.5 + (index - 1) * 6), math.floor(drawY + 17), 4, 3)
			end
		end
		graphics.setColor(255, 255, 255, 255)
	end

	local function crashPose(self, time)
		local age = math.max(0, time - (self.hcoCrashAt or time))
		local duration = self.hcoCrashDuration or 0.85
		local progress = util.clamp(age / duration, 0, 1)
		local eased = 1 - (1 - progress) * (1 - progress)
		local sway = math.sin(progress * math.pi * 3 + self.hcoPhase) * (1 - progress) * 7
		local drawX = (self.hcoCrashStartX or self.x) + ((self.hcoCrashEndX or self.x) - (self.hcoCrashStartX or self.x)) * eased + (self.hcoCrashSideX or 0) * sway
		local drawY = (self.hcoCrashStartY or self.y) + ((self.hcoCrashEndY or self.y) - (self.hcoCrashStartY or self.y)) * eased + (self.hcoCrashSideY or 0) * sway
		local renderAngle = (self.hcoCrashStartAngle or 0) + (self.hcoCrashSpin or math.pi * 2) * eased + math.sin(progress * math.pi * 7) * (1 - progress) * 0.16
		local scale = (self.hcoRenderScale or 0.34) * (1 - eased * 0.12)
		return drawX, drawY, renderAngle, scale, age, progress
	end

	local function drawCrashEffects(self, drawX, drawY, age, progress)
		local graphics = love.graphics
		local duration = self.hcoCrashDuration or 0.85
		local endX, endY = self.hcoCrashEndX or drawX, self.hcoCrashEndY or drawY
		graphics.setColor(0, 0, 0, 55 + math.floor(progress * 80))
		graphics.circle("fill", endX + 2, endY + 3, 7 + progress * 5)

		if progress < 1 then
			-- A short segmented smoke ribbon and hot fragments communicate lost
			-- lift and direction without introducing a detached particle engine.
			for index = 1, 5 do
				local lag = index * 0.11
				local sample = util.clamp(progress - lag, 0, 1)
				local px = (self.hcoCrashStartX or drawX) + (endX - (self.hcoCrashStartX or drawX)) * sample
				local py = (self.hcoCrashStartY or drawY) + (endY - (self.hcoCrashStartY or drawY)) * sample
				graphics.setColor(42, 48, 52, math.max(25, 150 - index * 21))
				graphics.circle("fill", math.floor(px), math.floor(py), 2 + index * 0.55)
			end
			for index = 1, 8 do
				local angle = self.hcoPhase + index * 2.17 + age * 8
				local distance = 7 + index * 1.4 + progress * 8
				graphics.setColor(255, index % 2 == 0 and 210 or 120, 45, 235 - index * 14)
				graphics.rectangle("fill", math.floor(drawX + math.cos(angle) * distance), math.floor(drawY + math.sin(angle) * distance), index % 3 == 0 and 3 or 2, 2)
			end
			graphics.setColor(255, 235, 170, 190)
			graphics.circle("fill", drawX, drawY, 3 + math.abs(math.sin(age * 22)) * 2)
		end

		local impactAge = age - duration * 0.72
		if impactAge >= 0 and impactAge <= 0.72 then
			local impactProgress = impactAge / 0.72
			graphics.setLineWidth(3 - impactProgress * 2)
			graphics.setColor(255, 145, 65, math.floor((1 - impactProgress) * 235))
			graphics.circle("line", endX, endY, 6 + impactProgress * 31)
		end

		if progress >= 1 then
			for index = 1, 6 do
				local angle = self.hcoPhase + index * 1.41
				local distance = 7 + index * 2.2
				graphics.setColor(65, 70, 73, 210)
				graphics.rectangle("fill", math.floor(endX + math.cos(angle) * distance), math.floor(endY + math.sin(angle) * distance), index % 2 == 0 and 4 or 3, 2)
			end
			local smokeAge = age - duration
			if smokeAge < 4 then
				for index = 1, 4 do
					local drift = smokeAge + index * 0.18
					graphics.setColor(35, 40, 43, math.max(0, 135 - math.floor(drift * 27)))
					graphics.circle("fill", math.floor(endX + math.sin(self.hcoPhase + index) * (3 + drift * 2)), math.floor(endY - drift * (4 + index)), 3 + drift * 1.3)
				end
			end
		end
		graphics.setColor(255, 255, 255, 255)
	end

	function visual:enterVisibilityRange()
		self._visible = true
		ensureSlot(self)
	end

	function visual:leaveVisibilityRange()
		self._visible = false
		releaseSlot(self)
	end

	function visual:draw()
		drawPasses = drawPasses + 1
		local time = curTime or 0
		local bob = math.sin(time * 6.5 + self.hcoPhase) * 1.1
		local drawX, drawY = self.x, self.y + bob
		local renderAngle = (self.hcoBodyAngle or 0) + SPRITE_FORWARD_OFFSET
		local scale = self.hcoRenderScale or 0.55
		local crashAge, crashProgress
		if self.hcoCrashAt then
			drawX, drawY, renderAngle, scale, crashAge, crashProgress = crashPose(self, time)
			drawCrashEffects(self, drawX, drawY, crashAge, crashProgress)
		else
			drawFlightEffects(self, drawX, drawY, renderAngle)
		end
		if ensureSlot(self) and sprite and quads then
			local alpha = self.hcoDisrupted and (110 + math.floor(math.abs(math.sin(time * 17)) * 100)) or 255
			if self.hcoCrashAt then
				if crashProgress < 1 then batch:setColor(255, 135, 70, 245) else batch:setColor(72, 78, 82, 190) end
			elseif self.hcoHitFlash and self.hcoHitFlash > 0 then
				batch:setColor(255, 185, 95, alpha)
			else
				batch:setColor(255, 255, 255, alpha)
			end
			local typeQuads = quads[self.hcoTypeIndex or 1] or quads[1]
			local frame = self.hcoCrashAt and crashProgress < 1 and (math.floor(crashAge / 0.06) % FRAME_COUNT + 1) or self.hcoFrame or 1
			batch:updateSprite(self.hcoSlot, typeQuads[frame], drawX, drawY, renderAngle, scale, scale, 48, 48)
			return
		end
		-- Texture-independent last resort, still executed by the native world
		-- quadtree rather than by an external overlay.
		if self.hcoCrashAt then love.graphics.setColor(85, 70, 60, 230) else love.graphics.setColor(90, 225, 255, 255) end
		love.graphics.circle("fill", drawX, drawY, 12)
		love.graphics.line(drawX - 22, drawY - 14, drawX + 22, drawY + 14)
		love.graphics.line(drawX - 22, drawY + 14, drawX + 22, drawY - 14)
	end

	function visual:remove()
		if not self:isValid() then return end
		releaseSlot(self)
		if game and game.worldObject then
			local handler = game.worldObject.getDecorQuadTreeVisHandler and game.worldObject:getDecorQuadTreeVisHandler()
			if handler and type(handler.removeObject) == "function" then pcall(handler.removeObject, handler, self) end
			if self.WITHINQUADTREE then pcall(game.worldObject.removeDecorationEntity, game.worldObject, self) end
		end
		visual.baseClass.remove(self)
	end

	objects.registerNew(visual)
	classData = visual
	loadSprite()
	return true
end

function airframes.create(owner, x, y)
	if not classData and not airframes.initialize() then return nil, "airframe-class-unavailable" end
	local ok, shell = pcall(objects.create, CLASS_ID)
	if not ok or not shell then return nil, "airframe-create-failed: " .. tostring(shell) end
	shell.hcoOwner = owner
	shell.hcoContext = owner and owner.hcoContext
	shell.hcoPhase = ((owner and owner.hcoIndex) or 1) * 1.61803398875
	local definition = owner and owner.hcoType or {}
	shell:setPose(x, y, owner and owner.hcoBodyAngle or owner and owner.curViewAngRad or 0, owner and owner.hcoSensorAngle or owner and owner.curViewAngRad or 0, 1, definition.index or 1, definition.renderScale or 0.34)
	local placed, placeError = pcall(shell.onPlacedIntoMap, shell)
	if not placed then return nil, "airframe-placement-failed: " .. tostring(placeError) end
	table.insert(live, shell)
	return shell
end

function airframes.sync(shell, owner)
	if shell and shell.isValid and shell:isValid() and owner then
		if shell.hcoCrashAt then return end
		shell.hcoDisrupted = owner.disrupted == true
		shell.hcoAggressive = owner.hcoContext and owner.hcoContext.security and owner.hcoContext.security.droneMode == "AGGRESSIVE"
		shell.hcoAcquiring = (owner.hcoDetect or 0) > 0
		shell.hcoHeavy = owner.hcoType and owner.hcoType.heavy == true
		shell.hcoWeaponState = owner.hcoWeaponState
		shell.hcoAimTargetX, shell.hcoAimTargetY = owner.hcoAimTargetX, owner.hcoAimTargetY
		shell.hcoLaserPulse, shell.hcoMuzzleFlash = owner.hcoLaserPulse, owner.hcoMuzzleFlash
		shell.hcoHitFlash = owner.hcoHitFlash
		shell.hcoImpactPulse = owner.hcoImpactPulse
		shell.hcoImpactX, shell.hcoImpactY = owner.hcoImpactX, owner.hcoImpactY
		shell.hcoArmorDisplay = owner.hcoArmorDisplay
		shell.hcoArmor, shell.hcoArmorMax = owner.hcoArmor, owner.hcoArmorMax
		shell.hcoLastArmorDamage = owner.hcoLastArmorDamage
		local definition = owner.hcoType or {}
		local offset = owner.hcoCenterOffset or 13
		shell:setPose((owner.x or 0) + offset, (owner.y or 0) + offset, owner.hcoBodyAngle or owner.curViewAngRad or 0, owner.hcoSensorAngle or owner.curViewAngRad or 0, owner.hcoFrame or 1, definition.index or 1, definition.renderScale or 0.34)
	end
end

local function clampCrashPoint(x, y)
	local worldObject = game and game.worldObject
	if worldObject and type(worldObject.getSize) == "function" then
		local ok, width, height = pcall(worldObject.getSize, worldObject)
		if ok and tonumber(width) and tonumber(height) then return util.clamp(x, 24, width - 24), util.clamp(y, 24, height - 24) end
	end
	return x, y
end

function airframes.crash(shell, owner, fallbackX, fallbackY)
	if not shell or not shell.isValid or not shell:isValid() then return fallbackX, fallbackY end
	airframes.sync(shell, owner)
	if shell.hcoCrashAt then return shell.hcoCrashEndX, shell.hcoCrashEndY end
	local startX, startY = shell.x or fallbackX or 0, shell.y or fallbackY or 0
	local moveX, moveY = shell.hcoMoveX or 0, shell.hcoMoveY or 0
	local speed = math.sqrt(moveX * moveX + moveY * moveY)
	if speed <= 0.05 then
		local angle = shell.hcoBodyAngle or 0
		moveX, moveY, speed = math.cos(angle), math.sin(angle), 1
	end
	local dirX, dirY = moveX / speed, moveY / speed
	local sideX, sideY = -dirY, dirX
	local direction = ((owner and owner.hcoIndex or 1) % 2 == 0) and -1 or 1
	local distance = shell.hcoHeavy and 34 or 42
	local endX = startX + dirX * distance + sideX * 10 * direction
	local endY = startY + dirY * distance + sideY * 10 * direction
	endX, endY = clampCrashPoint(endX, endY)
	shell.hcoCrashAt = curTime or 0
	shell.hcoCrashDuration = shell.hcoHeavy and 0.95 or 0.78
	shell.hcoCrashStartX, shell.hcoCrashStartY = startX, startY
	shell.hcoCrashEndX, shell.hcoCrashEndY = endX, endY
	shell.hcoCrashSideX, shell.hcoCrashSideY = sideX, sideY
	shell.hcoCrashStartAngle = (shell.hcoBodyAngle or 0) + SPRITE_FORWARD_OFFSET
	shell.hcoCrashSpin = direction * math.pi * (shell.hcoHeavy and 2.35 or 3.1)
	shell.hcoArmor, shell.hcoArmorDisplay = 0, 0
	shell.hcoAimTargetX, shell.hcoAimTargetY = nil, nil
	shell.hcoWeaponState = "DESTROYED"
	return endX, endY
end

function airframes.drawOutline(shell)
	if not shell or not shell.isValid or not shell:isValid() or not loadSprite() then return false end
	local typeQuads = quads and (quads[shell.hcoTypeIndex or 1] or quads[1])
	local quad = typeQuads and typeQuads[shell.hcoFrame or 1]
	if not quad then return false end
	local bob = math.sin((curTime or 0) * 6.5 + (shell.hcoPhase or 0)) * 1.1
	local renderAngle = (shell.hcoBodyAngle or 0) + SPRITE_FORWARD_OFFSET
	local scale = shell.hcoRenderScale or 0.55
	-- Aim outlines are drawn by a separate native pass. Drawing the atlas frame
	-- directly keeps that pass compatible without asking the invisible runtime
	-- security-camera carrier for a quadStruct it deliberately does not own.
	love.graphics.draw(sprite, quad, shell.x, shell.y + bob, renderAngle, scale, scale, 48, 48)
	return true
end

function airframes.remove(shell)
	if shell and shell.isValid and shell:isValid() then pcall(shell.remove, shell) end
end

function airframes.clearContext(context)
	local remaining = {}
	for _, shell in ipairs(live) do
		if shell and shell.isValid and shell:isValid() then
			if shell.hcoContext == context then pcall(shell.remove, shell) else table.insert(remaining, shell) end
		end
	end
	live = remaining
end

function airframes.diagnostics()
	local count, wrecks = 0, 0
	for _, shell in ipairs(live) do
		if shell and shell.isValid and shell:isValid() then
			if shell.hcoCrashAt then wrecks = wrecks + 1 else count = count + 1 end
		end
	end
	return {drawPasses = drawPasses, spriteReady = sprite ~= nil, batchReady = batch ~= nil, airframes = count, wrecks = wrecks}
end

return airframes
