local util = require("hco/util")

local balance = {}

local presets = {
	easy_real = {label="Easy", response=0.75, guardHealth=0.82, targetHealth=0.86, drones=0.8, detection=1.28, sensorRange=0.9, reward=0.9, threat=-1},
	easy = {label="Normal", response=1, guardHealth=1, targetHealth=1, drones=1, detection=1, sensorRange=1, reward=1, threat=0},
	normal = {label="Hard", response=1.08, guardHealth=1.08, targetHealth=1.08, drones=1.08, detection=0.9, sensorRange=1.06, reward=1.1, threat=0},
	["true"] = {label="True", response=1.15, guardHealth=1.12, targetHealth=1.12, drones=1.14, detection=0.82, sensorRange=1.12, reward=1.18, threat=1},
	throwback = {label="Throwback", response=1, guardHealth=0.9, targetHealth=0.92, drones=1, detection=1.08, sensorRange=1, reward=1, threat=0}
}

local roman = {"I", "II", "III", "IV", "V"}

local function difficultyData()
	local difficulty = game and game.difficulty
	if not difficulty then return "unknown", nil end
	local id = difficulty.id
	if type(difficulty.getID) == "function" then
		local ok, value = pcall(difficulty.getID, difficulty)
		if ok and value then id = value end
	end
	return tostring(id or "unknown"), difficulty
end

local function customPreset(difficulty)
	local vision = util.clamp(tonumber(difficulty and difficulty.enemyVisRangeMult) or 1, 0.65, 1.5)
	local incomingDamage = util.clamp(tonumber(difficulty and difficulty.playerDamageMult) or 1, 0.5, 2)
	local intensity = util.clamp((vision * 0.65 + incomingDamage * 0.35), 0.7, 1.45)
	return {
		label = "Custom",
		response = util.clamp(0.82 + (intensity - 0.7) * 0.42, 0.82, 1.14),
		guardHealth = util.clamp(0.88 + (incomingDamage - 0.5) * 0.16, 0.88, 1.12),
		targetHealth = util.clamp(0.9 + (incomingDamage - 0.5) * 0.15, 0.9, 1.13),
		drones = util.clamp(0.86 + (intensity - 0.7) * 0.38, 0.86, 1.14),
		detection = util.clamp(1 / vision, 0.78, 1.3),
		sensorRange = vision,
		reward = util.clamp(0.9 + (intensity - 0.7) * 0.32, 0.9, 1.14),
		threat = intensity >= 1.22 and 1 or intensity <= 0.82 and -1 or 0
	}
end

function balance.snapshot(profile)
	local difficultyID, difficulty = difficultyData()
	local source = presets[difficultyID] or (difficultyID == "custom" and customPreset(difficulty)) or presets.easy
	local baseThreat = tonumber(profile and profile.threatRating) or 3
	local threat = util.clamp(math.floor(baseThreat + (source.threat or 0) + 0.5), 1, 5)
	return {
		difficultyID = difficultyID,
		difficultyLabel = source.label,
		responseScale = source.response,
		guardHealthScale = source.guardHealth,
		targetHealthScale = source.targetHealth,
		droneCountScale = source.drones,
		detectionTimeScale = source.detection,
		sensorRangeScale = source.sensorRange,
		rewardScale = source.reward,
		threatRating = threat,
		threatLabel = roman[threat]
	}
end

function balance.scaledCount(value, scale, minimum)
	value = math.max(0, tonumber(value) or 0)
	if value <= 0 then return 0 end
	return math.max(minimum or 1, math.floor(value * (tonumber(scale) or 1) + 0.5))
end

return balance
