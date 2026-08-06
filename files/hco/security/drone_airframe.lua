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
			graphics.setColor(255, 225, 120, 235)
			for index = 1, 5 do
				local angle = self.hcoPhase + index * 1.31
				graphics.rectangle("fill", math.floor(drawX + math.cos(angle) * (8 + index)), math.floor(drawY + math.sin(angle) * (8 + index)), 2, 2)
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
		local bob = math.sin((curTime or 0) * 6.5 + self.hcoPhase) * 1.1
		local drawX, drawY = self.x, self.y + bob
		local renderAngle = (self.hcoBodyAngle or 0) + SPRITE_FORWARD_OFFSET
		drawFlightEffects(self, drawX, drawY, renderAngle)
		if ensureSlot(self) and sprite and quads then
			local alpha = self.hcoDisrupted and (110 + math.floor(math.abs(math.sin((curTime or 0) * 17)) * 100)) or 255
			batch:setColor(255, 255, 255, alpha)
			local typeQuads = quads[self.hcoTypeIndex or 1] or quads[1]
			local scale = self.hcoRenderScale or 0.55
			batch:updateSprite(self.hcoSlot, typeQuads[self.hcoFrame or 1], drawX, drawY, renderAngle, scale, scale, 48, 48)
			return
		end
		-- Texture-independent last resort, still executed by the native world
		-- quadtree rather than by an external overlay.
		love.graphics.setColor(90, 225, 255, 255)
		love.graphics.circle("fill", self.x, self.y, 12)
		love.graphics.line(self.x - 22, self.y - 14, self.x + 22, self.y + 14)
		love.graphics.line(self.x - 22, self.y + 14, self.x + 22, self.y - 14)
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
		shell.hcoDisrupted = owner.disrupted == true
		shell.hcoAggressive = owner.hcoContext and owner.hcoContext.security and owner.hcoContext.security.droneMode == "AGGRESSIVE"
		shell.hcoAcquiring = (owner.hcoDetect or 0) > 0
		shell.hcoHeavy = owner.hcoType and owner.hcoType.heavy == true
		shell.hcoWeaponState = owner.hcoWeaponState
		shell.hcoAimTargetX, shell.hcoAimTargetY = owner.hcoAimTargetX, owner.hcoAimTargetY
		shell.hcoLaserPulse, shell.hcoMuzzleFlash = owner.hcoLaserPulse, owner.hcoMuzzleFlash
		shell.hcoHitFlash = owner.hcoHitFlash
		local definition = owner.hcoType or {}
		local offset = owner.hcoCenterOffset or 13
		shell:setPose((owner.x or 0) + offset, (owner.y or 0) + offset, owner.hcoBodyAngle or owner.curViewAngRad or 0, owner.hcoSensorAngle or owner.curViewAngRad or 0, owner.hcoFrame or 1, definition.index or 1, definition.renderScale or 0.34)
	end
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

function airframes.diagnostics()
	local count = 0
	for _, shell in ipairs(live) do if shell and shell.isValid and shell:isValid() then count = count + 1 end end
	return {drawPasses = drawPasses, spriteReady = sprite ~= nil, batchReady = batch ~= nil, airframes = count}
end

return airframes
