local config = require("hco/config")
local disguise = require("hco/social/disguise")
local securityDirector = require("hco/security/director")
local stateModule = require("hco/state")
local util = require("hco/util")

local sensors = {}

function sensors.initialize(state)
	state.hooks = state.hooks or {}

	if state.hooks.cameraDetection then
		return
	end

	local cameraClass = objects.getClassData and objects.getClassData("security_camera")

	if not cameraClass or type(cameraClass.calculateDetectionIncrease) ~= "function" then
		util.log(config, "security-camera disguise hook unavailable; cameras retain vanilla behavior")

		return
	end

	state.hooks.cameraDetection = cameraClass.calculateDetectionIncrease
	local original = cameraClass.calculateDetectionIncrease

	function cameraClass:calculateDetectionIncrease(object, dt)
		local amount = original(self, object, dt)

		if object == game.playerActor and state.disguise and state.contract then
			local risk = disguise.getBehaviorRisk(state, object)
			local thermalMode = state.targetAI and state.targetAI.phase ~= "ROUTINE"
			local factor = thermalMode and math.max(0.75, risk) or math.max(config.DISGUISE_BASE_DETECTION, risk)

			return amount * factor
		end

		return amount
	end

	if not state.hooks.cameraDisrupt and type(cameraClass.disrupt) == "function" then
		state.hooks.cameraDisrupt = cameraClass.disrupt
		local originalDisrupt = cameraClass.disrupt

		function cameraClass:disrupt(...)
			local result = originalDisrupt(self, ...)

			for _, context in ipairs(stateModule.getContexts(state)) do securityDirector.notifySensorEvidence(context, self, "camera-disrupted") end

			return result
		end
	end

	if not state.hooks.cameraBreak and type(cameraClass.breakCam) == "function" then
		state.hooks.cameraBreak = cameraClass.breakCam
		local originalBreak = cameraClass.breakCam

		function cameraClass:breakCam(...)
			local result = originalBreak(self, ...)

			for _, context in ipairs(stateModule.getContexts(state)) do securityDirector.notifySensorEvidence(context, self, "camera-destroyed") end

			return result
		end
	end
end

return sensors
