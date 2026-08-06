local config = require("hco/config")
local feedback = require("hco/feedback")
local objective = require("hco/contracts/objective")
local persistence = require("hco/contracts/persistence")
local util = require("hco/util")

local intelligence = {}

local function makeAnchor(x, y)
	return {
		x = x,
		y = y,
		getPos = function(self) return self.x, self.y end,
		getPosition = function(self) return self.x, self.y end,
		getCenter = function(self) return self.x, self.y end,
		isValid = function() return true end
	}
end

function intelligence.attach(state)
	if state.contract and state.contract.intelStatus == "revealed" then
		state.intelligence = {status = "revealed", elapsed = 0}
		objective.attachMarker(state)
		return true
	end

	local px, py = util.getPos(game and game.playerActor)
	if not px then
		objective.attachMarker(state)
		return false
	end

	local seed = state.contract and state.contract.seed or 0
	local angle = math.rad(seed % 360)
	local distance = 150 + seed % 90
	local clueX = state.contract.intelX or (px + math.cos(angle) * distance)
	local clueY = state.contract.intelY or (py + math.sin(angle) * distance)
	state.intelligence = {
		status = "clue",
		elapsed = 0,
		anchor = makeAnchor(clueX, clueY)
	}
	state.contract.intelStatus = "clue"
	state.contract.intelX = clueX
	state.contract.intelY = clueY
	persistence.save(state.contract)
	objective.attachIntelMarker(state, state.intelligence.anchor)
	return true
end

function intelligence.reveal(state, reason)
	if not state.intelligence or state.intelligence.status == "revealed" then return end
	state.intelligence.status = "revealed"
	state.contract.intelStatus = "revealed"
	persistence.save(state.contract)
	objective.attachMarker(state)
	objective.updateHUD(state)
	feedback.show("TARGET INTELLIGENCE ACQUIRED — Contract " .. tostring(state.slot or 1) .. " location tracked.")
	util.log(config, "target intelligence revealed slot=" .. tostring(state.slot or 1) .. " reason=" .. tostring(reason))
end

function intelligence.update(state, dt)
	local intel = state.intelligence
	if not intel or intel.status == "revealed" then return end
	intel.elapsed = intel.elapsed + dt
	local player = game and game.playerActor
	if not player then return end

	if util.distance(player, intel.anchor) <= 72 then
		intelligence.reveal(state, "dead-drop-reached")
	elseif intel.elapsed >= 55 then
		-- Never let a generated clue leave a player directionless because its
		-- point happened to fall behind inaccessible geometry.
		intelligence.reveal(state, "field-intel-timeout")
	end
end

function intelligence.detach(state)
	state.intelligence = nil
end

return intelligence
