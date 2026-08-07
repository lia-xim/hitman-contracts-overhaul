local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path

function love.errorhandler(message)
	io.stderr:write("HCO_RUNTIME_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n")
	os.exit(1)
end

local function assertEqual(actual, expected, label)
	if actual ~= expected then
		error((label or "assertion") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end

local function assertTrue(value, label)
	if not value then
		error(label or "expected truthy value")
	end
end

curTime = 0
scrW, scrH = 1920, 1080
function _S(value)
	return value
end

gui = {}
function gui.create()
	local object = {w = 200}
	local methods = {"setFont", "setText", "setTargetW", "setupVisual", "addDepth", "wrapText", "setPos"}

	for _, method in ipairs(methods) do
		object[method] = function()
			return
		end
	end

	return object
end

events = {
	directReceivers = {}
}

function events:addDirectReceiver(object, eventList, handlerName)
	handlerName = handlerName or "handleEvent"

	for _, event in ipairs(eventList) do
		self.directReceivers[event] = self.directReceivers[event] or {}
		local duplicate = false

		for _, entry in ipairs(self.directReceivers[event]) do
			if entry.object == object and entry.handlerName == handlerName then
				duplicate = true
			end
		end

		if not duplicate then
			table.insert(self.directReceivers[event], {object = object, handlerName = handlerName})
		end
	end
end

function events:removeDirectReceiver(object, eventList, handlerName)
	handlerName = handlerName or "handleEvent"

	for _, event in ipairs(eventList or {}) do
		local list = self.directReceivers[event] or {}

		for index = #list, 1, -1 do
			if list[index].object == object and list[index].handlerName == handlerName then
				table.remove(list, index)
			end
		end
	end
end

function events:fire(event, ...)
	local snapshot = {}

	for index, entry in ipairs(self.directReceivers[event] or {}) do
		snapshot[index] = entry
	end

	for _, entry in ipairs(snapshot) do
		entry.object[entry.handlerName](entry.object, event, ...)
	end
end

game = {
	EVENTS = {
		MAP_LOADED = 1,
		RESET_FINISHED = 2,
		GAME_UNLOADED = 3,
		RETURNING_TO_MAIN_MENU = 4,
		PRE_REMOVE_GAME = 5,
		POST_MODS_LOADED = 8,
		RESET_STARTED = 9,
		LEVEL_FINISHED = 10
	}
}

function game.addHUDElement()
	return
end

actor = {
	EVENTS = {
		NEUTRALIZED = 6,
		DIED = 7
	}
}

weapons = {EVENTS = {FIRED = 11}}

npcAlertnessStates = {
	STATES = {
		IDLE = 1,
		SUSPICION = 2,
		ALERT = 3,
		COMBAT = 4
	},
	inCombat = false
}

function npcAlertnessStates:getCombat()
	return self.inCombat
end

local goonClass = {
	class = "goon",
	IDLE_STATE = "goon_idle",
	FEAR_STATE = "goon_fear",
	EXPERIENCE_LEVELS = {
		GREEN = 1,
		EXPERIENCED = 2,
		ELITE = 3
	},
	interactionList = {
		{actionCheck = function() return false end},
		{actionCheck = function() return false end}
	}
}

function goonClass:enumerateActions()
	self.actionTrackerID = 1
	for _, option in ipairs(self.interactionList) do
		option.id = self.actionTrackerID
		self.actionTrackerID = self.actionTrackerID * 2
	end
end
goonClass:enumerateActions()

function goonClass:increaseDetection(target, amount)
	self.detection[target] = math.min(1, (self.detection[target] or 0) + amount)

	return self.detection[target]
end

function goonClass:setEnemyInSight(value, target)
	self.enemyInSight = value == true
	self.enemiesInSight = self.enemiesInSight or {}

	if target then
		self.enemiesInSight[target:getID()] = value == true
	end
	if value == true then
		self.seenPlayer = true
	end
end

function goonClass:setFollower(value) self.follower = value end
function goonClass:getFollower() return self.follower end


function goonClass:setSeenBody(body, seen)
	self.seenBodies[body] = seen
end

function goonClass:makeFallen()
	self.unconscious = true
end

function goonClass:_die()
	self.dead = true
	self.weapon = nil
	self.keycard = nil
	self.keychain = nil
end

function goonClass:_choke()
	self.unconscious = true
	self.weapon = nil
	self.keycard = nil
	self.keychain = nil
end

function goonClass:onBodyDropped()
	self.bodyDropped = true
end


function actor.getClassData(class)
	return class == "goon" and goonClass or nil
end

local cameraClass = {}
function cameraClass:calculateDetectionIncrease(object, dt)
	return dt * 10
end
function cameraClass:disrupt()
	self.disrupted = true
end
function cameraClass:breakCam()
	self.destroyed = true
end

objects = {}
function objects.getClassData(class)
	return class == "security_camera" and cameraClass or nil
end

function objects.getClassID(class)
	return class
end

playerActor = {}
playerActor.EVENTS = {
	FIRED_WEAPON = 11
}

function playerActor:getOfflimits()
	return self.offlimits or npcAlertnessStates.STATES.IDLE
end
function playerActor:getOfflimitsActive()
	return self:getOfflimits() > npcAlertnessStates.STATES.IDLE
end
function playerActor:postDraw() return end

local player = {
	id = "player",
	PLAYER = true,
	class = {PLAYER = true},
	animVar = "sean",
	offlimits = npcAlertnessStates.STATES.ALERT,
	aiming = false,
	sprinting = false,
	weapon = nil,
	weaponConcealed = true,
	keys = {},
	x = 0,
	y = 0,
	state = {id = "player_main"}
}
setmetatable(player, {__index = playerActor})

function player:getID() return self.id end
function player:getPos() return self.x, self.y end
function player:getCenter() return self.x, self.y end
function player:getFixture()
	self.fixture = self.fixture or {owner = self}
	return self.fixture
end
function player:getState() return self.state end
function player:getAiming() return self.aiming end
function player:getSprinting() return self.sprinting end
function player:getWeapon() return self.weapon end
function player:getWeaponConcealed() return self.weaponConcealed end
function player:getAnimVariant() return self.animVar end
function player:setAnimVariant(value) self.animVar = value end
function player:hasKey(key)
	for index, value in ipairs(self.keys) do
		if value == key then return index end
	end

	return false
end
function player:addKey(key) table.insert(self.keys, key) end
function player:getVisibility() return 1 end
function player:onEnemyLostSight() return end
function player:onSightedByEnemy() return end

game.playerActor = player

local function createRoute(id)
	local route = {id = id, points = {}}

	for index, x in ipairs({100, 500, 900}) do
		local point = {id = id .. "-" .. index, x = x, y = index * 20}
		function point:getID() return self.id end
		function point:getPos() return self.x, self.y end
		table.insert(route.points, point)
	end

	function route:getID() return self.id end
	function route:getIndexes() return self.points end
	return route
end

local function createNPC(data)
	local npc = {
		class = data.class or "goon",
		id = data.id,
		dead = data.dead or false,
		unconscious = data.unconscious or false,
		patrol = data.patrol and createRoute("patrol-" .. data.id) or nil,
		patrolIndex = 1,
		radio = data.radio and {open = false, disrupted = false} or nil,
		experience = data.experience or 1,
		mapNameKey = data.mapNameKey or "",
		mapName = data.mapName or "",
		weapon = data.weapon == false and nil or {id = "weapon-" .. data.id, weaponType = data.weaponType or 2},
		keycard = data.keycard,
		keychain = data.keychain,
		animVar = data.animVar or "bandit1",
		detection = {},
		enemiesInSight = {},
		enemiesInSightMirror = {},
		closestEnemyDistance = math.huge,
		seenBodies = {},
		x = data.x or 100,
		y = data.y or 0,
		alertness = npcAlertnessStates.STATES.IDLE,
		health = 75,
		maxHealth = 75,
		states = {},
		grid = {},
		currentActionBitmask = 0
	}
	setmetatable(npc, {__index = goonClass})

	function npc.grid:worldToGrid(x, y) return x, y end
	function npc:isValid() return true end
	function npc:getClass() return self.class end
	function npc:getID() return self.id end
	function npc:getPos() return self.x, self.y end
	function npc:getCenter() return self.x, self.y end
	function npc:getFixture()
		self.fixture = self.fixture or {owner = self}
		return self.fixture
	end
	function npc:isDead() return self.dead end
	function npc:isUnconscious() return self.unconscious end
	function npc:getActivePatrolRoute() return self.patrol end
	function npc:setActivePatrolRoute(route, index) self.patrol, self.patrolIndex = route, index or 1 end
	function npc:getPatrolRouteIndex() return self.patrolIndex end
	function npc:setPatrolRouteIndex(index) self.patrolIndex = index end
	function npc:hasRadio() return self.radio ~= nil end
	function npc:getRadio() return self.radio end
	if npc.radio then
		function npc.radio:isOpen() return self.open end
		function npc.radio:isDisrupted() return self.disrupted end
		function npc.radio:open()
			if not self.disrupted then self.open = true end
		end
		function npc.radio:close() self.open = false end
	end
	function npc:getExperienceLevel() return self.experience end
	function npc:setExperienceLevel(value) self.experience = value end
	function npc:maxOutHealth() self.maxHealth, self.health = 95, 95 end
	function npc:getHealth() return self.health end
	function npc:setHealth(value) self.health = value end
	function npc:getMaxHealth() return self.maxHealth end
	function npc:setMaxHealth(value) self.maxHealth = value end
	function npc:getKeycard() return self.keycard end
	function npc:getKeychain() return self.keychain end
	function npc:getBlood() return self.blood or 30 end
	function npc:getWeapon() return self.weapon end
	if npc.weapon then
		function npc.weapon:getID() return self.id end
		function npc.weapon:getType() return self.weaponType end
	end
	function npc:dropWeapon() self.weapon = nil end
	function npc:getMapNameData() return self.mapNameKey, self.mapName end
	function npc:getAnimVariant() return self.animVar end
	function npc:setAnimVariant(value) self.animVar = value end
	function npc:getDetection(target) return self.detection[target] or 0 end
	function npc:setDetection(target, value) self.detection[target] = value end
	function npc:getAlertnessStateID() return self.alertness end
	function npc:getEnemyInSight(target)
		if target then return self.enemiesInSight[target:getID()] == true end
		return self.enemyInSight == true
	end
	function npc:getSeenPlayer() return self.seenPlayer == true or self.enemyInSight == true end
	function npc:updateVisionData()
		return {0, 0, 1, false, self.currentlySees == true}
	end
	function npc:isWithinView() return self.currentlySees == true end
	function npc:runGenericRaycast(_, _, _, _, target)
		if self.currentlySees == true then
			return {fixture = target:getFixture(), fraction = 1}
		end
		return {fixture = {blocked = true}, fraction = 0.5}
	end
	function npc:getBestHunchTime() return self.hunchTime or 999 end
	function npc:getBestHunch() return self.hunchX or self.x, self.hunchY or self.y end
	function npc:getSightPos() return self.hunchX or self.x, self.hunchY or self.y end
	function npc:setSightPos(x, y) self.hunchX, self.hunchY, self.hunchTime = x, y, 0 end
	function npc:setDestPos(x, y) self.destX, self.destY = x, y end
	function npc:setTargetPos(x, y) self.targetX, self.targetY = x, y end
	function npc:setPath(value) self.path = value end
	function npc:getDestPosObj()
		self.destObject = self.destObject or {owner = self, adjustResult = false}
		function self.destObject:adjust() return self.adjustResult end
		return self.destObject
	end
	function npc:getState()
		return self.state or self:getStateObject("goon_idle")
	end
	function npc:getStateObject(id)
		if not self.states[id] then
			local stateObject = {id = id, owner = self}
			self.states[id] = stateObject
			function stateObject:advanceDetection(target)
				self.owner:increaseDetection(target, 1)
				return true
			end
			function stateObject:onSightHitPlayer(target)
				self.owner:increaseDetection(target, 1)
				self.owner:setEnemyInSight(true, target)
				self.owner.nativeSightCombat = true
			end
			function stateObject:goToFollow(leader, followID)
				self.owner.following = leader
				self.owner.state = self.owner:getStateObject(followID or "goon_idle_following")
				leader:setFollower(self.owner)
			end
			if tostring(id):find("following", 1, true) then
				function stateObject:getWatchBack() return self.watchBack end
				function stateObject:setWatchBack(value) self.watchBack = value end
				function stateObject:getWatchDistance() return self.watchDistance end
				function stateObject:setWatchDistance(value) self.watchDistance = value end
			end
		end
		return self.states[id]
	end
	function npc:setState(value) self.state = value end
	function npc:receiveSightingData(source) self.receivedSightingFrom = source end
	function npc:updateInteractionList(interactor)
		local target = self._interactionList.options
		for _, option in ipairs(self.interactionList) do
			local available = not option.actionCheck or option.actionCheck(self, interactor)
			local active = bit.band(self.currentActionBitmask, option.id) == option.id
			if available and not active then
				table.insert(target, option)
				self.currentActionBitmask = self.currentActionBitmask + option.id
			elseif not available and active then
				for index = #target, 1, -1 do
					if target[index] == option then table.remove(target, index) end
				end
				self.currentActionBitmask = self.currentActionBitmask - option.id
			end
		end
	end
	function npc:getInteractOptions(interactor, update)
		if not self._interactionList then
			self._interactionList = {object = self, options = {}}
			self:updateInteractionList(interactor)
		elseif update then
			self:updateInteractionList(interactor)
		end
		return self._interactionList
	end
	function npc:postInteract(interactor)
		self.postInteractCount = (self.postInteractCount or 0) + 1
		self:updateInteractionList(interactor)
	end

	return npc
end

local namedStoryNPC = createNPC({id = "story-boss", patrol = true, experience = 3, mapName = "Story Boss", x = 200})
local stationaryNPC = createNPC({id = "stationary", patrol = false, experience = 1, weapon = false, animVar = "ped1", x = 250})
local validA = createNPC({id = "guard-a", patrol = true, experience = 2, keycard = "security-A", animVar = "bandit2", x = 130})
local validB = createNPC({id = "guard-b", patrol = true, experience = 3, radio = true, x = 150})
local validC = createNPC({id = "guard-c", patrol = true, experience = 2, radio = true, x = 170})
local validD = createNPC({id = "guard-d", patrol = true, experience = 2, x = 190})
local objectiveCritical = createNPC({id = "objective-critical", patrol = true, experience = 3, x = 210})
stationaryNPC.weapon = nil

local world = {
	mapID = "smoke-map",
	npcs = {namedStoryNPC, stationaryNPC, validA, validB, validC, validD, objectiveCritical}
}

function world:getMapID() return self.mapID end
function world:getNPCs() return self.npcs end
function world:getObjectsByClass() return {} end
function world:getActorTileOccupancy()
	return {
		adjustDestinationCoords = function(_, x, y) return x, y end
	}
end
game.worldObject = world

local mapData = {id = "smoke-map"}
function mapData:getID() return self.id end
maps = {registered = {mapData}}

local persistentData = {}
game.playthrough = {}
game.playthrough.money = 0
function game.playthrough:changeMoney(amount) self.money = self.money + amount end
function game.playthrough:getMoney() return self.money end
game.playthrough.finishedObjectives = {}
function game.playthrough:setPersistentMapData(key, value) persistentData[key] = value end
function game.playthrough:getPersistentMapData(key)
	if not persistentData[key] then error("missing") end
	return persistentData[key]
end
function game.playthrough:addFinishedObjective(id)
	table.insert(self.finishedObjectives, id)
end
function game.playthrough:hasFinishedObjective(id)
	for index, value in ipairs(self.finishedObjectives) do
		if value == id then return index end
	end

	return false
end

studio = nil

movePosIndicator = {
	EVENTS = {NOTIFY_OBJECTIVE_ID_REMOVE = 30},
	markers = {}
}
function movePosIndicator:addPosition(x, y, time, distance, class, unused, object, uid)
	local marker = {object = object, uid = uid}
	table.insert(self.markers, marker)
	return marker
end

gameStateService = {states = {}}
function gameStateService:addState(state) table.insert(self.states, state) end

local baseTask = {id = "base_task"}
function baseTask:init(objective)
	self.objective = objective
	self.baseTask = self
end
function baseTask:initConfig(config) self.config = config; self.uid = config.uid end
function baseTask:setHasStarted(value) self.hasStartedTask = value end
function baseTask:_onStart()
	if self.CATCHABLE_EVENTS then
		events:addDirectReceiver(self, self.CATCHABLE_EVENTS, "_handleEvent")
	end
end
function baseTask:_handleEvent(event, ...)
	self:handleEvent(event, ...)
	self.objective:doFinishCheck()
end
function baseTask:_onFinish()
	if self.CATCHABLE_EVENTS then
		events:removeDirectReceiver(self, self.CATCHABLE_EVENTS, "_handleEvent")
	end
end
function baseTask:isFinished() return self.completed end
function baseTask:verifyFinish() return self.completed end

objectiveHandler = {
	registeredTasksByID = {base_task = baseTask},
	registeredObjectivesByID = {},
	objectives = {}
}

local vanillaObjective = {
	id = "vanilla-story-objective",
	config = {task = {id = "neutralize_enemy", npc = "objective-critical"}}
}
function vanillaObjective:getID() return self.id end
function vanillaObjective:getTask() return {config = self.config.task} end
table.insert(objectiveHandler.objectives, vanillaObjective)

function objectiveHandler:registerNewTask(task, baseID)
	local base = self.registeredTasksByID[baseID]
	if base then setmetatable(task, {__index = base}); task.baseClass = base end
	self.registeredTasksByID[task.id] = task
end
function objectiveHandler:registerNewObjective(config) self.registeredObjectivesByID[config.id] = config; return config end
function objectiveHandler:getObjectiveData(id) return self.registeredObjectivesByID[id] end
function objectiveHandler:getObjectives() return self.objectives end
function objectiveHandler:createObjective(config)
	local object = {config = config, id = config.id, claimed = false}
	function object:getID() return self.id end
	function object:getTask() return self.task end
	function object:updateHUDElement() self.hudUpdates = (self.hudUpdates or 0) + 1 end
	function object:start() self.task:setHasStarted(true); self.task:_onStart() end
	function object:remove()
		for index = #objectiveHandler.objectives, 1, -1 do
			if objectiveHandler.objectives[index] == self then table.remove(objectiveHandler.objectives, index) end
		end
	end
	function object:fail() self.failed = true; self:remove() end
	function object:doFinishCheck()
		if self.task:verifyFinish() and not self.claimed then
			self.claimed = true
			-- HCO objectives intentionally have no native reward: the vanilla
			-- claimant depends on a hideout-only `studio` global.
			game.playthrough:addFinishedObjective(self.id)
			self.config:onFinish(self)
			self.task:_onFinish()
			self:remove()
		end
	end
	local taskClass = objectiveHandler.registeredTasksByID[config.task.id]
	local task = {}
	setmetatable(task, {__index = taskClass})
	task:init(object)
	task:initConfig(config.task)
	object.task = task
	return object
end

-- Reproduce the live checkpoint case: this body already owns a cached native
-- option list before HCO appends and enumerates its disguise action.
validA:getInteractOptions(player, false)

require("hco/bootstrap").start()

local state = playerActor._hitmanContractsOverhaulState
assertTrue(state, "shared state was not created")
assertEqual(state.targetID, "guard-b", "highest safe candidate selected")
assertEqual(state.target._hcoContractTarget, true, "target marker installed")
assertTrue(state.contract, "contract record created")
local activeProfile = require("hco/contracts/profiles").resolve(state.contract.seed, state.contract.archetype)
assertEqual(state.target.animVar, activeProfile.targetVariant, "target receives archetype-native visual variant")
assertEqual(#objectiveHandler.objectives, 2, "native objective injected beside vanilla objective")
assertTrue(state.targetMarker, "moving target marker attached")
assertTrue(objectiveHandler.objectives[2].config.startString, "native objective start indicator remains enabled after registration")
assertTrue(#state.escorts >= 2, "elite escort selected")
assertEqual(state.escorts[1].actor._hcoFactionVisual, activeProfile.visualIndex, "protection detail receives faction identity")
assertEqual(state.security.droneDoctrine.name, activeProfile.drone.name, "contract receives archetype-specific drone doctrine")
assertEqual(state.security.droneMode, "PATROL", "contract starts with passive drone patrol")
local followerLeader = state.target
local liveFollower = followerLeader:getFollower()
assertTrue(liveFollower and liveFollower._hcoFollowLeader == followerLeader, "close protection records native leader ownership")
assertTrue(type(liveFollower:getState().getWatchBack) == "function", "fresh close protection uses a follower-compatible state")
liveFollower:setState(liveFollower:getStateObject("goon_combat"))
assertEqual(followerLeader:getFollower(), nil, "leader releases HCO follower after combat state invalidates native follower instructions")
assertEqual(liveFollower._hcoFollowLeader, nil, "stale reverse follower ownership is cleared atomically")
local followerTickOK = pcall(function()
	local follower = followerLeader:getFollower()
	if follower then return follower:getState():getWatchBack() end
end)
assertTrue(followerTickOK, "native follower-instruction tick cannot call getWatchBack on a combat state")
assertEqual(#events.directReceivers[actor.EVENTS.DIED], 2, "lifecycle and objective death listeners")
local objectiveCriticalEntry
for _, entry in ipairs(state.lastSelectionReport.entries) do
	if entry.data.id == "objective-critical" then objectiveCriticalEntry = entry end
end
assertTrue(objectiveCriticalEntry and not objectiveCriticalEntry.eligible, "vanilla objective actor rejected")

local securityDirector = require("hco/security/director")
assertEqual(#state.security.guards, #state.escorts, "security roster remains contract-exclusive")

validA.hunchTime = 15
validA.hunchX, validA.hunchY = 340, 140
securityDirector.update(state, 1)
assertEqual(state.security.huntPhase, "LOCAL_REACTION", "weak fresh evidence starts local reaction")
validA.hunchTime = 999
validA.hunchX, validA.hunchY = nil, nil
state.security.knowledge = {}
state.security.lastKnown = nil
state.security.targetThreatLevel = 0
state.security.huntPhase = "STAND_DOWN"
state.security.searchOrderTime = 0

for _, guard in ipairs(state.security.guards) do
	if guard.actor == validA then
		guard.role = "close_protection"
	elseif guard.actor == validC then
		guard.role = "outer_security"
	elseif guard.actor == validD then
		guard.role = "response_unit"
	end
end
validA:setEnemyInSight(true, player)
validA.hunchX, validA.hunchY = 360, 160
securityDirector.update(state, 1)
assertEqual(state.security.huntPhase, "PRESSURE", "direct sighting starts pressure hunt")
assertTrue(state.security.dronesTriggeredByContact, "confirmed hostile contact triggers drone doctrine")
assertTrue((state.security.droneDeploymentRequested or 0) > 0, "contact queues physical drone deployment")
assertTrue(validC:getEnemyInSight(player) and validD:getEnemyInSight(player), "confirmed contact gives response guards explicit native target knowledge")
assertTrue(validA.destX == nil, "close protection remains with target during search")
validA:setEnemyInSight(false, player)
for _, npc in ipairs(world.npcs) do
	npc:setEnemyInSight(false, player)
	npc.seenPlayer = false
	npc.hunchTime = 999
	npc.hunchX, npc.hunchY = nil, nil
	npc.destX, npc.destY = nil, nil
end
state.security.knowledge = {}
state.security.lastKnown = nil
state.security.targetThreatLevel = 0
state.security.huntPhase = "STAND_DOWN"
state.security.searchOrderTime = 0

local disguiseOption = playerActor._hitmanContractsOverhaulState.hcoDisguiseInteraction
local restoreIdentityOption = playerActor._hitmanContractsOverhaulState.hcoDisguiseRestoreInteraction
assertEqual(goonClass.interactionList[1], disguiseOption, "take-disguise is the first native body action")
assertEqual(goonClass.interactionList[2], restoreIdentityOption, "restore-original-identity sits directly behind takeover")
assertEqual(disguiseOption.id, 1, "first disguise action receives the first native bit ID")
assertEqual(restoreIdentityOption.id, 2, "restore action receives its own native bit ID")
assertEqual(goonClass.actionTrackerID, 16, "native action tracker advances past both HCO options")
validA:_die()
assertEqual(validA.keycard, nil, "native death path drops live keycard before body interaction")
assertEqual(validA.weapon, nil, "native death path drops live weapon before body interaction")
local liveOptions = validA:getInteractOptions(player, true).options
local liveDisguiseOption
for _, option in ipairs(liveOptions) do
	if option._hcoInteraction == "hco_take_disguise_v1" then liveDisguiseOption = option end
end
assertEqual(liveDisguiseOption, disguiseOption, "cached live body menu receives disguise interaction")
assertEqual(liveOptions[1], disguiseOption, "take-disguise renders before native body actions")
assertTrue(disguiseOption.actionCheck(validA, player), "disguise interaction available on body")
local acquiredFaction = validA.animVar
local instantSightState = validC:getStateObject("goon_suspicion")
namedStoryNPC:setDetection(player, 1)
namedStoryNPC.seenPlayer = true
namedStoryNPC.lastVisionEnemy = player
namedStoryNPC.enemiesInSight[player:getID()] = true
liveDisguiseOption.interact(validA, player)
assertEqual(player.animVar, validA.animVar, "player inherits the contract faction disguise")
assertEqual(state.identityFX.kind, "acquired", "identity takeover starts a native world-space transition effect")
assertEqual(validA.postInteractCount, 1, "successful identity takeover refreshes native body menu")
local takeoverMenu = validA:getInteractOptions(player, true).options
assertEqual(takeoverMenu[1], restoreIdentityOption, "consumed source exposes restore-original as the first remaining identity action")
assertTrue(not disguiseOption.actionCheck(validA, player), "taken identity cannot be duplicated from the same body")
assertTrue(player:hasKey("security-A"), "body keycard granted")
assertEqual(namedStoryNPC:getDetection(player), 0, "unwitnessed identity takeover clears stale full native detection")
assertEqual(namedStoryNPC.seenPlayer, false, "unwitnessed identity takeover clears historical player identity")
assertEqual(namedStoryNPC.lastVisionEnemy, nil, "unwitnessed identity takeover clears stale native vision target")
player.weapon = {id = "player-sidearm", weaponType = 2}
function player.weapon:getID() return self.id end
function player.weapon:getType() return self.weaponType end
player.weaponConcealed = false
validC.animVar = acquiredFaction
validC:setDetection(player, 0)
validC:increaseDetection(player, 1)
assertTrue(validC:getDetection(player) < 0.5, "visible matching security weapon does not instantly reveal a fresh disguise")
validC:setDetection(player, 0)
validC.nativeSightCombat = false
instantSightState:onSightHitPlayer(player)
assertEqual(validC:getEnemyInSight(player), false, "native close-range sight cannot mark a calm fresh disguise hostile")
assertEqual(validC.nativeSightCombat, false, "native close-range sight bypass cannot enter combat through a calm disguise")
assertTrue(validC:getDetection(player) <= require("hco/config").DISGUISE_SOFT_DETECTION_CAP, "calm native sight remains below the identity-check boundary")
assertTrue(validC:getDetection(player) < 0.4, "calm social cover remains below native suspicion success")
validC:setEnemyInSight(true, player)
assertEqual(validC:getEnemyInSight(player), false, "hard native enemy-sight boundary rejects uninformed hostility")

validC.x = 60
validC.currentlySees = true
validC:setDetection(player, 0)
validC.nativeSightCombat = false
instantSightState:onSightHitPlayer(player)
assertTrue(state.localCompromisedDisguises[validC.id] and state.localCompromisedDisguises[validC.id][acquiredFaction], "point-blank visual inspection exposes the identity to that observer")
assertEqual(validC:getEnemyInSight(player), true, "point-blank recognition produces real native enemy knowledge")
assertEqual(validC.nativeSightCombat, true, "point-blank red recognition continues into native threaten or combat behavior")
assertEqual(state.identityFX.kind, "exposed", "local close-range exposure has its own readable world effect")
validC.x = 170
validC.currentlySees = false
state.localCompromisedDisguises[validC.id] = nil
state.pendingCompromises = {}
validC:setEnemyInSight(false, player)
validC:setDetection(player, 0)
validC.seenPlayer = false
validC.nativeSightCombat = false

validD.x = 120
validD.currentlySees = true
validD:setState(validD:getStateObject("goon_suspicion"))
require("hco/social/disguise").update(state, 0.25)
assertTrue(not state.localCompromisedDisguises[validD.id], "brief non-point-blank proximity starts scrutiny without instant exposure")
for step = 1, 12 do require("hco/social/disguise").update(state, 0.25) end
assertTrue(state.localCompromisedDisguises[validD.id] and state.localCompromisedDisguises[validD.id][acquiredFaction], "sustained close inspection exposes even a calm armed disguise")
assertEqual(validD:getEnemyInSight(player), true, "completed close inspection hands control back to native combat")
validD.x = 190
validD.currentlySees = false
state.localCompromisedDisguises[validD.id] = nil
state.pendingCompromises = {}
state.closeScrutiny = {}
validD:setEnemyInSight(false, player)
validD:setDetection(player, 0)
validD.seenPlayer = false
validD.nativeSightCombat = false

namedStoryNPC.x = 120
namedStoryNPC.currentlySees = true
require("hco/social/disguise").update(state, 0.5)
assertTrue(state.closeScrutiny[namedStoryNPC.id] and state.closeScrutiny[namedStoryNPC.id].time > 0, "close visual contact accumulates observer-local scrutiny")
namedStoryNPC.currentlySees = false
require("hco/social/disguise").update(state, 0.4)
assertEqual(state.closeScrutiny[namedStoryNPC.id], nil, "breaking visual contact drains partial scrutiny")
namedStoryNPC.currentlySees = true
require("hco/social/disguise").update(state, 1)
assertTrue(not state.localCompromisedDisguises[namedStoryNPC.id], "re-entering after scrutiny decays does not inherit a completed check")
namedStoryNPC.x = 200
namedStoryNPC.currentlySees = false
state.closeScrutiny = {}

player.aiming = true
instantSightState:onSightHitPlayer(player)
assertEqual(validC:getEnemyInSight(player), true, "directly aiming at a guard permits native recognition")
assertEqual(validC.nativeSightCombat, true, "overtly hostile behavior permits the original native combat transition")
player.aiming = false
validC:setEnemyInSight(false, player)
validC.seenPlayer = false
validC.nativeSightCombat = false
namedStoryNPC:setDetection(player, 0)
player.weapon.weaponType = 1
namedStoryNPC:increaseDetection(player, 1)
assertTrue(namedStoryNPC:getDetection(player) < 0.5, "held weapon model and family do not affect an otherwise credible disguise")
npcAlertnessStates.inCombat = true
namedStoryNPC:setDetection(player, 0)
namedStoryNPC:increaseDetection(player, 1)
assertTrue(namedStoryNPC:getDetection(player) < 0.5, "global combat elsewhere does not give an uninformed observer magical identity knowledge")
npcAlertnessStates.inCombat = false
namedStoryNPC.seenPlayer = true
events:fire(playerActor.EVENTS.FIRED_WEAPON)
assertTrue(not state.localCompromisedDisguises[namedStoryNPC.id], "past sight memory cannot turn an unobserved shot into identity knowledge")
namedStoryNPC.currentlySees = true
events:fire(playerActor.EVENTS.FIRED_WEAPON)
namedStoryNPC:setDetection(player, 0)
namedStoryNPC:increaseDetection(player, 1)
assertEqual(namedStoryNPC:getDetection(player), 1, "direct firing witness recognizes the disguised shooter locally")
namedStoryNPC.currentlySees = false
state.localCompromisedDisguises[namedStoryNPC.id] = nil
player.weapon = nil
player.weaponConcealed = true
curTime = curTime + 3.1
assertEqual(player:getOfflimits(), npcAlertnessStates.STATES.IDLE, "keycard disguise grants access reduction")
assertEqual(player:getOfflimitsActive(), false, "native trespass-active query agrees with disguise-adjusted access")

validD:getInteractOptions(player, false)
validD._hcoOriginalExperience = goonClass.EXPERIENCE_LEVELS.ELITE
validD.keychain = "elite-chain"
validD:makeFallen()
local fallenOptions = validD:getInteractOptions(player, false).options
local fallenHasDisguise = false
for _, option in ipairs(fallenOptions) do
	if option._hcoInteraction == "hco_take_disguise_v1" then fallenHasDisguise = true end
end
assertTrue(fallenHasDisguise, "native makeFallen hook refreshes an already-cached body menu")
validD.unconscious = false
validD:getInteractOptions(player, true)

local selectedBeforeReload = state.targetID
local objectiveCountBeforeReload = #objectiveHandler.objectives
events:fire(game.EVENTS.RESET_STARTED)
assertEqual(state.target, nil, "reset start clears actor references")
assertEqual(player.animVar, "sean", "reset cleanup restores player visual")
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.targetID, selectedBeforeReload, "active contract rebinds same target")
assertEqual(state.disguise.group, acquiredFaction, "active disguise restored from campaign persistence")
assertEqual(player.animVar, acquiredFaction, "restored disguise is visible")
assertEqual(state.disguise.originalAnimVar, "sean", "reload preserves the real pre-disguise player appearance")
assertEqual(state.identityFX.kind, "restored", "reload starts a restrained identity-restored effect")
assertTrue(not disguiseOption.actionCheck(validA, player), "used identity source remains consumed after checkpoint reload")
assertEqual(#objectiveHandler.objectives, objectiveCountBeforeReload, "active reload does not duplicate objective")
require("hco/social/disguise").update(state, 0.1)
assertTrue(state.disguiseRisk < 1, "calm restored disguise publishes reduced semantic risk for networked sensors")

validC.animVar = acquiredFaction
validC:setDetection(player, 0)
validC:increaseDetection(player, 1)
assertTrue(validC:getDetection(player) < 1, "matching disguise delays visual detection")
local normalPlayerState = player.state
player.state = {id = "player_breaking_lock"}
validC:setDetection(player, 0)
validC:increaseDetection(player, 1)
assertEqual(validC:getDetection(player), 1, "native lock-breaking state immediately defeats social cover")
player.state = {id = "player_reloading"}
validC:setDetection(player, 0)
validC:increaseDetection(player, 1)
assertTrue(validC:getDetection(player) < 0.5, "ordinary reloading does not defeat an armed identity")
player.state = normalPlayerState

validC:setDetection(player, 0.5)
state.identityCheckTime = 0
require("hco/social/disguise").update(state, 0.1)
local identityCheck
for _, pending in ipairs(state.pendingCompromises) do
	if pending.kind == "identity-check" then identityCheck = pending end
end
assertTrue(identityCheck ~= nil and validC.radio.open, "same-unit scrutiny opens a real interruptible radio identity check")
validC.radio.disrupted = true
require("hco/social/disguise").update(state, 0.1)
assertTrue(not state.disguise.compromised, "disrupting identity-check radio prevents compromise")
validC.radio.disrupted = false
validC.radio.open = false
state.pendingCompromises = {}
namedStoryNPC.x = 1000
namedStoryNPC.animVar = acquiredFaction
local evidenceObserver = createNPC({id = "evidence-observer", radio = true, animVar = acquiredFaction, x = 170})
evidenceObserver:setSeenBody(validA, true)
assertTrue(not state.disguise.compromised, "body discovery is local before radio completes")
assertEqual(evidenceObserver.radio.open, true, "body investigator starts native radio report")
evidenceObserver:setDetection(player, 0)
evidenceObserver:increaseDetection(player, 1)
assertEqual(evidenceObserver:getDetection(player), 1, "investigator recognizes locally compromised disguise")
namedStoryNPC:setDetection(player, 0)
namedStoryNPC:increaseDetection(player, 1)
assertTrue(namedStoryNPC:getDetection(player) < 1, "distant uninformed guard still accepts disguise")

for step = 1, 3 do
	curTime = curTime + 1
	for _, updateState in ipairs(gameStateService.states) do updateState:update(1) end
end
assertTrue(state.disguise.compromised, "completed radio call globally compromises disguise")
assertEqual(evidenceObserver.radio.open, false, "HCO closes its completed radio report")
namedStoryNPC:setDetection(player, 0)
namedStoryNPC:increaseDetection(player, 1)
assertEqual(namedStoryNPC:getDetection(player), 1, "radio recipients reject compromised disguise")
state.disguise.compromised = false
state.compromisedDisguises[acquiredFaction] = nil
assertTrue(require("hco/social/disguise").onSensorBodySeen(state, {id="drone-sensor"}, validA), "drone body scan recognizes the stolen uniform source")
assertTrue(state.disguise.compromised and state.compromisedDisguises[acquiredFaction], "networked drone evidence globally compromises the stolen identity")

stationaryNPC.dead = true
stationaryNPC.blood = 15
local staffVariant = stationaryNPC.animVar
assertTrue(disguiseOption.actionCheck(stationaryNPC, player), "staff body exposes identity switch")
validD.currentlySees = true
disguiseOption.interact(stationaryNPC, player)
assertEqual(state.disguise.tier, "staff", "unarmed civilian body produces staff access tier")
assertTrue(state.disguise.bloodied, "damaged source records a bloodied uniform condition")
assertEqual(player.animVar, staffVariant, "switch identity changes the visible player variant again")
assertTrue(state.compromisedDisguises[acquiredFaction], "changing identity preserves compromise knowledge for the old uniform")
assertTrue(state.localCompromisedDisguises[validD.id][staffVariant], "a real takeover eyewitness locally recognizes the new identity")
validD.currentlySees = false

validD.unconscious = true
local eliteVariant = validD.animVar
assertTrue(disguiseOption.actionCheck(validD, player), "elite body exposes another identity switch")
disguiseOption.interact(validD, player)
assertEqual(state.disguise.tier, "elite_security", "elite source produces elite security access tier")
assertEqual(player.animVar, eliteVariant, "elite identity is visibly applied")
assertTrue(player:hasKey("elite-chain"), "native keychain credentials are copied")
assertTrue(restoreIdentityOption.actionCheck(validD, player), "active disguise exposes an explicit native restore action")

state.security.knowledge = {}
state.security.targetThreatLevel = 0
state.targetAI.phase = "ROUTINE"
state.targetAI.resumePhase = nil
state.targetAI.safePoint = nil
local routineRecoveries = state.targetAI.routineRecoveries or 0
for step = 1, 10 do require("hco/targets/controller").update(state, 1) end
assertTrue(state.targetAI.routineRecoveries > routineRecoveries, "stationary routine target is advanced to another native patrol node")

state.target.alertness = npcAlertnessStates.STATES.ALERT
state.target:setState(state.target:getStateObject("goon_alert"))
state.target.hunchTime = 0
state.target.hunchX, state.target.hunchY = player.x, player.y
state.security.knowledge = {}
state.security.targetThreatLevel = 0
state.targetAI.phase = "ROUTINE"
state.targetAI.resumePhase = nil
state.targetAI.safePoint = nil
state.targetAI.threatTime = 0
state.targetAI.clearTime = 0
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.2) end
assertEqual(state.security.targetThreatLevel, 0, "native alert color alone is not disguised-player identity knowledge")
assertEqual(state.targetAI.phase, "ROUTINE", "uninformed target does not flee from a valid nearby disguise")
local targetX, targetY = state.target:getPos()
player.x, player.y = targetX + 100, targetY
securityDirector.notifyPlayerGunfire(state, player)
require("hco/targets/controller").update(state, 0.6)
assertEqual(state.targetAI.phase, "UNEASY", "one nearby audible shot moves the principal without identifying the shooter")
assertTrue(state.targetAI.safePoint, "secure destination selected")
state.security.targetThreatLevel = 1
require("hco/targets/controller").update(state, 0.2)
assertEqual(state.targetAI.phase, "THREATENED", "confirmed protection incident escalates the principal from relocation to flight")

state.target.x, state.target.y = state.targetAI.safePoint.x, state.targetAI.safePoint.y
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.2) end
assertEqual(state.targetAI.phase, "SHELTERED", "target physically reaches selected shelter")
local breachedPoint = state.targetAI.safePoint
local switchCount = state.targetAI.secureSwitches
local camera = setmetatable({x = breachedPoint.x, y = breachedPoint.y}, {__index = cameraClass})
function camera:getPos() return self.x, self.y end
camera:disrupt()
assertEqual(state.security.evidencePositions[#state.security.evidencePositions].source, "camera-disrupted", "camera disruption creates sensor evidence")
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.2) end
assertTrue(state.targetAI.secureSwitches > switchCount, "compromised shelter triggers a new secure move")
assertTrue(state.targetAI.safePoint.x ~= breachedPoint.x or state.targetAI.safePoint.y ~= breachedPoint.y, "target abandons breached shelter")

player.x = -1000
state.target.x = 2500
local recoveryBefore = state.targetAI.recoveries
for step = 1, 13 do
	curTime = curTime + 1
	for _, updateState in ipairs(gameStateService.states) do updateState:update(1) end
end
assertTrue(state.targetAI.recoveries > recoveryBefore, "blocked route triggers watchdog recovery within ten seconds")

restoreIdentityOption.interact(validD, player)
assertEqual(state.disguise, nil, "native restore action removes the active disguise")
assertEqual(player.animVar, "sean", "native restore action reapplies the original player appearance")
assertTrue(state.usedDisguiseSources[validA.id] and state.usedDisguiseSources[validD.id], "removing clothes does not make consumed identities reusable")
assertEqual(state.contract.disguiseGroup, nil, "removed disguise is cleared from campaign persistence")
assertEqual(state.identityFX.kind, "restored", "removing a disguise plays the world-space restore transition")

events:fire(actor.EVENTS.NEUTRALIZED, state.target)
assertEqual(state.contract.status, "completed", "contract completed")
assertEqual(state.contract.rewardPaid, true, "reward settlement persisted")
assertEqual(state.targetStatus, "completed", "neutralization alone resolves objective")
assertEqual(game.playthrough.money, state.contract.resolvedReward, "exactly one campaign reward paid")

local paidReward = game.playthrough.money
state.target.dead = true
events:fire(actor.EVENTS.DIED, state.target, player)
assertEqual(game.playthrough.money, paidReward, "death after neutralization cannot pay twice")

events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "completed contract does not respawn after reload")
assertEqual(#objectiveHandler.objectives, 1, "no duplicate objective inserted")

world.mapID = "iv2_hideout"
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "unsupported hideout quietly skips contract")

world.mapID = "empty-custom-map"
world.npcs = {}
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "custom map without NPCs quietly skips contract")

local function resetNPC(npc, x)
	npc.dead = false
	npc.unconscious = false
	npc.patrol = createRoute("patrol-" .. npc.id)
	npc.patrolIndex = 1
	npc.state = nil
	npc.alertness = npcAlertnessStates.STATES.IDLE
	npc.enemyInSight = false
	npc.hunchTime = 999
	npc.x = x
	npc.y = 0
	npc._hcoDisguiseTaken = nil
	if not npc.weapon then
		npc.weapon = {id = "weapon-" .. npc.id, weaponType = 2}
		function npc.weapon:getID() return self.id end
		function npc.weapon:getType() return self.weaponType end
	end
end

resetNPC(validA, 130)
resetNPC(validB, 150)
resetNPC(validC, 170)
resetNPC(validD, 190)
world.mapID = "objective-failure-map"
world.npcs = {namedStoryNPC, stationaryNPC, validA, validB, validC, validD, objectiveCritical}
local activeObjectives = objectiveHandler.objectives
objectiveHandler.objectives = nil
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "objective attach failure rolls back target mutation")
assertEqual(state.contract, nil, "objective attach failure clears partial runtime contract")
assertEqual(validA._hcoEscort, nil, "objective attach failure rolls back escort role")
assertEqual(validA.experience, 2, "objective attach failure restores guard experience")
assertEqual(validA.health, 75, "objective attach failure restores guard health")
assertEqual(validA.maxHealth, 75, "objective attach failure restores guard maximum health")
assertEqual(validA:getState().id, "goon_idle", "objective attach failure restores guard state")
assertEqual(validB:getPatrolRouteIndex(), 1, "objective attach failure restores target patrol position")
objectiveHandler.objectives = activeObjectives

resetNPC(validA, 130)
resetNPC(validB, 150)
resetNPC(validC, 170)
resetNPC(validD, 190)
world.mapID = "escape-map"
world.npcs = {namedStoryNPC, stationaryNPC, validA, validB, validC, validD, objectiveCritical}
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.targetID, "guard-b", "escape scenario creates deterministic contract")

