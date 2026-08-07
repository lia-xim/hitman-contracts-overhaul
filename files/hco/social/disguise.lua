local config = require("hco/config")
local english = require("hco/localization/english")
local feedback = require("hco/feedback")
local identityFX = require("hco/social/identity_fx")
local persistence = require("hco/contracts/persistence")
local securityDirector = require("hco/security/director")
local stateModule = require("hco/state")
local util = require("hco/util")

local disguise = {}

-- These helpers are assigned below after their dependencies are declared. They
-- are forward-declared because an identity takeover must immediately rebind
-- native observer knowledge and patch already-instantiated AI states.
local markLocalCompromise
local queueRadioCompromise
local hasCurrentVisualContact
local ensureNPCSightHooks
local ensureRuntimeBindings

local SUSPICIOUS_PLAYER_STATES = {
	player_lockpicking = true,
	player_lockpicking_enter = true,
	player_lockpicking_leave = true,
	player_breaking_lock = true,
	player_closet_bashing = true,
	player_carrying_body = true,
	player_grabbing_body = true,
	player_choking_enemy = true,
	player_killing_enemy = true,
	player_finish_off = true,
	player_finishing_enemy_off = true,
	player_bashing_door = true,
	player_kicking = true,
	player_kicking_object = true,
	player_throwing_weapon = true,
	player_throwing_item = true,
	player_post_throw_cooldown = true,
	player_taking_item_throwing = true
}

local INTERACTION_SENTINEL = "hco_take_disguise_v1"
local RESTORE_INTERACTION_SENTINEL = "hco_restore_identity_v1"
local GOON_HOOK_KEYS = {
	"reset", "increaseDetection", "setEnemyInSight", "getStateObject", "setState",
	"getInteractOptions", "hcoDisguiseBodyPostDraw", "hcoDisguiseDie", "hcoDisguiseChoke", "setSeenBody", "makeFallen", "onBodyDropped"
}

local function getPlayerStateID(player)
	local ok, stateObject = util.call(player, "getState")

	return ok and stateObject and (stateObject.id or stateObject.ID) or nil
end

local function getWeaponIdentity(weapon)
	if not weapon then
		return nil, nil
	end

	local _, weaponType = util.call(weapon, "getType")

	return weaponType, util.getID(weapon)
end

local function cacheBodyIdentity(body)
	if not body or body._hcoDisguiseIdentity then
		return body and body._hcoDisguiseIdentity or nil
	end

	local _, experience = util.call(body, "getExperienceLevel")
	local _, weapon = util.call(body, "getWeapon")
	local _, keycard = util.call(body, "getKeycard")
	local _, keychain = util.call(body, "getKeychain")
	local _, group = util.call(body, "getAnimVariant")
	local _, radio = util.call(body, "getRadio")
	local _, blood = util.call(body, "getBlood")
	local weaponType, weaponID = getWeaponIdentity(weapon)

	body._hcoDisguiseIdentity = {
		experience = body._hcoOriginalExperience or experience,
		weaponType = weaponType,
		weaponID = weaponID,
		keycard = keycard,
		keychain = keychain,
		group = group and tostring(group) or nil,
		armed = weapon ~= nil or body.startingWeapon ~= nil or body._hcoEscort == true,
		hadRadio = radio ~= nil,
		bloodied = tonumber(blood) ~= nil and tonumber(blood) < 30 or false
	}

	return body._hcoDisguiseIdentity
end

local function classifyBody(body)
	local identity = cacheBodyIdentity(body) or {}
	local _, currentExperience = util.call(body, "getExperienceLevel")
	local experience = identity.experience or body._hcoOriginalExperience or currentExperience
	local _, weapon = util.call(body, "getWeapon")
	local _, keycard = util.call(body, "getKeycard")
	local _, keychain = util.call(body, "getKeychain")
	local weaponType, weaponID = getWeaponIdentity(weapon)
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE
	local tier, access

	weaponType = identity.weaponType or weaponType
	weaponID = identity.weaponID or weaponID
	keycard = identity.keycard or keycard
	keychain = identity.keychain or keychain

	if not weapon and not identity.armed and not identity.hadRadio and not keycard and not keychain then
		tier, access = "staff", 1
	elseif elite and tonumber(experience) and experience >= elite then
		tier, access = "elite_security", 3
	else
		tier, access = "regular_security", 2
	end

	if keycard or keychain then
		access = math.max(access, tier == "elite_security" and 3 or 2)
	end

	return tier, access, weaponType, weaponID, keycard, keychain, identity.bloodied == true
end

local function observerLocallyCompromised(state, observer, group)
	local observerID = util.getID(observer)
	local known = observerID and state.localCompromisedDisguises and state.localCompromisedDisguises[observerID]

	return known and known[group] == true
end

local function isGloballyCompromised(state)
	return state.disguise and (state.disguise.compromised or state.compromisedDisguises[state.disguise.group])
end

function disguise.getBehaviorRisk(state, player)
	if not state.disguise or isGloballyCompromised(state) then
		return 1
	end

	local stateID = getPlayerStateID(player)

	if stateID and SUSPICIOUS_PLAYER_STATES[stateID] then
		return 1
	end

	local okAim, aiming = util.call(player, "getAiming")

	if okAim and aiming then
		return 1
	end

	local okSprint, sprinting = util.call(player, "getSprinting")

	if not okSprint then
		okSprint, sprinting = util.call(player, "isSprinting")
	end

	if okSprint and sprinting then
		return config.DISGUISE_SPRINT_DETECTION
	end

	if state.disguise.illicitTime and (curTime or 0) - state.disguise.illicitTime <= config.DISGUISE_ILLICIT_ACTION_TIME then
		-- The takeover remains suspicious at close range, but putting on a valid
		-- uniform does not globally preserve the pre-takeover hostile identity.
		-- Overt actions above always take precedence over this softer transition.
		return config.DISGUISE_TAKEOVER_DETECTION
	end

	return math.max(
		tonumber(state.disguise.lingerRisk) or 0,
		tonumber(state.disguise.disturbanceRisk) or 0,
		state.disguise.bloodied and config.DISGUISE_BLOODIED_DETECTION or 0
	)
end

local function observerFactor(state, observer, player)
	if state.disguise and observerLocallyCompromised(state, observer, state.disguise.group) then
		return 1
	end

	local _, enemyInSight = util.call(observer, "getEnemyInSight", player)

	-- Knowledge is observer-local. A global combat music/alert state never
	-- identifies this disguised player by itself; an observer that already has
	-- the player as its current enemy remains authoritative. A full native
	-- detection meter alone is not identity knowledge: the base game can leave
	-- that meter behind when the player changes clothes.
	if enemyInSight then
		return 1
	end

	local risk = disguise.getBehaviorRisk(state, player)
	local _, observerGroup = util.call(observer, "getAnimVariant")
	local factor = tostring(observerGroup) == state.disguise.group and config.DISGUISE_COLLEAGUE_DETECTION or config.DISGUISE_BASE_DETECTION
	local _, experience = util.call(observer, "getExperienceLevel")
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE

	if elite and tonumber(experience) and experience >= elite then
		factor = factor * 1.35
	end

	if observer._hcoSecurityRole == "close_protection" then
		factor = factor * 1.2
	elseif observer._hcoSecurityRole == "protected_target" then
		factor = factor * 1.45
	end

	return math.min(1, math.max(risk, factor))
