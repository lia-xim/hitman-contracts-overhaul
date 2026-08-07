local util = require("hco/util")
local audio = require("hco/audio")

local droneWeapons = {}

local function centerOffset(drone)
	return drone and drone.hcoCenterOffset or 13
end

local function sourceActor(drone)
	-- Native bullets need an actor-shaped attribution owner, but the weapon does
	-- not cease to exist when that guard is later killed. Preserve the first valid
	-- proxy for the drone's lifetime; corpses remain valid world actors and are a
	-- safer attribution source than silently disabling an intact drone mid-fight.
	if util.isValid(drone.hcoWeaponSource) then return drone.hcoWeaponSource end
	local context = drone.hcoContext
	local root = context and context.root
	local contexts = root and type(root.contracts) == "table" and #root.contracts > 0 and root.contracts or {context}
	for _, networkContext in ipairs(contexts) do
		for _, guard in ipairs(networkContext and networkContext.security and networkContext.security.guards or {}) do
			if guard.role ~= "close_protection" and util.isAlive(guard.actor) then
				drone.hcoWeaponSource = guard.actor
				return guard.actor
			end
		end
		if networkContext and util.isAlive(networkContext.target) then
			drone.hcoWeaponSource = networkContext.target
			return networkContext.target
		end
	end
	return nil
end

local function distanceToPlayer(drone, player)
	local px, py = util.getPos(player)
	if not px then return math.huge end
	local offset = centerOffset(drone)
	local dx, dy = px - ((drone.x or 0) + offset), py - ((drone.y or 0) + offset)
	return math.sqrt(dx * dx + dy * dy)
end

local function ensureNativeWeapon(drone, weaponConfig)
	if drone.broken or drone.hcoWeaponDisabled then return nil end
	if drone.hcoNativeWeapon then return drone.hcoNativeWeapon end
	if not weapons or type(weapons.instantiate) ~= "function" then return nil end
	local source = sourceActor(drone)
	if not source then return nil end
	local ok, weapon = pcall(weapons.instantiate, weapons, weaponConfig.weaponID)
	if not ok or not weapon then return nil end
	weapon.owner = source
	weapon.damage = weaponConfig.damage
	weapon.damageMin = weaponConfig.damage
	drone.hcoNativeWeapon = weapon
	return weapon
end

local function playWorldSound(soundID, parent, x, y, volume, pitch)
	if not soundID or not sound or type(sound.playWorld) ~= "function" then return end
	pcall(sound.playWorld, sound, soundID, parent, x, y, volume or 0.65, pitch or 1)
end

local function fireBallistic(drone, player, weaponConfig)
	if drone.broken or drone.hcoWeaponDisabled then return false end
	local weapon = ensureNativeWeapon(drone, weaponConfig)
	if not weapon or type(weapon.createBullet) ~= "function" then return false end
	local source = sourceActor(drone)
	if not source then return false end
	weapon.owner = source
	local px, py = util.getPos(player)
	local offset = centerOffset(drone)
	local x, y = (drone.x or 0) + offset, (drone.y or 0) + offset
	local angle = math.deg(math.atan2(py - y, px - x))
	drone.hcoShotCounter = (drone.hcoShotCounter or 0) + 1
	local spreadWave = math.sin(drone.hcoShotCounter * 4.17 + (drone.hcoIndex or 1))
	angle = angle + spreadWave * (weaponConfig.spread or 0)
	local muzzleX, muzzleY = x + math.cos(math.rad(angle)) * 14, y + math.sin(math.rad(angle)) * 14
	local okHeight, bulletHeight = util.call(player, "getWeaponBulletHeight")
	if not okHeight or not tonumber(bulletHeight) then
		okHeight, bulletHeight = util.call(player, "getMidZ")
	end
	bulletHeight = tonumber(bulletHeight) or 90
	local okSpeed, bulletSpeed = util.call(weapon, "getBulletSpeed")
	bulletSpeed = okSpeed and tonumber(bulletSpeed) or 1000
	local ok = pcall(weapon.createBullet, weapon, muzzleX, muzzleY, angle, bulletHeight, 0, bulletSpeed, 0)
	if not ok then return false end
	local okSound, fireSound = util.call(weapon, "getFireSound", 1)
	if okSound then playWorldSound(fireSound, source, muzzleX, muzzleY, 0.62, 1.08) end
	drone.hcoMuzzleFlash = 0.09
	return true
end

local function fireLaser(drone, player, weaponConfig)
	if drone.broken or drone.hcoWeaponDisabled then return false end
	local source = sourceActor(drone)
	if not source then return false end
	local inflictor = ensureNativeWeapon(drone, weaponConfig)
	if not inflictor then
		local okWeapon, actorWeapon = util.call(source, "getWeapon")
		if okWeapon then inflictor = actorWeapon end
	end
	if not inflictor then return false end
	local ok = util.call(player, "takeDamage", weaponConfig.damage, 1, source, inflictor)
	if not ok then return false end
	local offset = centerOffset(drone)
	local x, y = (drone.x or 0) + offset, (drone.y or 0) + offset
	if not audio.playDroneLaser(drone, drone.hcoType and drone.hcoType.heavy == true) then
		playWorldSound("disruptor_bag_fire", source, x, y, weaponConfig.damage >= 30 and 0.9 or 0.65, weaponConfig.damage >= 30 and 0.72 or 1.0)
	end
	drone.hcoLaserPulse = 0.16
	return true
