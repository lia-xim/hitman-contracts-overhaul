local config = require("hco/config")
local util = require("hco/util")

local visuals = {}
local sheet, quads

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
	if state.hooks.hcoFactionPostDraw then return true end
	local goonClass = actor.getClassData and actor.getClassData("goon")
	if not goonClass or type(goonClass.postDraw) ~= "function" then return false end
	loadSheet()
	local original = goonClass.postDraw
	state.hooks.hcoFactionPostDraw = original

	function goonClass:postDraw(...)
		original(self, ...)
		local index = self._hcoFactionVisual
		if not index or not sheet or not quads or self._visible == false then return end
		local x, y = self:getDrawPosition()
		local size = self._hcoContractTarget and 17 or 12
		local scale = size / 64
		love.graphics.setColor(255, 255, 255, self._hcoContractTarget and 235 or 190)
		love.graphics.draw(sheet, quads[index], x, y - (self._hcoContractTarget and 3 or 1), self:getAngle(), scale, scale, 32, 32)
		love.graphics.setColor(255, 255, 255, 255)
	end

	util.log(config, "native faction visuals ready")
	return true
end

return visuals