end

local function saveDisguise(state)
	if not state.contract then
		return
	end

	local active = state.disguise
	local contexts = stateModule.getContexts(state)
	if #contexts == 0 then contexts = {state} end
	for _, context in ipairs(contexts) do
		local record = context.contract
		if record then
			record.disguiseGroup = active and active.group or nil
			record.disguiseSourceID = active and active.sourceID or nil
			record.disguiseKeycard = active and active.keycard or nil
			record.disguiseKeychain = active and active.keychain or nil
			record.disguiseTier = active and active.tier or nil
			record.disguiseAccess = active and active.accessReduction or nil
			record.disguiseWeaponType = active and active.weaponType or nil
			record.disguiseWeaponID = active and active.weaponID or nil
			record.disguiseOriginalAnimVar = active and active.originalAnimVar or nil
			record.disguiseAcquiredTime = active and active.acquiredTime or nil
			record.disguiseSourceWasDead = active and active.sourceWasDead == true or false
			record.disguiseBloodied = active and active.bloodied == true or false
			record.disguiseFactionVisual = active and active.factionVisual or nil
			record.usedDisguiseSources = state.usedDisguiseSources
			record.compromisedDisguises = state.compromisedDisguises
			persistence.save(record)
		end
	end
end

local function clearNativeIdentityMemory(observer, player, notifyNative)
	if notifyNative then
		util.call(observer, "setEnemyInSight", false, player)
	end

	local playerID = util.getID(player)
	local otherEnemyInSight = false
	if playerID and type(observer.enemiesInSight) == "table" then
		observer.enemiesInSight[playerID] = false
		for id, visible in pairs(observer.enemiesInSight) do
			if id ~= playerID and visible == true then
				otherEnemyInSight = true
				break
			end
		end
	end
	if playerID and type(observer.enemiesInSightMirror) == "table" then
		observer.enemiesInSightMirror[playerID] = false
	end

	observer.enemyInSight = otherEnemyInSight
	if not otherEnemyInSight then observer.enemyWasInSight = false end
	observer.seenPlayer = false
	if observer.visionEnemy == player then observer.visionEnemy = nil end
	if observer.lastVisionEnemy == player then observer.lastVisionEnemy = nil end
	if observer.lastHearActor == player then observer.lastHearActor = nil end
	if observer.closestEnemy == player then
		observer.closestEnemy = nil
		observer.closestEnemyDistance = math.huge
	end
	util.call(player, "onEnemyLostSight", observer)
end

local function rebindIdentityKnowledge(state, player, witnessTakeover)
	if not game.worldObject or type(game.worldObject.getNPCs) ~= "function" then
		return
	end

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		ensureNPCSightHooks(state, npc)

		if witnessTakeover and util.isAlive(npc) and hasCurrentVisualContact(npc, player) then
			-- A real eyewitness knows that this specific person changed clothes.
			-- Keep that knowledge local until their physical radio report finishes.
			markLocalCompromise(state, npc, state.disguise.group)
			queueRadioCompromise(state, npc, state.disguise.group, "identity-takeover")
		else
			-- Everyone else must forget the old actor identity. Merely retaining a
			-- full vanilla detection meter or historical seenPlayer flag would make
			-- the fresh disguise fail instantly despite no witnessed takeover.
			util.call(npc, "setDetection", player, 0)
			clearNativeIdentityMemory(npc, player, true)
		end
	end
end

function disguise.applyFromBody(state, body, player)
	local _, group = util.call(body, "getAnimVariant")

	if not group or not state.contract or not util.worldMatches(state, state.target) then
		return false
	end

	local tier, access, weaponType, weaponID, keycard, keychain, bloodied = classifyBody(body)
	local _, sourceWasDead = util.call(body, "isDead")
	local switched = state.disguise ~= nil
	local _, previousAnimVar = util.call(player, "getAnimVariant")
	local originalAnimVar = state.disguise and state.disguise.originalAnimVar

	if not originalAnimVar then
		originalAnimVar = previousAnimVar
	end

	local candidate = {
		group = tostring(group),
		sourceID = util.getID(body),
		keycard = keycard,
		keychain = keychain,
		tier = tier,
		accessReduction = access,
		weaponType = weaponType,
		weaponID = weaponID,
		originalAnimVar = originalAnimVar,
		acquiredTime = curTime or 0,
		illicitTime = curTime or 0,
		lingerTime = 0,
		lingerRisk = 0,
		sourceWasDead = sourceWasDead == true,
		bloodied = bloodied,
		factionVisual = tonumber(body._hcoFactionVisual),
		compromised = state.compromisedDisguises[tostring(group)] == true
	}

	local changed = util.call(player, "setAnimVariant", group)
	local _, appliedGroup = util.call(player, "getAnimVariant")

	if not changed or tostring(appliedGroup) ~= tostring(group) then
		if previousAnimVar then util.call(player, "setAnimVariant", previousAnimVar) end
		feedback.show(english.DISGUISE_VISUAL_FAILED)
		util.log(config, "disguise rejected because visual variant did not apply group=" .. tostring(group))
		return false, "visual-variant-rejected"
	end

	state.disguise = candidate
	state.disguiseRisk = candidate.compromised and 1 or disguise.getBehaviorRisk(state, player)
	state.closeScrutiny = {}
	state.lastLocalExposureFeedbackTime = nil
	body._hcoDisguiseTaken = true
	player._hcoDisguiseFactionVisual = candidate.factionVisual
	state.usedDisguiseSources = state.usedDisguiseSources or {}
	if candidate.sourceID then state.usedDisguiseSources[candidate.sourceID] = true end

	local _, hasKeycard = util.call(player, "hasKey", keycard)
	if keycard and not hasKeycard then util.call(player, "addKey", keycard, nil) end
	local _, hasKeychain = util.call(player, "hasKey", keychain)
	if keychain and not hasKeychain then util.call(player, "addKey", keychain, nil) end

	for _, context in ipairs(stateModule.getContexts(state)) do
		context.contract.metrics = context.contract.metrics or {}
		context.contract.metrics.usedDisguise = true
	end
	rebindIdentityKnowledge(state, player, true)
	saveDisguise(state)
	feedback.show(state.disguise.compromised and english.DISGUISE_COMPROMISED or english.disguiseAcquired(tier, switched, keycard or keychain, bloodied))
	identityFX.trigger(state, state.disguise.compromised and "compromised" or "acquired")
	util.log(config, "disguise acquired tier=" .. tostring(tier) .. " group=" .. tostring(group) .. " source=" .. tostring(state.disguise.sourceID) .. " keycard=" .. tostring(keycard or "none"))

	return true
