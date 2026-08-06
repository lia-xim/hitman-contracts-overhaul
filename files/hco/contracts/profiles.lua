local profiles = {}

profiles.list = {
	{
		id = "executive",
		name = "Executive",
		visualIndex = 1,
		targetVariant = "gideon",
		guardVariants = {"bodyg", "bodyg", "police"},
		drone = {name="Watcher Wing", count=2, speed=0.85, radius=1.2, detect=1.2, armor=1.15},
		bodyguards = 5,
		responseUnits = 10,
		escorts = 15,
		healthMultiplier = 2,
		targetHealthMultiplier = 2.5,
		rewardMultiplier = 1.2,
		evacuationDelay = 30,
		escortLossThreshold = 0.5,
		dropsWeapon = true
	},
	{
		id = "broker",
		name = "Broker",
		visualIndex = 3,
		targetVariant = "bandit4",
		guardVariants = {"bandit2", "bandit3", "motor"},
		drone = {name="Smuggler Wing", count=3, speed=1, radius=0.95, detect=1, armor=1},
		bodyguards = 5,
		responseUnits = 5,
		escorts = 10,
		healthMultiplier = 1.75,
		targetHealthMultiplier = 2,
		rewardMultiplier = 1.1,
		evacuationDelay = 42,
		escortLossThreshold = 0.5,
		dropsWeapon = true
	},
	{
		id = "commander",
		name = "Commander",
		visualIndex = 2,
		targetVariant = "merc",
		guardVariants = {"merc", "merc", "police"},
		drone = {name="Hunter Wing", count=5, speed=1.08, radius=1.05, detect=0.72, armor=1.35},
		bodyguards = 5,
		responseUnits = 20,
		escorts = 25,
		healthMultiplier = 3,
		targetHealthMultiplier = 4,
		rewardMultiplier = 1.4,
		evacuationDelay = 58,
		escortLossThreshold = 0.75,
		dropsWeapon = false
	},
	{
		id = "fixer",
		name = "Fixer",
		visualIndex = 4,
		targetVariant = "bodyg",
		guardVariants = {"bodyg", "merc", "gideon"},
		drone = {name="Interceptor Wing", count=4, speed=1.18, radius=0.9, detect=0.78, armor=1.15},
		bodyguards = 5,
		responseUnits = 15,
		escorts = 20,
		healthMultiplier = 2.5,
		targetHealthMultiplier = 3,
		rewardMultiplier = 1.3,
		evacuationDelay = 48,
		escortLossThreshold = 0.66,
		dropsWeapon = false
	}
}

function profiles.resolve(seed, existingID)
	if existingID == "defector" then
		existingID = "fixer"
	end
	if existingID then
		for _, profile in ipairs(profiles.list) do
			if profile.id == existingID then
				return profile
			end
		end
	end

	return profiles.list[(tonumber(seed) or 0) % #profiles.list + 1]
end

return profiles