validA.dead = true
disguiseOption.interact(validA, player)
validC.radio.disrupted = true
validC.animVar = acquiredFaction
validC:setSeenBody(validA, true)
for step = 1, 9 do
	curTime = curTime + 1
	for _, updateState in ipairs(gameStateService.states) do updateState:update(1) end
end
assertTrue(not state.disguise.compromised, "disrupted radio prevents global disguise compromise")
validC.radio.disrupted = false

local moneyBeforeEscape = game.playthrough.money
state.target.alertness = npcAlertnessStates.STATES.ALERT
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.6) end
for _, escortData in ipairs(state.escorts) do
	escortData.actor.dead = true
end
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.2) end
assertEqual(state.targetAI.phase, "EVACUATING", "sustained threat starts physical evacuation")
assertTrue(state.targetAI.safePoint, "evacuation owns a physical destination")
state.target.x, state.target.y = state.targetAI.safePoint.x, state.targetAI.safePoint.y
for _, updateState in ipairs(gameStateService.states) do updateState:update(0.2) end
assertEqual(state.contract.status, "failed_escaped", "reaching evacuation fails optional contract")
assertEqual(game.playthrough.money, moneyBeforeEscape, "escaped target grants no reward")

events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "escaped contract remains terminal after reload")

local function runDirectDeathScenario(mapID, attacker, label)
	resetNPC(validA, 130)
	resetNPC(validB, 150)
	resetNPC(validC, 170)
	resetNPC(validD, 190)
	world.mapID = mapID
	world.npcs = {namedStoryNPC, stationaryNPC, validA, validB, validC, validD, objectiveCritical}
	events:fire(game.EVENTS.RESET_STARTED)
	events:fire(game.EVENTS.RESET_FINISHED)
	assertTrue(state.target, label .. " starts a contract")
	local moneyBefore = game.playthrough.money
	state.target.dead = true
	events:fire(actor.EVENTS.DIED, state.target, attacker)
	assertEqual(state.contract.status, "completed", label .. " completes directly from death")
	assertTrue(game.playthrough.money > moneyBefore, label .. " pays campaign reward")
	local paid = game.playthrough.money
	events:fire(actor.EVENTS.DIED, state.target, attacker)
	assertEqual(game.playthrough.money, paid, label .. " cannot pay twice")