end

function disguise.restore(state)
	local record = state.contract
	local player = game and game.playerActor

	if not record or not record.disguiseGroup or not player then
		return false
	end

	local _, originalAnimVar = util.call(player, "getAnimVariant")
	state.compromisedDisguises = record.compromisedDisguises or {}
	state.usedDisguiseSources = record.usedDisguiseSources or {}
	state.disguise = {
		group = record.disguiseGroup,
		sourceID = record.disguiseSourceID,
		keycard = record.disguiseKeycard,
		keychain = record.disguiseKeychain,
		tier = record.disguiseTier or "regular_security",
		accessReduction = record.disguiseAccess or ((record.disguiseKeycard or record.disguiseKeychain) and 2 or 1),
		weaponType = record.disguiseWeaponType,
		weaponID = record.disguiseWeaponID,
		originalAnimVar = record.disguiseOriginalAnimVar or originalAnimVar,
		acquiredTime = record.disguiseAcquiredTime or curTime or 0,
		illicitTime = nil,
		lingerTime = 0,
		lingerRisk = 0,
		sourceWasDead = record.disguiseSourceWasDead == true,
		bloodied = record.disguiseBloodied == true,
		factionVisual = record.disguiseFactionVisual,
		compromised = state.compromisedDisguises[record.disguiseGroup] == true
	}

	local changed = util.call(player, "setAnimVariant", record.disguiseGroup)
	local _, appliedGroup = util.call(player, "getAnimVariant")
	if not changed or tostring(appliedGroup) ~= tostring(record.disguiseGroup) then
		state.disguise = nil
		feedback.show(english.DISGUISE_VISUAL_FAILED)
		return false
	end

	local _, hasKeycard = util.call(player, "hasKey", record.disguiseKeycard)
	if record.disguiseKeycard and not hasKeycard then util.call(player, "addKey", record.disguiseKeycard, nil) end
	local _, hasKeychain = util.call(player, "hasKey", record.disguiseKeychain)
	if record.disguiseKeychain and not hasKeychain then util.call(player, "addKey", record.disguiseKeychain, nil) end
	player._hcoDisguiseFactionVisual = state.disguise.factionVisual
	state.disguiseRisk = state.disguise.compromised and 1 or disguise.getBehaviorRisk(state, player)

	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		if state.usedDisguiseSources[util.getID(body)] then body._hcoDisguiseTaken = true end
	end
	if not state.disguise.compromised then
		rebindIdentityKnowledge(state, player, false)
	end

	feedback.show(english.disguiseRestored(state.disguise.tier, state.disguise.compromised))
	identityFX.trigger(state, state.disguise.compromised and "compromised" or "restored")

	return true
end

function disguise.remove(state, player)
	player = player or game and game.playerActor
	local active = state and state.disguise
	if not active or not player or not active.originalAnimVar then return false, "no-active-disguise" end
	local changed = util.call(player, "setAnimVariant", active.originalAnimVar)
	local _, applied = util.call(player, "getAnimVariant")
	if not changed or tostring(applied) ~= tostring(active.originalAnimVar) then
		feedback.show(english.DISGUISE_VISUAL_FAILED)
		return false, "original-visual-rejected"
	end
	player._hcoDisguiseFactionVisual = nil
	for _, pending in ipairs(state.pendingCompromises or {}) do
		if pending.openedByHCO and pending.radio then util.call(pending.radio, "close") end
	end
	state.disguise = nil
	state.disguiseRisk = 1
	state.localCompromisedDisguises = {}
	state.pendingCompromises = {}
	state.closeScrutiny = {}
	state.lastLocalExposureFeedbackTime = nil
	saveDisguise(state)
	feedback.show(english.DISGUISE_REMOVED)
	identityFX.trigger(state, "restored")
	util.log(config, "original player identity restored")
	return true
end

function disguise.clear(state, restoreVisual)
	local player = game and game.playerActor

	if restoreVisual and player and state.disguise and state.disguise.originalAnimVar then
		util.call(player, "setAnimVariant", state.disguise.originalAnimVar)
	end
	if player then player._hcoDisguiseFactionVisual = nil end

	state.disguise = nil
	state.disguiseRisk = 1
	state.compromisedDisguises = {}
	state.usedDisguiseSources = {}
	state.localCompromisedDisguises = {}
	state.pendingCompromises = {}
	state.closeScrutiny = {}
	state.lastLocalExposureFeedbackTime = nil
	identityFX.clear(state)
end

markLocalCompromise = function(state, observer, group)
	local id = util.getID(observer)

	if not id then
		return
	end

	state.localCompromisedDisguises[id] = state.localCompromisedDisguises[id] or {}
	state.localCompromisedDisguises[id][group] = true
end

queueRadioCompromise = function(state, observer, group, kind)
	local okRadio, radio = util.call(observer, "getRadio")

	if not okRadio or not radio then
		return
	end

	for _, pending in ipairs(state.pendingCompromises) do
		if pending.observer == observer and pending.group == group then
			return
		end
	end

	local _, wasOpen = util.call(radio, "isOpen")
	local openedByHCO = wasOpen ~= true

	if openedByHCO then
		-- Radios are closed by default. Opening the real NPC radio makes this a
		-- visible/audible and disruptible report instead of a hidden timer.
		util.call(radio, "open")
	end

	table.insert(state.pendingCompromises, {
		observer = observer,
		radio = radio,
		group = group,
		kind = kind or "evidence",
		remaining = kind == "identity-check" and config.DISGUISE_IDENTITY_CHECK_TRANSMISSION or config.RADIO_TRANSMISSION_TIME,
		waitRemaining = config.RADIO_WAIT_TIMEOUT,
		openedByHCO = openedByHCO,
		worldToken = state.worldToken
	})

	if kind == "identity-check" then
		feedback.show(english.DISGUISE_IDENTITY_CHECK)
		identityFX.trigger(state, "checking", config.DISGUISE_IDENTITY_CHECK_TRANSMISSION + 0.2)
	end
end

local function globallyCompromise(state, group, source)
	if state.compromisedDisguises[group] then
		return
	end

	state.compromisedDisguises[group] = true

	if state.disguise and state.disguise.group == group then
		state.disguise.compromised = true
		state.disguiseRisk = 1
		feedback.show(english.DISGUISE_COMPROMISED)
		identityFX.trigger(state, "compromised")
	end

	saveDisguise(state)
	util.log(config, "disguise globally compromised group=" .. tostring(group) .. " source=" .. tostring(source))
end

