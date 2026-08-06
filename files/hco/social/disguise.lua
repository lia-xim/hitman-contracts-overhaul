local config = require("hco/config")
local english = require("hco/localization/english")
local feedback = require("hco/feedback")
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
	player_taking_item_throwing = true
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

local function classifyBody(body)
	local _, currentExperience = util.call(body, "getExperienceLevel")
	local experience = body._hcoOriginalExperience or currentExperience
	local _, weapon = util.call(body, "getWeapon")
	local _, keycard = util.call(body, "getKeycard")
	local weaponType, weaponID = getWeaponIdentity(weapon)
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE
	local tier, access

	if not weapon then
		tier, access = "staff", 1
	elseif elite and tonumber(experience) and experience >= elite then
		tier, access = "elite_security", 3
	else
		tier, access = "regular_security", 2
	end

	if keycard then
		access = math.max(access, tier == "elite_security" and 3 or 2)
	end

	return tier, access, weaponType, weaponID, keycard
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

	if active.tier == "elite_security" then
		if active.weaponType == nil or weaponType == active.weaponType or active.weaponID ~= nil and weaponID == active.weaponID then
			return 0.15
		end

		return config.DISGUISE_VISIBLE_WEAPON_DETECTION
	end

	if active.weaponType ~= nil and weaponType == active.weaponType then
		return 0.15
	end

	if active.weaponID ~= nil and weaponID == active.weaponID then
		return 0.15
	end

	return active.tier == "staff" and config.DISGUISE_WRONG_WEAPON_DETECTION or config.DISGUISE_VISIBLE_WEAPON_DETECTION
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

	return visibleWeaponRisk(state, player)
end

local function observerFactor(state, observer, player)
	if state.disguise and observerLocallyCompromised(state, observer, state.disguise.group) then
		return 1
	end

	local risk = disguise.getBehaviorRisk(state, player)

	if risk > 0 then
		return risk
	end

	local _, observerGroup = util.call(observer, "getAnimVariant")
	local factor = tostring(observerGroup) == state.disguise.group and config.DISGUISE_COLLEAGUE_DETECTION or config.DISGUISE_BASE_DETECTION
	local _, experience = util.call(observer, "getExperienceLevel")
	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE

	if elite and tonumber(experience) and experience >= elite then
		factor = factor * 1.5
	end

	if observer._hcoSecurityRole == "close_protection" then
		factor = factor * 1.35
	elseif observer._hcoSecurityRole == "protected_target" then
		factor = factor * 1.6
	end

	return math.min(1, factor)
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
			record.disguiseTier = active and active.tier or nil
			record.disguiseAccess = active and active.accessReduction or nil
			record.disguiseWeaponType = active and active.weaponType or nil
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

	local tier, access, weaponType, weaponID, keycard = classifyBody(body)
	local originalAnimVar = state.disguise and state.disguise.originalAnimVar

	if not originalAnimVar then
		local _, currentAnimVar = util.call(player, "getAnimVariant")
		originalAnimVar = currentAnimVar
	end

	state.disguise = {
		group = tostring(group),
		sourceID = util.getID(body),
		keycard = keycard,
		tier = tier,
		accessReduction = access,
		weaponType = weaponType,
		weaponID = weaponID,
		originalAnimVar = originalAnimVar,
		acquiredTime = curTime or 0,
		compromised = state.compromisedDisguises[tostring(group)] == true
	}

	body._hcoDisguiseTaken = true
	util.call(player, "setAnimVariant", group)

	if keycard and type(player.addKey) == "function" and not player:hasKey(keycard) then
		player:addKey(keycard, nil)
	end

	for _, context in ipairs(stateModule.getContexts(state)) do
		context.contract.metrics = context.contract.metrics or {}
		context.contract.metrics.usedDisguise = true
	end
	clearLowDetection(player)
	saveDisguise(state)
	feedback.show(state.disguise.compromised and english.DISGUISE_COMPROMISED or english.DISGUISE_ACQUIRED)
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
	state.disguise = {
		group = record.disguiseGroup,
		sourceID = record.disguiseSourceID,
		keycard = record.disguiseKeycard,
		tier = record.disguiseTier or "regular_security",
		accessReduction = record.disguiseAccess or (record.disguiseKeycard and 2 or 1),
		weaponType = record.disguiseWeaponType,
		originalAnimVar = originalAnimVar,
		acquiredTime = curTime or 0,
		compromised = state.compromisedDisguises[record.disguiseGroup] == true
	}

	util.call(player, "setAnimVariant", record.disguiseGroup)

	if record.disguiseKeycard and type(player.addKey) == "function" and not player:hasKey(record.disguiseKeycard) then
		player:addKey(record.disguiseKeycard, nil)
	end

	return true
