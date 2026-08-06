local config = require("hco/config")
local util = require("hco/util")

local airframes = {}
local CLASS_ID = "hco_drone_airframe"
local BATCH_ID = "hco_drone_airframes"
local BATCH_DEPTH = 68
local AIRFRAME_SCALE = 0.28
local SPRITE_FORWARD_OFFSET = -math.pi * 0.5
local classData
local sprite, quads, batch
local live = {}
local drawPasses = 0

local function loadSprite()
	if sprite or not love or not love.graphics then return sprite ~= nil end
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
	local ok, container = pcall(spriteBatchController.newSpriteBatch, spriteBatchController, BATCH_ID, sprite, 16, "stream", BATCH_DEPTH, false, true, false, true)
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
		self.hcoAngle = 0
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

	function visual:setPose(x, y, angle, frame)
		local dx, dy = x - (self.x or x), y - (self.y or y)
		self.hcoMoveX = self.hcoMoveX * 0.72 + dx * 0.28
		self.hcoMoveY = self.hcoMoveY * 0.72 + dy * 0.28
		self.x, self.y = x, y
		self.hcoAngle = angle or self.hcoAngle
		self.hcoFrame = frame or self.hcoFrame
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

		graphics.push()
		graphics.translate(drawX, drawY)
		graphics.rotate(renderAngle)
		graphics.setLineWidth(1)
		local rotorPulse = 3.2 + math.abs(math.sin(time * 18 + self.hcoPhase)) * 1.4
		local rotorAlpha = self.hcoDisrupted and 65 or 125
		graphics.setColor(125, 225, 245, rotorAlpha)
		for _, rotor in ipairs({{-9,-7},{9,-7},{-9,7},{9,7}}) do graphics.circle("line", rotor[1], rotor[2], rotorPulse) end
		local sensorPulse = 1.8 + math.abs(math.sin(time * 7 + self.hcoPhase)) * 1.2
		if self.hcoDisrupted then
			graphics.setColor(90, 150, 255, 170)
		elseif self.hcoAggressive or self.hcoAcquiring then
			graphics.setColor(255, 70, 55, 230)
		else
			graphics.setColor(65, 245, 255, 220)
		end
		graphics.circle("fill", 0, 9, sensorPulse)
		graphics.pop()
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
		local renderAngle = (self.hcoAngle or 0) + SPRITE_FORWARD_OFFSET
		drawFlightEffects(self, drawX, drawY, renderAngle)
		if ensureSlot(self) and sprite and quads then
			local alpha = self.hcoDisrupted and (110 + math.floor(math.abs(math.sin((curTime or 0) * 17)) * 100)) or 255
			batch:setColor(255, 255, 255, alpha)
			batch:updateSprite(self.hcoSlot, quads[self.hcoFrame or 1], drawX, drawY, renderAngle, AIRFRAME_SCALE, AIRFRAME_SCALE, 48, 48)
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
	shell:setPose(x, y, owner and owner.curViewAngRad or 0, 1)
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
		shell:setPose((owner.x or 0) + 13, (owner.y or 0) + 13, owner.curViewAngRad or 0, owner.hcoFrame or 1)
	end
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