function disguise.onSensorBodySeen(state, sensor, body)
	if not state.disguise or not body then
		return false
	end

	local _, group = util.call(body, "getAnimVariant")
	local sourceMatch = util.getID(body) == state.disguise.sourceID
	local groupMatch = group ~= nil and tostring(group) == state.disguise.group

	if not sourceMatch and not groupMatch then
		return false
	end

	-- Search drones are networked sensors. Once one has an unobstructed view of
	-- the stolen uniform's source, the identity is compromised immediately; the
	-- player can prevent this by hiding the body, disrupting or destroying the
	-- drone before it completes the scan.
	globallyCompromise(state, state.disguise.group, "drone-body-scan:" .. tostring(util.getID(sensor) or "sensor"))
	return true
end

function disguise.onBodySeen(state, observer, body)
	local _, group = util.call(body, "getAnimVariant")

	if not group or not state.disguise then
		return
	end

	group = tostring(group)
	local sourceMatch = util.getID(body) == state.disguise.sourceID
	local groupMatch = group == state.disguise.group

	if not sourceMatch and not groupMatch then
		return
	end

	-- The original source actor can be restored to its vanilla animation variant
	-- during a checkpoint rebuild. Its identity still compromises the disguise
	-- that was actually taken from it, not the restored cosmetic variant.
	if sourceMatch then group = state.disguise.group end

	markLocalCompromise(state, observer, group)

	if game.worldObject and type(game.worldObject.getNPCs) == "function" then
		for _, nearby in ipairs(util.getNPCs(game.worldObject)) do
			if util.isAlive(nearby) and util.distance(observer, nearby) <= config.KNOWLEDGE_NEARBY_RANGE then
				markLocalCompromise(state, nearby, group)
			end
		end
	end

	queueRadioCompromise(state, observer, group)
	for _, context in ipairs(stateModule.getContexts(state)) do
		securityDirector.notifyBodyEvidence(context, observer, body)
	end
	util.log(config, "disguise evidence found group=" .. group .. " observer=" .. tostring(util.getID(observer)))
end

local function processPendingCompromises(state, dt)
	for index = #state.pendingCompromises, 1, -1 do
		local pending = state.pendingCompromises[index]
		local observer = pending.observer
		local remove = pending.worldToken ~= state.worldToken or not util.isAlive(observer)
		local radio = pending.radio

		if not remove then
			if pending.kind == "identity-check" then
				local player = game and game.playerActor
				remove = not player or not state.disguise or state.disguise.group ~= pending.group
					or util.distance(observer, player) > config.DISGUISE_IDENTITY_CHECK_RANGE * 1.35
			end
		end

		if not remove then
			local _, currentRadio = util.call(observer, "getRadio")
			radio = currentRadio or radio

			if not radio then
				remove = true
			else
				local _, disrupted = util.call(radio, "isDisrupted")
				local _, open = util.call(radio, "isOpen")

				if disrupted == true then
					remove = true
				elseif open == true then
					pending.remaining = pending.remaining - dt

					if pending.remaining <= 0 then
						globallyCompromise(state, pending.group, pending.kind == "identity-check" and "failed-identity-check" or "completed-radio-call")
						remove = true
					end
				else
					pending.waitRemaining = pending.waitRemaining - dt
					remove = pending.waitRemaining <= 0
				end
			end
		end

		if remove then
			if pending.openedByHCO and radio then
				util.call(radio, "close")
			end

			table.remove(state.pendingCompromises, index)
		end
	end
end

hasCurrentVisualContact = function(observer, player)
	-- getSeenPlayer() is persistent vanilla memory ("has ever seen the player"),
	-- not proof that this observer saw this shot. Reuse the current native
	-- vision AABB/FOV and generic world raycast instead. enemyInSight is only a
	-- fallback for unusual actors that do not expose those native vision APIs;
	-- for regular goons it can itself be a stale one-frame flag.
	local _, enemyInSight = util.call(observer, "getEnemyInSight", player)
	local hasNativeVision = type(observer.updateVisionData) == "function"
		and type(observer.isWithinView) == "function"
		and type(observer.runGenericRaycast) == "function"

	if not hasNativeVision then
		return enemyInSight == true
	end

	local okVision, visionData = util.call(observer, "updateVisionData", player)
	local okView, withinView = util.call(observer, "isWithinView", player)

	if not okVision or type(visionData) ~= "table" or not okView then
		return false
	end

	if visionData[5] ~= true or withinView ~= true then
		return false
	end

	local okObserverCenter, ox, oy = util.call(observer, "getCenter")
	local okPlayerCenter, px, py = util.call(player, "getCenter")

	if not okObserverCenter then ox, oy = util.getPos(observer) end
	if not okPlayerCenter then px, py = util.getPos(player) end
	if not ox or not px then return false end

	local okRay, hit = util.call(observer, "runGenericRaycast", ox, oy, px, py, player)

	if not okRay or type(hit) ~= "table" then
		return false
	end

	if tonumber(hit.fraction) and hit.fraction >= 0.999 then
		return true
	end

	local okFixture, playerFixture = util.call(player, "getFixture")

	return okFixture and playerFixture ~= nil and hit.fixture == playerFixture
end

local function closeScrutinyTime(state, observer)
	local duration = config.DISGUISE_CLOSE_SCRUTINY_TIME
	local _, observerGroup = util.call(observer, "getAnimVariant")

	if state.disguise and tostring(observerGroup) == tostring(state.disguise.group) then
		duration = duration * 0.55
	end

	local _, experience = util.call(observer, "getExperienceLevel")
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE
	if elite and tonumber(experience) and experience >= elite then duration = duration * 0.75 end

	if observer._hcoSecurityRole == "close_protection" then
		duration = duration * 0.75
	elseif observer._hcoSecurityRole == "protected_target" then
		duration = duration * 0.6
	end

	return math.max(0.55, duration)
end

local function exposeIdentityToObserver(state, observer, player, reason, activateNativeState)
	if not state.disguise or not observer or not player
		or observerLocallyCompromised(state, observer, state.disguise.group) then
		return false
	end

	local observerID = util.getID(observer)
	markLocalCompromise(state, observer, state.disguise.group)
	queueRadioCompromise(state, observer, state.disguise.group, reason or "close-recognition")
	if observerID and state.closeScrutiny then state.closeScrutiny[observerID] = nil end
	local now = curTime or 0
	if state.lastLocalExposureFeedbackTime == nil or now - state.lastLocalExposureFeedbackTime >= 0.75 then
		state.lastLocalExposureFeedbackTime = now
		feedback.show(english.DISGUISE_LOCALLY_EXPOSED)
		identityFX.trigger(state, "exposed")
	end
	util.log(config, "disguise locally exposed observer=" .. tostring(observerID) .. " reason=" .. tostring(reason or "close-recognition"))

	if not activateNativeState then
		return true
	end

	util.call(observer, "setDetection", player, 1)
	local okState, stateObject = util.call(observer, "getState")

	if okState and stateObject and type(stateObject.onSightHitPlayer) == "function" then
		pcall(stateObject.onSightHitPlayer, stateObject, player)
	end

	local _, enemyInSight = util.call(observer, "getEnemyInSight", player)
	if enemyInSight == true then return true end

	-- A future or unusual state may accept the callback without establishing
	-- any actionable result. Never leave confirmed red recognition as dialogue
	-- only: give that observer real enemy knowledge and enter its native combat
	-- transition as the fail-closed fallback.
	util.call(observer, "setEnemyInSight", true, player)
	if okState and stateObject and type(stateObject.goToCombat) == "function" then
		pcall(stateObject.goToCombat, stateObject, true)
	end

	return true