end

function droneWeapons.update(drone, player, visible, aimError, dt, canAttack)
	if drone.broken or drone.hcoWeaponDisabled then
		drone.hcoBurstLeft, drone.hcoBurstWait = 0, 0
		drone.hcoLaserCharge, drone.hcoMuzzleFlash, drone.hcoLaserPulse = 0, 0, 0
		drone.hcoAimTargetX, drone.hcoAimTargetY = nil, nil
		drone.hcoWeaponState = "DESTROYED"
		return false
	end
	local weaponConfig = drone.hcoType and drone.hcoType.weapon
	drone.hcoWeaponChargeMax = weaponConfig and weaponConfig.kind == "laser" and weaponConfig.charge or nil
	drone.hcoWeaponCooldown = math.max(0, (drone.hcoWeaponCooldown or 0) - dt)
	drone.hcoMuzzleFlash = math.max(0, (drone.hcoMuzzleFlash or 0) - dt)
	drone.hcoLaserPulse = math.max(0, (drone.hcoLaserPulse or 0) - dt)
	drone.hcoAimTargetX, drone.hcoAimTargetY = nil, nil
	if not weaponConfig or not player or not util.isAlive(player) or not canAttack then
		drone.hcoLaserCharge = 0
		drone.hcoWeaponState = "IDLE"
		return false
	end
	local px, py = util.getPos(player)
	local inRange = distanceToPlayer(drone, player) <= (weaponConfig.range or 520)
	local onAim = aimError <= math.rad(weaponConfig.aimTolerance or 8)
	if visible and inRange then drone.hcoAimTargetX, drone.hcoAimTargetY = px, py end

	if weaponConfig.kind == "laser" then
		if visible and inRange and onAim and drone.hcoWeaponCooldown <= 0 then
			drone.hcoWeaponState = "CHARGING"
			drone.hcoLaserCharge = math.min(weaponConfig.charge, (drone.hcoLaserCharge or 0) + dt)
			if drone.hcoLaserCharge >= weaponConfig.charge then
				local fired = fireLaser(drone, player, weaponConfig)
				drone.hcoLaserCharge = 0
				drone.hcoWeaponCooldown = weaponConfig.cooldown
				drone.hcoWeaponState = fired and "FIRED" or "IDLE"
				return fired
			end
		else
			drone.hcoLaserCharge = math.max(0, (drone.hcoLaserCharge or 0) - dt * 2.5)
			drone.hcoWeaponState = drone.hcoLaserCharge > 0 and "CHARGING" or "IDLE"
		end
		return false
	end

	if (drone.hcoBurstLeft or 0) > 0 then
		drone.hcoBurstWait = (drone.hcoBurstWait or 0) - dt
		if drone.hcoBurstWait <= 0 and visible and inRange and onAim then
			local fired = fireBallistic(drone, player, weaponConfig)
			drone.hcoBurstLeft = drone.hcoBurstLeft - 1
			drone.hcoBurstWait = weaponConfig.shotInterval
			drone.hcoWeaponState = fired and "FIRING" or "IDLE"
			if drone.hcoBurstLeft <= 0 then drone.hcoWeaponCooldown = weaponConfig.cooldown end
			return fired
		elseif not visible then
			drone.hcoBurstLeft = 0
		end
	elseif visible and inRange and onAim and drone.hcoWeaponCooldown <= 0 then
		drone.hcoBurstLeft = weaponConfig.burst or 1
		drone.hcoBurstWait = 0
		drone.hcoWeaponState = "AIMING"
	end
	return false
end

function droneWeapons.disable(drone)
	if not drone then return end
	drone.hcoWeaponDisabled = true
	drone.hcoBurstLeft, drone.hcoBurstWait = 0, 0
	drone.hcoLaserCharge, drone.hcoMuzzleFlash, drone.hcoLaserPulse = 0, 0, 0
	drone.hcoAimTargetX, drone.hcoAimTargetY = nil, nil
	drone.hcoWeaponCooldown = math.huge
	drone.hcoWeaponState = "DESTROYED"
	if drone and drone.hcoNativeWeapon and type(drone.hcoNativeWeapon.remove) == "function" then
		pcall(drone.hcoNativeWeapon.remove, drone.hcoNativeWeapon)
	end
	if drone then drone.hcoNativeWeapon = nil end
	if drone then drone.hcoWeaponSource = nil end
end

function droneWeapons.remove(drone)
	droneWeapons.disable(drone)
end

return droneWeapons
