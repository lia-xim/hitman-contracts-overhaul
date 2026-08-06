local config = require("hco/config")
local balance = require("hco/balance")
local profiles = require("hco/contracts/profiles")
local util = require("hco/util")

local escort = {}

local escortSafeRejections = {
	["no-patrol"] = true,
	["insufficient-route-nodes"] = true
}

local function isEscortSafeEntry(entry)
	if entry.eligible then
		return true
	end

	if entry.data.class ~= "goon" or entry.data.dead or entry.data.unconscious then
		return false
	end

	for _, reason in ipairs(entry.reasons or {}) do
		if not escortSafeRejections[reason] then
			return false
		end
	end

	return true
end

local function canEscort(entry, target)
	if entry.npc == target or entry.npc._hcoReservedTarget or entry.npc._hcoAssignedContract or not isEscortSafeEntry(entry) then
		return false
	end

	local ok, weapon = util.call(entry.npc, "getWeapon")

	return ok and weapon ~= nil
end

local function makeFollow(follower, leader)
	local okState, stateObject = util.call(follower, "getState")

	if okState and stateObject and type(stateObject.goToFollow) == "function" then
		local ok = pcall(stateObject.goToFollow, stateObject, leader, "goon_idle_following")

		return ok
	end

	return false
end

function escort.detach(state)
	for _, data in ipairs(state.escorts or {}) do
		local actorObject = data.actor

		if actorObject then
			actorObject._hcoEscort = nil
			actorObject._hcoOriginalExperience = nil
			actorObject._hcoAssignedContract = nil
			actorObject._hcoFactionVisual = nil
			util.call(actorObject, "setFollower", nil)

			if data.experience then
				util.call(actorObject, "setExperienceLevel", data.experience)
			end
			if data.animVariant then util.call(actorObject, "setAnimVariant", data.animVariant) end

			if data.maxHealth then
				util.call(actorObject, "setMaxHealth", data.maxHealth)
			end

			if data.health then
				util.call(actorObject, "setHealth", math.min(data.health, data.maxHealth or data.health))
			end

			if data.originalState then
				util.call(actorObject, "setState", data.originalState)
			end

			if data.originalRoute then
				util.call(actorObject, "setActivePatrolRoute", data.originalRoute, data.originalRouteIndex or 1)
			end
		end
	end

	if state.target then
		util.call(state.target, "setFollower", nil)
		if state.originalTargetMaxHealth then
			util.call(state.target, "setMaxHealth", state.originalTargetMaxHealth)
			if state.originalTargetHealth then
				util.call(state.target, "setHealth", math.min(state.originalTargetHealth, state.originalTargetMaxHealth))
			end
		end
	end

	state.escorts = {}
	state.originalTargetHealth = nil
	state.originalTargetMaxHealth = nil
end