end

local function updateCloseScrutiny(state, player, dt)
	state.closeScrutiny = state.closeScrutiny or {}
	local observed = {}

	for _, observer in ipairs(util.getNPCs(game.worldObject)) do
		local observerID = util.getID(observer)
		if observerID and util.isAlive(observer)
			and not observerLocallyCompromised(state, observer, state.disguise.group) then
			local distance = util.distance(observer, player)

			if distance <= config.DISGUISE_CLOSE_SCRUTINY_RANGE and hasCurrentVisualContact(observer, player) then
				observed[observerID] = true

				if distance <= config.DISGUISE_POINT_BLANK_RECOGNITION_RANGE then
					exposeIdentityToObserver(state, observer, player, "point-blank-recognition", true)
				else
					local entry = state.closeScrutiny[observerID] or {time = 0, observer = observer}
					entry.time = entry.time + dt
					entry.observer = observer
					state.closeScrutiny[observerID] = entry

					if entry.time >= closeScrutinyTime(state, observer) then
						exposeIdentityToObserver(state, observer, player, "close-inspection", true)
					end
				end
			end
		end
	end

	for observerID, entry in pairs(state.closeScrutiny) do
		if not observed[observerID] then
			entry.time = math.max(0, (tonumber(entry.time) or 0) - dt * config.DISGUISE_CLOSE_SCRUTINY_DECAY)
			if entry.time <= 0 or not util.isAlive(entry.observer) then state.closeScrutiny[observerID] = nil end
		end
	end
end

local function shouldSuppressNativeRecognition(state, observer, player)
	if player ~= (game and game.playerActor) or not state.contract or not state.disguise then
		return false
	end

	if isGloballyCompromised(state)
		or observerLocallyCompromised(state, observer, state.disguise.group) then
		return false
	end

	-- Point-blank inspection is a deliberate hard failure state. The native
	-- sight callback that asked this question continues immediately after the
	-- observer gains local knowledge, preserving the game's own threaten,
	-- startle, surrender and combat behavior.
	if util.distance(observer, player) <= config.DISGUISE_POINT_BLANK_RECOGNITION_RANGE
		and hasCurrentVisualContact(observer, player) then
		exposeIdentityToObserver(state, observer, player, "point-blank-recognition", false)
		return false
	end

	return disguise.getBehaviorRisk(state, player) < 1
end

local function patchSightStateObject(state, stateObject)
	if type(stateObject) ~= "table" or rawget(stateObject, "_hcoDisguiseSightOriginal") then
		return false
	end

	local original = stateObject.onSightHitPlayer
	if type(original) ~= "function" then
		return false
	end

	rawset(stateObject, "_hcoDisguiseSightOriginal", original)
	rawset(stateObject, "onSightHitPlayer", function(self, playerData, ...)
		local observer = self.actor or self.owner

		if observer and shouldSuppressNativeRecognition(state, observer, playerData) then
			-- Vanilla suspicion, alert, investigate-body and combat states all have
			-- direct branches that can mark the player hostile at close range. Run
			-- only their native detection progression, then hold calm social cover
			-- below the radio-check boundary. No combat transition or spotted stat
			-- is allowed until this observer actually knows the identity.
			local advanced = util.call(self, "advanceDetection", playerData)
			if not advanced then
				util.call(observer, "increaseDetection", playerData, 0.05)
			end

			local okDetection, currentDetection = util.call(observer, "getDetection", playerData)
			if okDetection and tonumber(currentDetection)
				and currentDetection > config.DISGUISE_SOFT_DETECTION_CAP then
				util.call(observer, "setDetection", playerData, config.DISGUISE_SOFT_DETECTION_CAP)
			end

			clearNativeIdentityMemory(observer, playerData, false)
			return
		end

		return original(self, playerData, ...)
	end)

	return true
end

ensureNPCSightHooks = function(state, npc)
	if not npc then return end

	local seen = {}
	local function patch(candidate)
		if candidate and not seen[candidate] then
			seen[candidate] = true
			patchSightStateObject(state, candidate)
		end
	end

	local okCurrent, current = util.call(npc, "getState")
	if okCurrent then patch(current) end

	if type(npc.states) == "table" then
		for _, stateObject in pairs(npc.states) do patch(stateObject) end
	end
	if type(npc.stateMap) == "table" then
		for _, stateObject in pairs(npc.stateMap) do patch(stateObject) end
	end
end

local function refreshNPCSightHooks(state, dt)
	state.disguiseSightHookRefreshTime = (state.disguiseSightHookRefreshTime or 0) - (dt or 0)
	if state.disguiseSightHookRefreshTime > 0 then return end
	state.disguiseSightHookRefreshTime = 0.5

	if not game.worldObject or type(game.worldObject.getNPCs) ~= "function" then return end
	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		ensureNPCSightHooks(state, npc)
	end
end

local function compromiseDirectWitnesses(state)
	local player = game and game.playerActor

	if not state.disguise or not player or not game.worldObject or type(game.worldObject.getNPCs) ~= "function" then
		return
	end

	local witnessed = false

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		if util.isAlive(npc) then
			if hasCurrentVisualContact(npc, player) then
				witnessed = true
				markLocalCompromise(state, npc, state.disguise.group)
				queueRadioCompromise(state, npc, state.disguise.group)
			end
		end
	end

	if witnessed and state.contract and state.contract.metrics then
		state.contract.metrics.alarmRaised = true
		persistence.save(state.contract)
	end
end

local function updateTargetLingerRisk(state, player, dt)
	local nearTarget = false

	for _, context in ipairs(stateModule.getContexts(state)) do
		if context.target and util.isAlive(context.target) and util.distance(context.target, player) <= config.DISGUISE_TARGET_LINGER_RANGE then
			nearTarget = true
			break
		end
	end

	if nearTarget then
		state.disguise.lingerTime = math.min(config.DISGUISE_TARGET_LINGER_DANGER + 4, (state.disguise.lingerTime or 0) + dt)
	else
		state.disguise.lingerTime = math.max(0, (state.disguise.lingerTime or 0) - dt * 1.5)
	end

	if state.disguise.lingerTime >= config.DISGUISE_TARGET_LINGER_DANGER then
		state.disguise.lingerRisk = 0.65
	elseif state.disguise.lingerTime >= config.DISGUISE_TARGET_LINGER_WARNING then
		state.disguise.lingerRisk = 0.35
	else
		state.disguise.lingerRisk = 0
	end