end

runDirectDeathScenario("environment-kill-map", nil, "environmental kill")
runDirectDeathScenario("npc-kill-map", validC, "NPC kill")

resetNPC(validA, 130)
resetNPC(validB, 150)
resetNPC(validC, 170)
resetNPC(validD, 190)
world.mapID = "invalid-map"
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
local invalidTarget = state.target
assertTrue(invalidTarget, "invalid-reference scenario starts active")
events:fire(game.EVENTS.RESET_STARTED)
local remaining = {}
for _, npc in ipairs(world.npcs) do
	if npc ~= invalidTarget then table.insert(remaining, npc) end
end
world.npcs = remaining
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(state.target, nil, "missing saved target is never rerolled")
assertEqual(state.contract.status, "failed_invalid", "missing saved target fails closed")

-- Large-map migration: two targets, isolated guards, objective slots and v3 bundle.
local hcoConfig = require("hco/config")
hcoConfig.TWO_CONTRACT_ACTOR_THRESHOLD = 12
hcoConfig.THREE_CONTRACT_ACTOR_THRESHOLD = 99
world.mapID = "multi-contract-map"
world.npcs = {}
for index = 1, 20 do
	table.insert(world.npcs, createNPC({id = "multi-" .. tostring(index), patrol = true, experience = index % 3 + 1, radio = index % 4 == 0, x = 100 + index * 55, y = 180 + (index % 4) * 45}))
