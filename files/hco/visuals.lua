local config = require("hco/config")
local util = require("hco/util")

local visuals = {}
local sheet, quads

local function drawInsignia(object, index, size, alpha, yOffset)
	if not index or not sheet or not quads or not quads[index] or object._visible == false then return end
	local okPos, x, y = util.call(object, "getDrawPosition")
	if not okPos then x, y = util.getPos(object) end
	if not x then return end
	local _, angle = util.call(object, "getAngle")
	local scale = size / 64
	love.graphics.setColor(255, 255, 255, alpha)
	love.graphics.draw(sheet, quads[index], x, y - yOffset, angle or 0, scale, scale, 32, 32)
	love.graphics.setColor(255, 255, 255, 255)
end

local function loadSheet()
	if sheet or not love or not love.graphics then return end
	local candidates = {
		"mods/Hitman-Contracts-Overhaul/files/assets/hco/faction-insignia-sheet.png",
		"mods/Hitman-Contracts-Overhaul/assets/hco/faction-insignia-sheet.png",
		"assets/hco/faction-insignia-sheet.png"
	}
	for _, path in ipairs(candidates) do
		local ok, image = pcall(love.graphics.newImage, path)
		if ok and image then
			sheet = image
			image:setFilter("nearest", "nearest")
			quads = {}
			for index = 0, 3 do quads[index + 1] = love.graphics.newQuad(index * 64, 0, 64, 64, 256, 64) end
			return
		end
	end
end

function visuals.initialize(state)
	state.hooks = state.hooks or {}
	local goonClass = actor.getClassData and actor.getClassData("goon")
	if not goonClass or type(goonClass.postDraw) ~= "function" then return false end
	loadSheet()
	if not state.hooks.hcoFactionPostDraw then
		local original = goonClass.postDraw
		state.hooks.hcoFactionPostDraw = original

		function goonClass:postDraw(...)
			original(self, ...)
			local index = self._hcoFactionVisual
			local size = self._hcoContractTarget and 17 or 12
			drawInsignia(self, index, size, self._hcoContractTarget and 235 or 190, self._hcoContractTarget and 3 or 1)
		end
	end

	if not state.hooks.hcoFactionPlayerPostDraw and playerActor and type(playerActor.postDraw) == "function" then
		local original = playerActor.postDraw
		state.hooks.hcoFactionPlayerPostDraw = original

		function playerActor:postDraw(...)
			local result = original(self, ...)
			if game and self == game.playerActor then
				drawInsignia(self, self._hcoDisguiseFactionVisual, 11, 205, 1)
			end
			return result
		end
	end

	util.log(config, "native faction visuals ready")
	return true
end

return visuals
