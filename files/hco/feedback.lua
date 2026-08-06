local audio = require("hco/audio")
local feedback = {}

function feedback.show(text)
	if not game or not game.playerActor or not gui or not gui.create then
		return false
	end

	local ok = pcall(function()
		local indicator = gui.create("FadingTextIndicator")

		indicator:setFont("pixellari24")
		indicator:setText(tostring(text))
		indicator:setTargetW(460)
		indicator:setupVisual()
		indicator:addDepth(5010)
		indicator:wrapText()
		indicator:setPos(scrW * 0.5 - indicator.w * 0.5, scrH * 0.5 - _S(230))
		game.addHUDElement(indicator)
	end)

	return ok
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

	if not game or not game.playerActor or not gui or not gui.create then
		return false
	end

	local ok = pcall(function()
		local indicator = gui.create("FadingTextIndicator")
		indicator:setFont("pixellari28")
		indicator:setText(text)
		indicator:setTargetW(540)
		indicator:setupVisual()
		indicator:addDepth(5050)
		indicator:wrapText()
		indicator:setPos(scrW * 0.5 - indicator.w * 0.5, scrH * 0.5 - _S(205))
		game.addHUDElement(indicator)
	end)

	return ok
end

return feedback
