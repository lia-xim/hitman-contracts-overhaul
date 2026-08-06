local english = {}

function english.contractTrackText(profileName, phase)
	if phase == "EVACUATING" then
		return "Contract: " .. tostring(profileName) .. " escaping!"
	end

	return "Contract: eliminate " .. tostring(profileName)
end

function english.contractStartText(profileName, reward, conditionText)
	local text = string.upper(tostring(profileName)) .. " CONTRACT — $" .. tostring(reward)

	if conditionText then
		text = text .. "\n" .. conditionText:gsub("^Optional:%s*", "Bonus: ")
	end

	return text
end


english.DISGUISE_ACQUIRED = "DISGUISE ACQUIRED"
english.DISGUISE_COMPROMISED = "DISGUISE COMPROMISED"
english.TARGET_ESCAPING = "CONTRACT UPDATE: TARGET IS ESCAPING"
english.TARGET_ESCAPED = "CONTRACT FAILED: TARGET ESCAPED"

return english
