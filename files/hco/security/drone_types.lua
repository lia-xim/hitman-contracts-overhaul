local util = require("hco/util")

local droneTypes = {}

local definitions = {
	{
		id = "scout", index = 1, label = "Scout", family = "scout", weight = {patrol=64, aggressive=20},
		speed = 1.42, scanRadius = 1.18, detect = 0.78, armor = 1, renderScale = 0.32,
		turnRate = 4.8, sensorTurnRate = 6.5, gimbal = 58, preferredRange = 250, fov = 64
	},
	{
		id = "pistol_light", index = 2, label = "Light Pistol", family = "pistol", weight = {patrol=22, aggressive=18},
		speed = 1.24, scanRadius = 1.02, detect = 0.9, armor = 1, renderScale = 0.35,
		turnRate = 4.2, sensorTurnRate = 5.7, gimbal = 48, preferredRange = 300, fov = 52,
		weapon = {kind="ballistic", weaponID="p320", damage=7, burst=1, shotInterval=0.1, cooldown=1.2, range=510, aimTolerance=8, spread=2.2}
	},
	{
		id = "pistol_heavy", index = 3, label = "Heavy Pistol", family = "pistol", heavy = true, weight = {patrol=0, aggressive=11},
		speed = 0.82, scanRadius = 1.05, detect = 0.82, armor = 3, renderScale = 0.39,
		turnRate = 2.7, sensorTurnRate = 4.1, gimbal = 34, preferredRange = 340, fov = 48,
		weapon = {kind="ballistic", weaponID="p320", damage=11, burst=2, shotInterval=0.18, cooldown=1.65, range=560, aimTolerance=6, spread=1.2}
	},
	{
		id = "smg_light", index = 4, label = "Light SMG", family = "smg", weight = {patrol=10, aggressive=19},
		speed = 1.18, scanRadius = 0.96, detect = 0.84, armor = 1, renderScale = 0.35,
		turnRate = 4.0, sensorTurnRate = 5.4, gimbal = 44, preferredRange = 330, fov = 50,
		weapon = {kind="ballistic", weaponID="mp5", damage=4, burst=3, shotInterval=0.1, cooldown=1.45, range=520, aimTolerance=10, spread=3.4}
	},
	{
		id = "smg_heavy", index = 5, label = "Heavy SMG", family = "smg", heavy = true, weight = {patrol=0, aggressive=15},
		speed = 0.76, scanRadius = 1.0, detect = 0.76, armor = 4, renderScale = 0.39,
		turnRate = 2.5, sensorTurnRate = 3.8, gimbal = 30, preferredRange = 370, fov = 46,
		weapon = {kind="ballistic", weaponID="mp5", damage=5, burst=6, shotInterval=0.085, cooldown=2.1, range=580, aimTolerance=8, spread=2.6}
	},
	{
		id = "laser_light", index = 6, label = "Light Laser", family = "laser", weight = {patrol=4, aggressive=11},
		speed = 1.12, scanRadius = 1.04, detect = 0.82, armor = 1, renderScale = 0.35,
		turnRate = 3.8, sensorTurnRate = 5.2, gimbal = 46, preferredRange = 380, fov = 48,
		weapon = {kind="laser", weaponID="disruptor", damage=18, charge=0.9, cooldown=2.8, range=610, aimTolerance=6}
	},
	{
		id = "laser_heavy", index = 7, label = "Heavy Laser", family = "laser", heavy = true, weight = {patrol=0, aggressive=6},
		speed = 0.7, scanRadius = 1.08, detect = 0.72, armor = 4, renderScale = 0.39,
		turnRate = 2.25, sensorTurnRate = 3.5, gimbal = 28, preferredRange = 430, fov = 44,
		weapon = {kind="laser", weaponID="disruptor", damage=38, charge=1.4, cooldown=4.2, range=680, aimTolerance=4.5}
	}
}

local byID = {}
for _, definition in ipairs(definitions) do byID[definition.id] = definition end

local doctrineBias = {
	executive = {laser=1.65, pistol=0.85, smg=0.75},
	broker = {pistol=1.7, smg=1.2, laser=0.55},
	commander = {smg=1.85, pistol=0.7, laser=0.95},
	fixer = {laser=1.55, pistol=1.15, smg=0.85}
}

local doctrineSignature = {
	executive = "laser_light",
	broker = "pistol_light",
	commander = "smg_heavy",
	fixer = "laser_heavy"
}

local function selectionSeed(context, index, aggressive)
	local contract = context and context.contract or {}
	local generation = context and context.security and context.security.droneGeneration or 0
	return util.stableHash(tostring(contract.seed or context and context.slot or 0) .. ":" .. tostring(index) .. ":" .. tostring(generation) .. ":" .. (aggressive and "A" or "P"))
end

function droneTypes.get(idOrIndex)
	if type(idOrIndex) == "number" then return definitions[idOrIndex] end
	return byID[idOrIndex]
end

function droneTypes.all()
	return definitions
end

function droneTypes.select(context, index, aggressive)
	-- Every protection detail starts with a readable, information-first scout.
	if index == 1 and not aggressive then return definitions[1] end
	local profileID = context and context.contract and context.contract.archetype
	local security = context and context.security
	local used = {}
	for _, drone in ipairs(security and security.drones or {}) do
		if drone and not drone.broken and drone.hcoType then used[drone.hcoType.id] = true end
	end
	if aggressive and security and index == security.droneWaveFirstIndex and doctrineSignature[profileID] then
		local signature = byID[doctrineSignature[profileID]]
		if signature and not used[signature.id] then return signature end
	end
	local bias = doctrineBias[profileID] or {}
	local mode = aggressive and "aggressive" or "patrol"
	local total, weighted = 0, {}
	for _, definition in ipairs(definitions) do
		local weight = (definition.weight and definition.weight[mode] or 0) * (bias[definition.family] or 1)
		if weight > 0 then
			total = total + weight
			table.insert(weighted, {definition=definition, ceiling=total})
		end
	end
	if total <= 0 then return definitions[1] end
	local roll = (selectionSeed(context, index, aggressive) % 100000) / 100000 * total
	local selectedIndex = #weighted
	for weightedIndex, entry in ipairs(weighted) do if roll < entry.ceiling then selectedIndex = weightedIndex break end end
	for offset = 0, #weighted - 1 do
		local candidate = weighted[(selectedIndex + offset - 1) % #weighted + 1].definition
		if not used[candidate.id] then return candidate end
	end
	return weighted[selectedIndex].definition
end

return droneTypes