end
events:fire(game.EVENTS.RESET_STARTED)
events:fire(game.EVENTS.RESET_FINISHED)
assertEqual(#state.contracts, 2, "large map creates two contract contexts")
assertTrue(state.contracts[1].target ~= state.contracts[2].target, "contract targets remain unique")
local assigned = {}
for _, context in ipairs(state.contracts) do
	assertTrue(#context.escorts >= 5, "every large-map contract receives a heavy protection detail")
	local responseLookup = {}
	for _, data in ipairs(context.escorts) do
		assertTrue(not assigned[data.actor], "guard is never shared between contract details")
		assigned[data.actor] = true
		if data.role == "response_unit" then
			responseLookup[data.actor] = true
			assertTrue(data.actor.following == nil, "response unit remains autonomous instead of entering a follower state")
		end
	end
	for _, leader in ipairs(context.escorts) do
		assertTrue(not responseLookup[leader.actor:getFollower()], "no close-protection leader retains a response unit as native follower")
	end
	assertTrue(not responseLookup[context.target:getFollower()], "protected target never retains a response unit as native follower")
end
local multiRecords = require("hco/contracts/persistence").loadAll("multi-contract-map")
assertEqual(#multiRecords, 2, "persistence v3 stores both contracts")

local suppressedWeapon = {owner=game.playerActor, getSuppressed=function() return true end}
events:fire(weapons.EVENTS.FIRED, suppressedWeapon)
events:fire(weapons.EVENTS.FIRED, suppressedWeapon)
events:fire(weapons.EVENTS.FIRED, suppressedWeapon)
assertTrue(not state.security.dronesTriggeredByGunfire, "suppressed player fire preserves passive patrol")
local loudWeapon = {owner=game.playerActor, getSuppressed=function() return false end}
events:fire(weapons.EVENTS.FIRED, loudWeapon)
events:fire(weapons.EVENTS.FIRED, loudWeapon)
events:fire(weapons.EVENTS.FIRED, loudWeapon)
assertTrue(state.security.dronesTriggeredByGunfire, "loud player fire triggers drone escalation")
assertEqual(state.security.droneMode, "AGGRESSIVE", "loud player fire switches drones to aggressive search")
assertEqual(state.security.lastKnown.actor, nil, "sound-only escalation stores a search position without the player's identity")
for _, data in ipairs(state.security.guards) do
	if data.role ~= "close_protection" then
		assertTrue(data.actor.enemyInSight ~= true, "sound-only escalation never marks response guards as seeing the player")
	end
end

require("hco/bootstrap").start()
assertEqual(#events.directReceivers[game.EVENTS.MAP_LOADED], 1, "duplicate lifecycle listener prevented")

events:fire(game.EVENTS.GAME_UNLOADED)
assertEqual(state.target, nil, "target released on unload")

local balance = require("hco/balance")
game.difficulty = {id="easy_real"}
local easyTuning = balance.snapshot({threatRating=3})
assertEqual(easyTuning.threatLabel, "II", "easy difficulty lowers the native contract threat rating")
assertTrue(easyTuning.detectionTimeScale > 1 and easyTuning.droneCountScale < 1, "easy difficulty slows acquisition and reduces wings")
game.difficulty = {id="true"}
local trueTuning = balance.snapshot({threatRating=3})
assertEqual(trueTuning.threatLabel, "IV", "True difficulty raises the native contract threat rating")
assertTrue(trueTuning.detectionTimeScale < 1 and trueTuning.rewardScale > 1, "True difficulty increases pressure and reward")
game.difficulty = {id="custom",enemyVisRangeMult=1.4,playerDamageMult=1.5}
local customTuning = balance.snapshot({threatRating=3})
assertTrue(customTuning.sensorRangeScale==1.4 and customTuning.rewardScale>1, "custom difficulty fields produce bounded adaptive tuning")
game.difficulty = nil

print("HCO_RUNTIME_SMOKE_PASS")
love = love or {}
love.event = love.event or {quit=function() end}
function love.update() love.event.quit(0) end
