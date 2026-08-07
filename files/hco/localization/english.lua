local english = {}

function english.contractTrackText(profileName, phase)
	if phase == "EVACUATING" then
		return "Contract: " .. tostring(profileName) .. " escaping!"
	end

	return "Contract: eliminate " .. tostring(profileName)
end

function english.contractStartText(profileName, reward, conditionText, threatLabel)
	local threat = threatLabel and " [" .. tostring(threatLabel) .. "]" or ""
	local text = string.upper(tostring(profileName)) .. " CONTRACT" .. threat .. " — $" .. tostring(reward)

	if conditionText then
		text = text .. "\n" .. conditionText:gsub("^Optional:%s*", "Bonus: ")
	end

	return text
end


local TIER_NAMES = {
	staff = "STAFF",
	regular_security = "SECURITY",
	elite_security = "ELITE SECURITY"
}

function english.disguiseAcquired(tier, switched, keycard, bloodied)
	local heading = switched and "IDENTITY CHANGED" or "IDENTITY ACQUIRED"
	local access = TIER_NAMES[tostring(tier)] or "UNKNOWN ACCESS"
	local credentials = keycard and "\nCREDENTIALS COPIED — BEHAVE NATURALLY" or "\nUNIFORM ONLY — RESTRICTED ACCESS MAY EXPOSE YOU"
	local condition = bloodied and "\nBLOODIED UNIFORM — CLOSE INSPECTION RISK" or ""

	return heading .. " — " .. access .. credentials .. condition
end

function english.disguiseInteraction(active)
	return active and "Switch identity / search body" or "Take disguise / search body"
end

function english.disguiseRestored(tier, compromised)
	if compromised then return english.DISGUISE_COMPROMISED end
	return "IDENTITY RESTORED — " .. (TIER_NAMES[tostring(tier)] or "UNKNOWN ACCESS")
end

english.DISGUISE_ACQUIRED = "IDENTITY ACQUIRED"
english.DISGUISE_COMPROMISED = "DISGUISE COMPROMISED"
english.DISGUISE_BODY_AVAILABLE = "IDENTITY AVAILABLE — OPEN BODY INTERACTIONS"
english.DISGUISE_IDENTITY_CHECK = "IDENTITY CHECK — MOVE AWAY OR DISRUPT THE RADIO"
english.DISGUISE_LOCALLY_EXPOSED = "COVER BLOWN — BREAK CONTACT"
english.DISGUISE_VISUAL_FAILED = "IDENTITY FAILED — UNIFORM IS NOT PLAYER-COMPATIBLE"
english.DISGUISE_UNAVAILABLE = "IDENTITY UNAVAILABLE"
english.TARGET_ESCAPING = "CONTRACT UPDATE: TARGET IS ESCAPING"
english.TARGET_ESCAPED = "CONTRACT FAILED: TARGET ESCAPED"

return english