end

function disguise.clear(state, restoreVisual)
	local player = game and game.playerActor

	if restoreVisual and player and state.disguise and state.disguise.originalAnimVar then
		util.call(player, "setAnimVariant", state.disguise.originalAnimVar)
	end

	state.disguise = nil
	state.compromisedDisguises = {}
	state.localCompromisedDisguises = {}
	state.pendingCompromises = {}
end

local function markLocalCompromise(state, observer, group)
	local id = util.getID(observer)

	if not id then
		return
	end

	state.localCompromisedDisguises[id] = state.localCompromisedDisguises[id] or {}
	state.localCompromisedDisguises[id][group] = true
end

local function queueRadioCompromise(state, observer, group)
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
		remaining = config.RADIO_TRANSMISSION_TIME,
		waitRemaining = config.RADIO_WAIT_TIMEOUT,
		openedByHCO = openedByHCO,
		worldToken = state.worldToken
	})
end

local function globallyCompromise(state, group, source)
	if state.compromisedDisguises[group] then
		return
	end

	state.compromisedDisguises[group] = true

	if state.disguise and state.disguise.group == group then
		state.disguise.compromised = true
		feedback.show(english.DISGUISE_COMPROMISED)
	end

	saveDisguise(state)
	util.log(config, "disguise globally compromised group=" .. tostring(group) .. " source=" .. tostring(source))
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
						globallyCompromise(state, pending.group, "completed-radio-call")
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

function disguise.update(state, dt)
	local player = game and game.playerActor

	processPendingCompromises(state, dt)

	if not state.disguise or not player or isGloballyCompromised(state) then
		return
	end

	state.identityCheckTime = (state.identityCheckTime or 8) - dt

	if state.identityCheckTime > 0 or disguise.getBehaviorRisk(state, player) >= 0.5 then
		return
	end

	state.identityCheckTime = config.DISGUISE_IDENTITY_CHECK_MIN + util.stableHash(tostring(state.contract and state.contract.seed or 0) .. ":" .. tostring(math.floor((curTime or 0) / 10))) % config.DISGUISE_IDENTITY_CHECK_VARIANCE
	local closest, closestDistance

	for _, npc in ipairs(util.getNPCs(game.worldObject)) do
		if npc ~= state.target and util.isAlive(npc) then
			local _, group = util.call(npc, "getAnimVariant")
			local distance = util.distance(npc, player)

			if tostring(group) == state.disguise.group and distance <= 220 and (not closestDistance or distance < closestDistance) then
				closest = npc
				closestDistance = distance
			end
		end
	end

	if closest then
		local _, current = util.call(closest, "getDetection", player)
		local increase = closest._hcoEscort and 0.18 or 0.1

		util.call(closest, "setDetection", player, math.min(1, (tonumber(current) or 0) + increase))
		util.log(config, "identity check observer=" .. tostring(util.getID(closest)) .. " detection+=" .. tostring(increase))
	end
end

local function installBodyInteraction(state, goonClass)
	if state.hcoDisguiseInteraction then
		return
	end

	local option = {}

	function option.getText()
		return "Search body / take disguise"
	end

	function option.actionCheck(body, interactor)
		if not state.contract or not interactor or not interactor.PLAYER or body._hcoDisguiseTaken then
			return false
		end

		local _, dead = util.call(body, "isDead")
		local _, unconscious = util.call(body, "isUnconscious")
		local _, group = util.call(body, "getAnimVariant")

		return group ~= nil and (dead == true or unconscious == true)
	end

	function option.interact(body, interactor)
		local ok, err = pcall(disguise.applyFromBody, state, body, interactor)

		if not ok then
			util.log(config, "disguise interaction failed: " .. tostring(err))
		end
	end

	local used = {}

	for _, existing in ipairs(goonClass.interactionList or {}) do
		if existing.id then
			used[existing.id] = true
		end
	end

	local id = 1

	while used[id] or id <= #(goonClass.interactionList or {}) do
		id = id * 2
	end

	option.id = id
	table.insert(goonClass.interactionList, option)
	state.hcoDisguiseInteraction = option
end

local function installHooks(state, goonClass)
	state.hooks = state.hooks or {}

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
	installEventListener(state)
end

return disguise
