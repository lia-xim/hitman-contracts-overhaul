local sourceRoot = os.getenv("HCO_SOURCE_ROOT")
if not sourceRoot or sourceRoot == "" then error("HCO_SOURCE_ROOT is required") end
package.path = sourceRoot .. "/?.lua;" .. sourceRoot .. "/?/init.lua;" .. package.path

function love.errorhandler(message)
	io.stderr:write("HCO_BOOT_SMOKE_ERROR: " .. tostring(message) .. "\n" .. debug.traceback() .. "\n")
	os.exit(1)
end

local function assertTrue(value, label)
	if not value then
		error(label or "expected truthy value")
	end
end

events = {receivers = {}}
function events:addDirectReceiver(object, list)
	for _, event in ipairs(list) do
		self.receivers[event] = self.receivers[event] or {}
		table.insert(self.receivers[event], object)
	end
end
function events:fire() return end

game = {
	EVENTS = {
		MAP_LOADED = 1,
		RESET_STARTED = 2,
		RESET_FINISHED = 3,
		GAME_UNLOADED = 4,
		RETURNING_TO_MAIN_MENU = 5,
		PRE_REMOVE_GAME = 6,
		LEVEL_FINISHED = 7,
		PLAYER_SET = 8,
		POST_MODS_LOADED = 9
	},
	worldObject = nil,
	playerActor = nil
}

actor = {
	EVENTS = {NEUTRALIZED = 10, DIED = 11},
	getClassData = function() return nil end
}
playerActor = {EVENTS = {FIRED_WEAPON = 12}}
objects = {getClassData = function() return nil end}
gameStateService = {states = {}}
function gameStateService:addState(state) table.insert(self.states, state) end

require("hco/bootstrap").start()

local state = playerActor._hitmanContractsOverhaulState
assertTrue(state, "sandbox-safe shared state created without _G dependency")
assertTrue(state.runtimeInstalled, "runtime update state survives absent world")
assertTrue(state.listenerInstalled, "lifecycle listener survives absent world")
assertTrue(state.bootstrapErrors and state.bootstrapErrors["contract-objective"], "missing objective subsystem is isolated")
assertTrue(state.bootstrapErrors and state.bootstrapErrors.disguise, "missing disguise subsystem is isolated")

print("HCO_BOOT_FAILURE_ISOLATION_PASS")
love = love or {event={quit=function() end}}
love.event = love.event or {quit=function() end}
function love.update() love.event.quit(0) end
