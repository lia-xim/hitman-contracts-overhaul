local config = require("hco/config")
local util = require("hco/util")

local identityFX = {}

local COLORS = {
	acquired = {72, 224, 224},
	restored = {90, 205, 176},
	checking = {255, 183, 58},
	exposed = {255, 92, 48},
	compromised = {245, 62, 67}
}

local DURATIONS = {
	acquired = 0.95,
	restored = 0.65,
	checking = 2.6,
	exposed = 0.9,
	compromised = 1.25
}

local function playNativeCue(kind)
	if not sound or type(sound.play) ~= "function" then return end

	if kind == "acquired" then
		pcall(sound.play, sound, "weapon_pickup", game and game.playerActor)
	elseif kind == "restored" then
		pcall(sound.play, sound, "wep_select_confirm")
	elseif kind == "compromised" or kind == "exposed" then
		pcall(sound.play, sound, "invalid_use")
	end
	-- An identity check already opens the NPC's real radio. A second synthetic
	-- cue would obscure the disruptible native sound and is intentionally omitted.
end

function identityFX.trigger(state, kind, duration)
	if not state or not COLORS[kind] then return false end
	state.identityFX = {
		kind = kind,
		time = 0,
		duration = tonumber(duration) or DURATIONS[kind]
	}
	playNativeCue(kind)
	return true
end

function identityFX.update(state, dt)
	local active = state and state.identityFX
	if not active then return end
	active.time = active.time + (tonumber(dt) or 0)
	if active.time >= active.duration then state.identityFX = nil end
end

function identityFX.clear(state)
	if state then state.identityFX = nil end
end

local function segmentCircle(x, y, radius, startAngle, length, segments)
	local previousX, previousY
	for index = 0, segments do
		local angle = startAngle + length * index / segments
		local px = x + math.cos(angle) * radius
		local py = y + math.sin(angle) * radius
		if previousX then love.graphics.line(previousX, previousY, px, py) end
		previousX, previousY = px, py
	end
end

local function drawBrackets(x, y, radius, alpha, broken)
	local size = broken and 7 or 6
	for index = 0, 3 do
		if not broken or index ~= 1 then
			local sx = (index == 0 or index == 3) and -1 or 1
			local sy = index < 2 and -1 or 1
			local bx, by = x + sx * radius, y + sy * radius
			love.graphics.line(bx, by, bx - sx * size, by)
			love.graphics.line(bx, by, bx, by - sy * size)
		end
	end
end

local function drawPixels(active, x, y, radius, alpha)
	local seed = active.kind == "compromised" and 13 or active.kind == "checking" and 7 or 3
	for index = 1, 8 do
		local angle = seed + index * 2.399 + active.time * (index % 2 == 0 and 3.2 or -2.4)
		local travel = radius + (index % 3) * 3
		local px = math.floor(x + math.cos(angle) * travel)
		local py = math.floor(y + math.sin(angle) * travel)
		local size = index % 3 == 0 and 2 or 1
		love.graphics.rectangle("fill", px, py, size, size)
	end
end

local function drawEffect(state, player)
	local active = state.identityFX
	if not active or not love or not love.graphics then return end
	local x, y = util.getPos(player)
	if not x then return end

	local progress = math.min(1, active.time / math.max(0.01, active.duration))
	local color = COLORS[active.kind]
	local alpha = math.floor(220 * (1 - progress))
	local locallyExposed = active.kind == "exposed"
	local brokenIdentity = active.kind == "compromised" or locallyExposed
	local radius = 14 + progress * (brokenIdentity and 22 or 15)
	local oldWidth = love.graphics.getLineWidth and love.graphics.getLineWidth() or 1
	love.graphics.setColor(color[1], color[2], color[3], alpha)
	love.graphics.setLineWidth(active.kind == "checking" and 2 or 1)

	if active.kind == "checking" then
		local sweep = math.max(0.18, progress) * math.pi * 2
		segmentCircle(x, y, radius, -math.pi * 0.5, sweep, 18)
		segmentCircle(x, y, radius + 4, math.pi * 0.5, math.pi * 0.55, 6)
		drawBrackets(x, y, radius + 5, alpha, false)
	elseif brokenIdentity then
		segmentCircle(x, y, radius, 0.2, math.pi * 0.7, 7)
		segmentCircle(x, y, radius, math.pi * 1.15, math.pi * 0.58, 6)
		drawBrackets(x, y, radius + 4, alpha, true)
		if active.kind == "compromised" then
			love.graphics.line(x - 7 - progress * 5, y - 7, x + 7 + progress * 5, y + 7)
			love.graphics.line(x + 7 + progress * 5, y - 7, x - 7 - progress * 5, y + 7)
		else
			love.graphics.line(x - radius, y, x + radius, y)
		end
	else
		segmentCircle(x, y, radius, -math.pi * 0.5, math.pi * 1.55, 15)
		drawBrackets(x, y, radius + 3, alpha, false)
	end

	drawPixels(active, x, y, radius, alpha)
	love.graphics.setLineWidth(oldWidth)
	love.graphics.setColor(255, 255, 255, 255)
end

function identityFX.initialize(state)
	state.hooks = state.hooks or {}
	if state.hooks.hcoIdentityPostDraw then return true end
	if not playerActor or type(playerActor.postDraw) ~= "function" then
		util.log(config, "identity transition effects unavailable; visible uniform variants remain active")
		return false
	end

	local original = playerActor.postDraw
	state.hooks.hcoIdentityPostDraw = original

	function playerActor:postDraw(...)
		local result = original(self, ...)
		if game and self == game.playerActor then drawEffect(state, self) end
		return result
	end

	return true
end

return identityFX
