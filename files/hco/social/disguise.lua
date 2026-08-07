local config = require("hco/config")
local english = require("hco/localization/english")
local feedback = require("hco/feedback")
local identityFX = require("hco/social/identity_fx")
local persistence = require("hco/contracts/persistence")
local securityDirector = require("hco/security/director")
local stateModule = require("hco/state")
local util = require("hco/util")

local disguise = {}

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
	player_taking_item_throwing = true,
	player_reloading = true,
	player_reload = true,
	player_reloading_weapon = true
}

local INTERACTION_SENTINEL = "hco_take_disguise_v1"

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

local function visibleWeaponRisk(state, player)
	local okWeapon, weapon = util.call(player, "getWeapon")
	local okConcealed, concealed = util.call(player, "getWeaponConcealed")

	if not okWeapon or not weapon or (okConcealed and concealed) then
		return 0
	end

	local weaponType, weaponID = getWeaponIdentity(weapon)
	local active = state.disguise

	if active.tier == "staff" then
		return config.DISGUISE_WRONG_WEAPON_DETECTION
	end

	-- Security uniforms are expected to carry weapons. Exact models do not
	-- matter: the native weapon type is the stable family boundary (sidearm,
	-- primary, gadget, and so on). A different but ordinary security family is
	-- a mild inconsistency, never an instant reveal. Aiming, firing and native
	-- combat remain fully exposing through getBehaviorRisk/observerFactor.
	if active.weaponType == nil or weaponType == active.weaponType
		or active.weaponID ~= nil and weaponID == active.weaponID then
		return config.DISGUISE_MATCHING_WEAPON_DETECTION
	end

	return config.DISGUISE_SECURITY_WEAPON_DETECTION
end

function disguise.getBehaviorRisk(state, player)
	if not state.disguise or isGloballyCompromised(state) then
		return 1
	end

	local stateID = getPlayerStateID(player)

	if stateID and SUSPICIOUS_PLAYER_STATES[stateID] then
		return 1
	end

	if state.disguise.firedTime and (curTime or 0) - state.disguise.firedTime <= 5 then
		return 1
	end

	if state.disguise.illicitTime and (curTime or 0) - state.disguise.illicitTime <= config.DISGUISE_ILLICIT_ACTION_TIME then
		-- The takeover remains suspicious at close range, but putting on a valid
		-- uniform does not globally preserve the pre-takeover hostile identity.
		-- Actual witnesses/body investigators are handled by native sight and
		-- setSeenBody, which can still compromise this identity locally.
		return config.DISGUISE_TAKEOVER_DETECTION
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

	return math.max(
		visibleWeaponRisk(state, player),
		tonumber(state.disguise.lingerRisk) or 0,
		tonumber(state.disguise.disturbanceRisk) or 0,
		state.disguise.bloodied and config.DISGUISE_BLOODIED_DETECTION or 0
	)
end

local function observerFactor(state, observer, player)
	if state.disguise and observerLocallyCompromised(state, observer, state.disguise.group) then
		return 1
	end

	if npcAlertnessStates and npcAlertnessStates.getCombat and npcAlertnessStates:getCombat() then
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

local function clearLowDetection(player)
	if not game.worldObject or type(game.worldObject.getNPCs) ~= "function" then
		return
	end

	if npcAlertnessStates and npcAlertnessStates.getCombat and npcAlertnessStates:getCombat() then
		return
	end

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		local ok, value = util.call(npc, "getDetection", player)

		if ok and value and value < 1 then
			util.call(npc, "setDetection", player, math.min(value, 0.2))
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
	clearLowDetection(player)
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

	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		if state.usedDisguiseSources[util.getID(body)] then body._hcoDisguiseTaken = true end
	end

	feedback.show(english.disguiseRestored(state.disguise.tier, state.disguise.compromised))
	identityFX.trigger(state, state.disguise.compromised and "compromised" or "restored")

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
	identityFX.clear(state)
end

local function markLocalCompromise(state, observer, group)
	local id = util.getID(observer)

	if not id then
		return
	end

	state.localCompromisedDisguises[id] = state.localCompromisedDisguises[id] or {}
	state.localCompromisedDisguises[id][group] = true
end

local function queueRadioCompromise(state, observer, group, kind)
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

local function compromiseDirectWitnesses(state)
	local player = game and game.playerActor

	if not state.disguise or not player or not game.worldObject or type(game.worldObject.getNPCs) ~= "function" then
		return
	end

	state.disguise.firedTime = curTime or 0
	local witnessed = false

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		if util.isAlive(npc) then
			local _, sees = util.call(npc, "getEnemyInSight", player)
			local _, detection = util.call(npc, "getDetection", player)

			if sees or tonumber(detection) and detection >= 0.8 then
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

