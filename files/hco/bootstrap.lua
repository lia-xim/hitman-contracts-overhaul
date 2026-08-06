local config = require("hco/config")
local contractObjective = require("hco/contracts/objective")
local lifecycle = require("hco/lifecycle")
local runtime = require("hco/runtime")
local sensors = require("hco/security/sensors")
local drones = require("hco/security/drones")
local disguise = require("hco/social/disguise")
local stateModule = require("hco/state")
local util = require("hco/util")
local visuals = require("hco/visuals")

local bootstrap = {}

local function startSubsystem(state, name, callback)
	local ok, err = pcall(callback, state)

	if not ok then
		state.bootstrapErrors = state.bootstrapErrors or {}
		state.bootstrapErrors[name] = tostring(err)
		util.log(config, "startup subsystem disabled name=" .. tostring(name) .. " error=" .. tostring(err))
	end

	return ok
end

function bootstrap.start()
	local state = stateModule.acquire()
	local previousVersion = state.version

	if previousVersion and previousVersion ~= config.VERSION then
		util.log(config, "version collision detected active=" .. tostring(previousVersion) .. " requested=" .. tostring(config.VERSION) .. "; remove duplicate local/Workshop copies if behavior differs")
	end

	state.version = config.VERSION
	state.bootstrapErrors = {}

	local objectiveReady = startSubsystem(state, "contract-objective", contractObjective.initialize)
	startSubsystem(state, "search-drones", drones.initialize)
	startSubsystem(state, "faction-visuals", visuals.initialize)
	startSubsystem(state, "disguise", disguise.initialize)
	startSubsystem(state, "sensors", sensors.initialize)
	startSubsystem(state, "runtime", runtime.install)
	startSubsystem(state, "lifecycle", lifecycle.start)

	if objectiveReady then
		util.log(config, "Hitman Contracts Overhaul " .. config.VERSION .. " loaded; native contract core active")
	else
		util.log(config, "Hitman Contracts Overhaul " .. config.VERSION .. " loaded in safe degraded mode; contracts disabled")
	end

	return state
end

return bootstrap
