local config = require("hco/config")
local util = require("hco/util")

local airframes = {}
local CLASS_ID = "hco_drone_airframe"
local BATCH_ID = "hco_drone_airframes"
local BATCH_DEPTH = 68
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
		self.x, self.y = x, y
		self.hcoAngle = angle or self.hcoAngle
		self.hcoFrame = frame or self.hcoFrame
		if self._placed and self.renderTree then self.renderTree:insert(self) end
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
		if ensureSlot(self) and sprite and quads then
			batch:setColor(255, 255, 255, 255)
			batch:updateSprite(self.hcoSlot, quads[self.hcoFrame or 1], self.x, self.y, self.hcoAngle or 0, 0.68, 0.68, 48, 48)
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
	shell:setPose(x, y, owner and owner.curViewAngRad or 0, 1)
	local placed, placeError = pcall(shell.onPlacedIntoMap, shell)
	if not placed then return nil, "airframe-placement-failed: " .. tostring(placeError) end
	table.insert(live, shell)
	return shell
end

function airframes.sync(shell, owner)
	if shell and shell.isValid and shell:isValid() and owner then
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