function escort.attach(state, report)
	escort.detach(state)

	local candidates = {}

	for _, entry in ipairs(report.entries or report.eligible) do
		if canEscort(entry, state.target) then
			table.insert(candidates, {
				entry = entry,
				distance = util.distance(entry.npc, state.target)
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.distance == b.distance then
			return a.entry.data.id < b.entry.data.id
		end

		return a.distance < b.distance
	end)

	local goonClass = actor.getClassData and actor.getClassData("goon")
	local elite = goonClass and goonClass.EXPERIENCE_LEVELS and goonClass.EXPERIENCE_LEVELS.ELITE
	local leader = state.target
	local profile = profiles.resolve(state.contract and state.contract.seed or 0, state.contract and state.contract.archetype)
	local tuning = balance.snapshot(profile)
	state.balance = tuning
	local requestedResponse = balance.scaledCount(profile.responseUnits or 0, tuning.responseScale, 1)
	local requestedProtection = (profile.bodyguards or 5) + requestedResponse
	local escortCount = math.min(requestedProtection, state.escortLimit or math.huge)
	local healthMultiplier = (profile.healthMultiplier or config.ESCORT_HEALTH_MULTIPLIER) * tuning.guardHealthScale
	local _, targetHealth = util.call(state.target, "getHealth")
	local _, targetMaxHealth = util.call(state.target, "getMaxHealth")
	state.originalTargetHealth = targetHealth
	state.originalTargetMaxHealth = targetMaxHealth

	if tonumber(targetMaxHealth) and targetMaxHealth > 0 then
		local targetMultiplier = (profile.targetHealthMultiplier or config.TARGET_HEALTH_MULTIPLIER) * tuning.targetHealthScale
		util.call(state.target, "setMaxHealth", math.floor(targetMaxHealth * targetMultiplier))
		util.call(state.target, "maxOutHealth")
	end

	for index = 1, math.min(escortCount, #candidates) do
		local actorObject = candidates[index].entry.npc
		local _, experience = util.call(actorObject, "getExperienceLevel")
		local _, animVariant = util.call(actorObject, "getAnimVariant")
		local _, originalState = util.call(actorObject, "getState")
		local _, originalRoute = util.call(actorObject, "getActivePatrolRoute")
		local _, originalRouteIndex = util.call(actorObject, "getPatrolRouteIndex")
		local _, health = util.call(actorObject, "getHealth")
		local _, maxHealth = util.call(actorObject, "getMaxHealth")
		local data = {
			actor = actorObject,
			id = util.getID(actorObject),
			experience = experience,
			animVariant = animVariant,
			health = health,
			maxHealth = maxHealth,
			originalState = originalState,
			originalRoute = originalRoute,
			originalRouteIndex = originalRouteIndex,
			role = index <= (profile.bodyguards or 5) and "close_protection" or "response_unit"
		}

		actorObject._hcoEscort = true
		actorObject._hcoOriginalExperience = experience
		actorObject._hcoAssignedContract = state.contract and state.contract.contractID or true
		actorObject._hcoFactionVisual = profile.visualIndex
		local variants = profile.guardVariants or {}
		if #variants > 0 then util.call(actorObject, "setAnimVariant", variants[(index - 1) % #variants + 1]) end

		if elite then
			util.call(actorObject, "setExperienceLevel", elite)
		end

		if tonumber(maxHealth) and maxHealth > 0 then
			util.call(actorObject, "setMaxHealth", math.floor(maxHealth * healthMultiplier))
		end
		util.call(actorObject, "maxOutHealth")

		if data.role == "close_protection" then
			if index == 1 or (index - 1) % 3 == 0 then
				leader = state.target
			end

			makeFollow(actorObject, leader)
			leader = actorObject
		else
			-- Response units are autonomous search/combat actors. Putting them into
			-- the native follower chain leaves their leader holding a stale follower
			-- reference as soon as HCO changes the response unit to alert/combat. The
			-- leader then calls follower-only methods such as getWatchBack() on a
			-- combat state and crashes the mission.
			util.call(actorObject, "setFollower", nil)
		end
		table.insert(state.escorts, data)
	end

	if state.contract and state.contract.metrics then
		state.contract.metrics.initialEscortCount = math.max(state.contract.metrics.initialEscortCount or 0, #state.escorts)
		state.contract.metrics.livingEscortCount = #state.escorts
	end

	local closeCount, responseCount = 0, 0
	for _, data in ipairs(state.escorts) do
		if data.role == "close_protection" then closeCount = closeCount + 1 else responseCount = responseCount + 1 end
	end
	state.protectionStrength = {close = closeCount, response = responseCount, requestedResponse = requestedResponse, threatRating = tuning.threatRating}
	util.log(config, "elite protection assigned close=" .. tostring(closeCount) .. " response=" .. tostring(responseCount) .. " requestedResponse=" .. tostring(requestedResponse) .. " threat=" .. tostring(tuning.threatLabel) .. " difficulty=" .. tostring(tuning.difficultyID))
end

function escort.update(state)
	if not state.target or not state.targetAI then
		return
	end

	state.escortUpdateTime = (state.escortUpdateTime or 0) - (state.runtimeDelta or 0)

	if state.escortUpdateTime > 0 then
		return
	end

	state.escortUpdateTime = state.targetAI.phase == "ROUTINE" and 2 or 0.75

	local leader = state.target

	for _, data in ipairs(state.escorts or {}) do
		local actorObject = data.actor

		if data.role == "close_protection" and util.isAlive(actorObject) then
			if state.targetAI.phase == "ROUTINE" and util.distance(actorObject, leader) > config.ESCORT_REJOIN_DISTANCE then
				makeFollow(actorObject, leader)
			elseif state.targetAI.phase ~= "ROUTINE" then
				-- Close protection evacuates with the principal. Response units are
				-- deliberately left under the security director's search orders.
				makeFollow(actorObject, state.target)
			end

			leader = actorObject
		end
	end
end

return escort