end

local function updateDisturbanceRisk(state, player)
	local now = curTime or 0
	local risk = 0

	for _, context in ipairs(stateModule.getContexts(state)) do
		for _, evidence in ipairs(context.security and context.security.evidencePositions or {}) do
			local age = now - (tonumber(evidence.time) or now)
			if age <= config.DISGUISE_DISTURBANCE_MAX_AGE and util.distanceToPoint(player, evidence.x, evidence.y) <= config.DISGUISE_DISTURBANCE_RANGE then
				risk = config.DISGUISE_DISTURBANCE_DETECTION
				break
			end
		end
		if risk > 0 then break end
	end

	state.disguise.disturbanceRisk = risk
end

local function isBodyInteractionTarget(body, interactor)
	if not interactor or not body or (not interactor.PLAYER and interactor ~= (game and game.playerActor)) then return false end
	local _, dead = util.call(body, "isDead")
	local _, unconscious = util.call(body, "isUnconscious")
	return dead == true or unconscious == true
end

local function isEligibleBody(state, body, interactor)
	local bodyID = util.getID(body)
	if not state.contract or not isBodyInteractionTarget(body, interactor) or body._hcoDisguiseTaken
		or bodyID and state.usedDisguiseSources and state.usedDisguiseSources[bodyID] then
		return false
	end

	local _, group = util.call(body, "getAnimVariant")

	return group ~= nil
end

local function invalidateBodyInteractionCache(state, body)
	if not body then return false end
	local generation = state.hcoDisguiseInteractionGeneration or 0
	if body._hcoDisguiseInteractionGeneration == generation then return false end

	-- Native bodies cache both the visible option objects and a bitmask of the
	-- class action IDs. A body cached before HCO registration or across a mission
	-- reset can otherwise claim an HCO bit while rendering neither action. Rebuild
	-- exactly once per registration generation, then let the native updater own
	-- the other menu entries again.
	body.currentActionBitmask = 0
	if body._interactionList then body._interactionList.options = {} end
	body._hcoDisguiseInteractionGeneration = generation
	return true
end

local function isInteractionEntry(entry, option, sentinel)
	return entry == option or entry and entry._hcoInteraction == sentinel
end

local function setActionBit(body, option, visible)
	local mask, id = tonumber(body and body.currentActionBitmask), tonumber(option and option.id)
	if not mask or not id or not bit or type(bit.band) ~= "function" then return end
	local active = bit.band(mask, id) == id
	if visible and not active then
		body.currentActionBitmask = mask + id
	elseif not visible and active then
		body.currentActionBitmask = mask - id
	end
end