local function isEligibleBody(state, body, interactor)
	local bodyID = util.getID(body)
	if not state.contract or not interactor or not interactor.PLAYER or not body or body._hcoDisguiseTaken
		or bodyID and state.usedDisguiseSources and state.usedDisguiseSources[bodyID] then
		return false
	end

	local _, dead = util.call(body, "isDead")
	local _, unconscious = util.call(body, "isUnconscious")
	local _, group = util.call(body, "getAnimVariant")

	return group ~= nil and (dead == true or unconscious == true)
end

local function refreshBodyInteraction(body, interactor)
	if not body or not interactor then return false end

	-- Existing bodies cache their native option list. Updating that list after
	-- HCO's class-level action registration is what makes hot-loaded and
	-- checkpoint-restored bodies expose the disguise action in the real menu.
	if body._interactionList and type(body.updateInteractionList) == "function" then
		local ok = util.call(body, "updateInteractionList", interactor)
		return ok
	end

	return false
end

local function refreshNearbyBodies(state, player, dt)
	state.disguiseInteractionRefreshTime = (state.disguiseInteractionRefreshTime or 0) - dt
	if state.disguiseInteractionRefreshTime > 0 then return end
	state.disguiseInteractionRefreshTime = config.DISGUISE_SWITCH_COOLDOWN

	for _, body in ipairs(util.getNPCs(game.worldObject)) do
		if isEligibleBody(state, body, player) then
			refreshBodyInteraction(body, player)

			if not state.disguiseBodyHintShown and util.distance(body, player) <= config.DISGUISE_BODY_HINT_RANGE then
				state.disguiseBodyHintShown = true
				feedback.show(english.DISGUISE_BODY_AVAILABLE)
			end
		end
	end
end

function disguise.update(state, dt)
	local player = game and game.playerActor

	processPendingCompromises(state, dt)
	identityFX.update(state, dt)
	if player then refreshNearbyBodies(state, player, dt) end
	if state.disguise and player then
		updateTargetLingerRisk(state, player, dt)
		updateDisturbanceRisk(state, player)
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
	local inList = false

	for index = #list, 1, -1 do
		local existing = list[index]
		if existing._hcoInteraction == INTERACTION_SENTINEL or existing == state.hcoDisguiseInteraction then
			if not option then
				option = existing
				inList = true
			else
				table.remove(list, index)
			end
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
		else
			util.call(body, "postInteract", interactor)
		end
	end

	if not inList then
		table.insert(list, option)
	end

	if type(goonClass.enumerateActions) == "function" then
		local ok, err = util.call(goonClass, "enumerateActions")
		if not ok then error("failed to enumerate native disguise action: " .. tostring(err)) end
	else
		goonClass.actionTrackerID = 1
		for _, entry in ipairs(list) do
			entry.id = goonClass.actionTrackerID
			goonClass.actionTrackerID = goonClass.actionTrackerID * 2
		end
	end

	state.hcoDisguiseInteraction = option
end

local function installHooks(state, goonClass)
	state.hooks = state.hooks or {}

	if not state.hooks.reset and type(goonClass.reset) == "function" then
		state.hooks.reset = goonClass.reset
		local original = goonClass.reset

		function goonClass:reset(...)
			self._hcoDisguiseIdentity = nil
			self._hcoDisguiseTaken = nil
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

	if not state.hooks.hcoDisguiseDie and type(goonClass._die) == "function" then
		state.hooks.hcoDisguiseDie = goonClass._die
		local original = goonClass._die

		function goonClass:_die(...)
			cacheBodyIdentity(self)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(self, player) end
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
			if player then refreshBodyInteraction(self, player) end
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
			if player then refreshBodyInteraction(self, player) end
			return result
		end
	end

	if not state.hooks.onBodyDropped and type(goonClass.onBodyDropped) == "function" then
		state.hooks.onBodyDropped = goonClass.onBodyDropped
		local original = goonClass.onBodyDropped

		function goonClass:onBodyDropped(...)
			local result = original(self, ...)
			local player = game and game.playerActor
			if player then refreshBodyInteraction(self, player) end
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
	identityFX.initialize(state)
	installEventListener(state)
	state.hcoDroneBodySeen = function(sensor, body)
		return disguise.onSensorBodySeen(state, sensor, body)
	end
end

return disguise
