local audio = require("hco/audio")
local feedback = {queue = {}, active = nil, activeTime = 0, delay = 0}

local function killActive()
	local active = feedback.active
	if active and type(active.isValid) == "function" then
		local ok, valid = pcall(active.isValid, active)
		if ok and valid and type(active.kill) == "function" then pcall(active.kill, active) end
	end
	feedback.active = nil
	feedback.activeTime = 0
end

local function createIndicator(entry)
	if not game or not game.playerActor or not gui or not gui.create then return false end
	local ok, indicator = pcall(function()
		local element = gui.create("FadingTextIndicator")
		element:setFont(entry.font or "pixellari24")
		element:setText(entry.text)
		element:setTargetW(entry.width or 560)
		element:setupVisual()
		element:addDepth(entry.depth or 5010)
		element:wrapText()
		-- Native objective announcements occupy the upper/central HUD. HCO uses
		-- the lower third so both remain readable when they begin together.
		element:setPos(scrW * 0.5 - element.w * 0.5, scrH - _S(entry.bottom or 285))
		game.addHUDElement(element)
		return element
	end)
	if not ok or not indicator then return false end
	feedback.active = indicator
	feedback.activeTime = entry.duration or 3.4
	return true
end

local function enqueue(entry)
	for _, queued in ipairs(feedback.queue) do
		if queued.text == entry.text then return true end
	end
	if feedback.active and feedback.active._hcoFeedbackText == entry.text then return true end
	table.insert(feedback.queue, entry)
	feedback.delay = math.max(feedback.delay, 1.25)
	return true
end

function feedback.show(text)
	return enqueue({text = tostring(text), width = 560, duration = 3.4, bottom = 285})
end

function feedback.update(dt)
	dt = tonumber(dt) or 0
	if feedback.active then
		feedback.activeTime = math.max(0, feedback.activeTime - dt)
		if feedback.activeTime > 0 then return end
		killActive()
		feedback.delay = math.max(feedback.delay, 0.45)
	end
	feedback.delay = math.max(0, feedback.delay - dt)
	if feedback.delay > 0 or #feedback.queue == 0 then return end
	local entry = table.remove(feedback.queue, 1)
	if createIndicator(entry) and feedback.active then feedback.active._hcoFeedbackText = entry.text end
end

function feedback.complete(record, amount)
	local archetype = string.upper(tostring(record and record.archetype or "CONTRACT"))
	local condition = record and record.condition
	local bonus = condition and condition.result == true and "\nBONUS CONDITION COMPLETE" or ""
	local text = "CONTRACT COMPLETE — " .. archetype .. "\n+$" .. tostring(amount or 0) .. bonus

	local customChime = audio.playCompletion()
	if sound and type(sound.play) == "function" then
		if not customChime then pcall(sound.play, sound, "stinger_enemies_neutralized") end
		pcall(sound.play, sound, "wep_select_confirm")
	end

	-- Completion is the only pre-emptive banner: discard stale tactical notices
	-- and render it immediately as one lower-third announcement.
	feedback.queue = {}
	feedback.delay = 0
	killActive()
	local entry = {text = text, font = "pixellari28", width = 600, duration = 4.8, bottom = 300, depth = 5050}
	local ok = createIndicator(entry)
	if ok and feedback.active then feedback.active._hcoFeedbackText = text end
	return ok
end

function feedback.reset()
	feedback.queue = {}
	feedback.delay = 0
	killActive()
end

return feedback