local function reconcileVisibleAction(body, interactionList, option, sentinel, visible, preferredIndex)
	local options = interactionList and interactionList.options
	if type(options) ~= "table" or not option then return end
	for index = #options, 1, -1 do
		if isInteractionEntry(options[index], option, sentinel) then table.remove(options, index) end
	end
	if visible then
		-- Keep HCO's signature action visually first without renumbering native or
		-- third-party class actions. Renumbering a live class invalidates the cached
		-- action bitmasks on every existing body and caused the original regression.
		table.insert(options, math.max(1, math.min(preferredIndex or 1, #options + 1)), option)
	end
	setActionBit(body, option, visible)
end

local function reconcileVisibleBodyActions(state, body, interactor, interactionList)
	if type(interactionList) ~= "table" or type(interactionList.options) ~= "table" then return interactionList end
	reconcileVisibleAction(body, interactionList, state.hcoDisguiseInteraction, INTERACTION_SENTINEL,
		isEligibleBody(state, body, interactor), 1)
	reconcileVisibleAction(body, interactionList, state.hcoDisguiseRestoreInteraction, RESTORE_INTERACTION_SENTINEL,
		state.disguise ~= nil and isBodyInteractionTarget(body, interactor), 2)
	return interactionList
end

local function refreshBodyInteraction(state, body, interactor)
	if not body or not interactor then return false end
	invalidateBodyInteractionCache(state, body)

	-- Existing bodies cache their native option list. Updating that list after
	-- HCO's class-level action registration is what makes hot-loaded and
	-- checkpoint-restored bodies expose the disguise action in the real menu.
	if body._interactionList and type(body.updateInteractionList) == "function" then
		local ok = util.call(body, "updateInteractionList", interactor)
		reconcileVisibleBodyActions(state, body, interactor, body._interactionList)
		return ok
	end

	return false
end

local function refreshNearbyBodies(state, player, dt)
	state.disguiseInteractionRefreshTime = (state.disguiseInteractionRefreshTime or 0) - dt
	if state.disguiseInteractionRefreshTime > 0 then return end
	state.disguiseInteractionRefreshTime = config.DISGUISE_SWITCH_COOLDOWN

	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		if isEligibleBody(state, body, player) or state.disguise and isBodyInteractionTarget(body, player) then
			refreshBodyInteraction(state, body, player)

			if isEligibleBody(state, body, player) and not state.disguiseBodyHintShown and util.distance(body, player) <= config.DISGUISE_BODY_HINT_RANGE then
				state.disguiseBodyHintShown = true
				feedback.show(english.DISGUISE_BODY_AVAILABLE)
			end
		end
	end
end

function disguise.update(state, dt)
	local player = game and game.playerActor
	local bindingsOK, bindingsError = pcall(ensureRuntimeBindings, state, false, dt)
	if not bindingsOK then util.log(config, "disguise runtime binding refresh failed: " .. tostring(bindingsError)) end

	refreshNPCSightHooks(state, dt)
	processPendingCompromises(state, dt)
	identityFX.update(state, dt)
	if player then refreshNearbyBodies(state, player, dt) end
	if state.disguise and player then
		updateTargetLingerRisk(state, player, dt)
		updateDisturbanceRisk(state, player)
		if not isGloballyCompromised(state) then updateCloseScrutiny(state, player, dt) end
	end
	state.disguiseRisk = player and disguise.getBehaviorRisk(state, player) or 1

	if not state.disguise or not player or isGloballyCompromised(state) then
		return
	end

	state.identityCheckTime = (state.identityCheckTime or 8) - dt

	if state.identityCheckTime > 0 or state.disguiseRisk >= 0.5 then
		return
	end

	state.identityCheckTime = config.DISGUISE_IDENTITY_CHECK_MIN + util.stableHash(tostring(state.contract and state.contract.seed or 0) .. ":" .. tostring(math.floor((curTime or 0) / 10))) % config.DISGUISE_IDENTITY_CHECK_VARIANCE
	local closest, closestDistance

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		if npc ~= state.target and util.isAlive(npc) then
			local _, group = util.call(npc, "getAnimVariant")
			local distance = util.distance(npc, player)

			if tostring(group) == state.disguise.group and distance <= config.DISGUISE_IDENTITY_CHECK_RANGE and (not closestDistance or distance < closestDistance) then
				closest = npc
				closestDistance = distance
			end
		end
	end

	if closest then
		local _, current = util.call(closest, "getDetection", player)
		local increase = closest._hcoEscort and 0.18 or 0.1
		local nextDetection = math.min(1, (tonumber(current) or 0) + increase)

		util.call(closest, "setDetection", player, nextDetection)
		if nextDetection >= config.DISGUISE_IDENTITY_CHECK_THRESHOLD then
			queueRadioCompromise(state, closest, state.disguise.group, "identity-check")
		end
		util.log(config, "identity check observer=" .. tostring(util.getID(closest)) .. " detection+=" .. tostring(increase))
	end
end

local function installBodyInteraction(state, goonClass)
	local list = goonClass.interactionList
	local option
	local restoreOption

	for index = #list, 1, -1 do
		local existing = list[index]
		if existing._hcoInteraction == INTERACTION_SENTINEL or existing == state.hcoDisguiseInteraction then
			if not option then
				option = existing
			end
			table.remove(list, index)
		elseif existing._hcoInteraction == RESTORE_INTERACTION_SENTINEL or existing == state.hcoDisguiseRestoreInteraction then
			if not restoreOption then restoreOption = existing end
			table.remove(list, index)
		end
	end

	option = option or {}
	option._hcoInteraction = INTERACTION_SENTINEL

	function option.getText()
		return english.disguiseInteraction(state.disguise ~= nil)
	end

	function option.actionCheck(body, interactor)
		return isEligibleBody(state, body, interactor)
	end

	function option.interact(body, interactor)
		local ok, applied, reason = pcall(disguise.applyFromBody, state, body, interactor)

		if not ok then
			util.log(config, "disguise interaction failed: " .. tostring(applied))
			feedback.show(english.DISGUISE_UNAVAILABLE)
		elseif not applied then
			util.log(config, "disguise interaction rejected: " .. tostring(reason or "unknown"))
		end
	end

	restoreOption = restoreOption or {}
	restoreOption._hcoInteraction = RESTORE_INTERACTION_SENTINEL

	function restoreOption.getText()
		return english.disguiseRestoreInteraction()
	end

	function restoreOption.actionCheck(body, interactor)
		return state.disguise ~= nil and isBodyInteractionTarget(body, interactor)
	end

	function restoreOption.interact(body, interactor)
		local ok, removed, reason = pcall(disguise.remove, state, interactor)
		if not ok then
			util.log(config, "identity restore interaction failed: " .. tostring(removed))
			feedback.show(english.DISGUISE_UNAVAILABLE)
		elseif not removed then
			util.log(config, "identity restore interaction rejected: " .. tostring(reason or "unknown"))
		end
	end

	-- Append to the class registry so every already-enumerated native/third-party
	-- action keeps its original bit ID. The returned per-body menu is reordered by
	-- reconcileVisibleBodyActions, which gives the player the requested first-slot
	-- takeover without mutating the engine's global action identity scheme.
	table.insert(list, option)
	table.insert(list, restoreOption)

	local usedIDs = {}
	local nextID = 1
	for _, entry in ipairs(list) do
		local id = tonumber(entry.id)
		if id and id > 0 and not usedIDs[id] then
			usedIDs[id] = true
			while usedIDs[nextID] do nextID = nextID * 2 end
		else
			entry.id = nil
		end
	end
	for _, entry in ipairs(list) do
		if not entry.id then
			while usedIDs[nextID] do nextID = nextID * 2 end
			entry.id = nextID
			usedIDs[nextID] = true
			nextID = nextID * 2
		end
	end
	while usedIDs[nextID] do nextID = nextID * 2 end
	goonClass.actionTrackerID = nextID

	state.hcoDisguiseInteraction = option
	state.hcoDisguiseRestoreInteraction = restoreOption
	state.hcoDisguiseInteractionGeneration = (state.hcoDisguiseInteractionGeneration or 0) + 1
	state.hcoDisguiseBoundGoonClass = goonClass
end

local function installHooks(state, goonClass)
	state.hooks = state.hooks or {}

	if not state.hooks.reset and type(goonClass.reset) == "function" then
		state.hooks.reset = goonClass.reset
		local original = goonClass.reset

		function goonClass:reset(...)
			self._hcoDisguiseIdentity = nil
			self._hcoDisguiseTaken = nil
			self._hcoDisguiseInteractionGeneration = nil
			return original(self, ...)
		end
	end

	if not state.hooks.increaseDetection and type(goonClass.increaseDetection) == "function" then
		state.hooks.increaseDetection = goonClass.increaseDetection
		local original = goonClass.increaseDetection

		function goonClass:increaseDetection(target, amount, cutoff)
			if target == game.playerActor and state.disguise and state.contract then
				amount = amount * observerFactor(state, self, target)
			end

			return original(self, target, amount, cutoff)
		end
	end

	if not state.hooks.setEnemyInSight and type(goonClass.setEnemyInSight) == "function" then
		state.hooks.setEnemyInSight = goonClass.setEnemyInSight
		local original = goonClass.setEnemyInSight

		function goonClass:setEnemyInSight(stateValue, actorInst)
			if stateValue == true and actorInst == (game and game.playerActor)
				and shouldSuppressNativeRecognition(state, self, actorInst) then
				local okDetection, currentDetection = util.call(self, "getDetection", actorInst)
				if okDetection and tonumber(currentDetection)
					and currentDetection > config.DISGUISE_SOFT_DETECTION_CAP then
					util.call(self, "setDetection", actorInst, config.DISGUISE_SOFT_DETECTION_CAP)
				end
				clearNativeIdentityMemory(self, actorInst, false)
				return
			end

			return original(self, stateValue, actorInst)
		end
	end

	if not state.hooks.getStateObject and type(goonClass.getStateObject) == "function" then
		state.hooks.getStateObject = goonClass.getStateObject
		local original = goonClass.getStateObject

		function goonClass:getStateObject(...)
			local stateObject = original(self, ...)
			patchSightStateObject(state, stateObject)
			return stateObject
		end
	end

	if not state.hooks.setState and type(goonClass.setState) == "function" then
		state.hooks.setState = goonClass.setState
		local original = goonClass.setState

		function goonClass:setState(stateObject, ...)
			patchSightStateObject(state, stateObject)
			return original(self, stateObject, ...)
		end
	end

	if not state.hooks.getInteractOptions and type(goonClass.getInteractOptions) == "function" then
		state.hooks.getInteractOptions = goonClass.getInteractOptions
		local original = goonClass.getInteractOptions

		function goonClass:getInteractOptions(interactor, update)
			-- objectSelector:setInteractionData deliberately re-reads the already
			-- validated menu without passing an interactor. That nil call is a render
			-- handoff, not a request to re-run action checks. Treating nil as an invalid
			-- player removed the disguise action between selector filtering and drawing.
			if interactor == nil then
				return original(self, interactor, update)
			end

			-- This is the authoritative selector boundary. The base implementation may
			-- return a cached list without updating it at all when update=false. Repair
			-- the cache before that query, then reconcile the exact returned list after
			-- native actions run so takeover cannot be absent while its bit is still set.
			local invalidated = invalidateBodyInteractionCache(state, self)
			-- If HCO cleared an old generation, force the native updater once even
			-- when the selector requested update=false; otherwise unrelated carry,
			-- inventory and finish-off entries would remain absent from that menu.
			local interactionList = original(self, interactor, update or invalidated)
			return reconcileVisibleBodyActions(state, self, interactor, interactionList)
		end
	end

	if not state.hooks.hcoDisguiseBodyPostDraw and type(goonClass.postDraw) == "function" then
		state.hooks.hcoDisguiseBodyPostDraw = goonClass.postDraw
		local original = goonClass.postDraw

		function goonClass:postDraw(...)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player and isEligibleBody(state, self, player)
				and util.distance(self, player) <= config.DISGUISE_BODY_MARKER_RANGE then
				identityFX.drawAvailableBody(self, state.disguise ~= nil)
			end
			return result
		end
	end

	if not state.hooks.hcoDisguiseDie and type(goonClass._die) == "function" then
		state.hooks.hcoDisguiseDie = goonClass._die
		local original = goonClass._die

		function goonClass:_die(...)
			cacheBodyIdentity(self)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(state, self, player) end
			return result
		end
	end

	if not state.hooks.hcoDisguiseChoke and type(goonClass._choke) == "function" then
		state.hooks.hcoDisguiseChoke = goonClass._choke
		local original = goonClass._choke

		function goonClass:_choke(...)
			cacheBodyIdentity(self)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(state, self, player) end
			return result
		end
	end

	if not state.hooks.setSeenBody and type(goonClass.setSeenBody) == "function" then
		state.hooks.setSeenBody = goonClass.setSeenBody
		local original = goonClass.setSeenBody

		function goonClass:setSeenBody(body, seen, ignoreStat)
			local result = original(self, body, seen, ignoreStat)

			if seen then
				disguise.onBodySeen(state, self, body)
			end

			return result
		end
	end

	if not state.hooks.makeFallen and type(goonClass.makeFallen) == "function" then
		state.hooks.makeFallen = goonClass.makeFallen
		local original = goonClass.makeFallen

		function goonClass:makeFallen(...)
			cacheBodyIdentity(self)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(state, self, player) end
			return result
		end
	end

	if not state.hooks.onBodyDropped and type(goonClass.onBodyDropped) == "function" then
		state.hooks.onBodyDropped = goonClass.onBodyDropped
		local original = goonClass.onBodyDropped

		function goonClass:onBodyDropped(...)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(state, self, player) end
			return result
		end
	end

	if not state.hooks.getOfflimits and type(playerActor.getOfflimits) == "function" then
		state.hooks.getOfflimits = playerActor.getOfflimits
		local original = playerActor.getOfflimits

		function playerActor:getOfflimits(...)
			local value = original(self, ...)

			if type(value) == "number" and state.disguise and state.contract and disguise.getBehaviorRisk(state, self) < 0.5 then
				return math.max(npcAlertnessStates.STATES.IDLE, value - (state.disguise.accessReduction or 1))
			end

			return value
		end
	end

	if not state.hooks.getOfflimitsActive and type(playerActor.getOfflimitsActive) == "function" then
		state.hooks.getOfflimitsActive = playerActor.getOfflimitsActive
		local original = playerActor.getOfflimitsActive

		function playerActor:getOfflimitsActive(...)
			if state.disguise and state.contract and disguise.getBehaviorRisk(state, self) < 0.5 then
				local ok, value = pcall(self.getOfflimits, self)
				if ok and type(value) == "number" then
					return value > npcAlertnessStates.STATES.IDLE
				end
			end

			return original(self, ...)
		end
	end
end

local function hasInteractionBinding(state, goonClass)
	local take, restore = false, false
	for _, entry in ipairs(goonClass and goonClass.interactionList or {}) do
		if entry._hcoInteraction == INTERACTION_SENTINEL or entry == state.hcoDisguiseInteraction then take = true end
		if entry._hcoInteraction == RESTORE_INTERACTION_SENTINEL or entry == state.hcoDisguiseRestoreInteraction then restore = true end
	end
	return take and restore
end

ensureRuntimeBindings = function(state, force, dt)
	state.disguiseBindingRefreshTime = (state.disguiseBindingRefreshTime or 0) - (dt or 0)
	if not force and state.disguiseBindingRefreshTime > 0 then return true end
	state.disguiseBindingRefreshTime = 0.5
	local goonClass = actor.getClassData and actor.getClassData("goon")
	if not goonClass or type(goonClass.interactionList) ~= "table" then return false end

	if state.hcoDisguiseBoundGoonClass ~= goonClass then
		state.hooks = state.hooks or {}
		for _, key in ipairs(GOON_HOOK_KEYS) do state.hooks[key] = nil end
		state.hcoDisguiseBoundGoonClass = goonClass
		installHooks(state, goonClass)
	end
	if not hasInteractionBinding(state, goonClass) then
		installBodyInteraction(state, goonClass)
		util.log(config, "native disguise actions rebound after class/menu lifecycle reset")
	end
	return true
end

local function installEventListener(state)
	if state.disguiseEventListenerInstalled or not playerActor.EVENTS or not playerActor.EVENTS.FIRED_WEAPON then
		return
	end

	local listener = {}

	function listener:handleEvent()
		local ok, err = pcall(compromiseDirectWitnesses, state)

		if not ok then
			util.log(config, "disguise gunfire witness handling failed: " .. tostring(err))
		end
	end

	state.disguiseEventListener = listener
	state.disguiseEventListenerInstalled = true
	events:addDirectReceiver(listener, {playerActor.EVENTS.FIRED_WEAPON})
end

function disguise.initialize(state)
	local goonClass = actor.getClassData and actor.getClassData("goon")

	if not goonClass or type(goonClass.interactionList) ~= "table" then
		error("goon class or interaction list unavailable")
	end

	installBodyInteraction(state, goonClass)
	installHooks(state, goonClass)
	state.hcoDisguiseBoundGoonClass = goonClass
	state.disguiseBindingRefreshTime = 0.5
	refreshNPCSightHooks(state, 1)
	identityFX.initialize(state)
	installEventListener(state)
	state.hcoDroneBodySeen = function(sensor, body)
		return disguise.onSensorBodySeen(state, sensor, body)
	end
end

return disguise
