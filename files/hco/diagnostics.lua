local config = require("hco/config")
local util = require("hco/util")

local diagnostics = {}

local function boolText(value)
	return value and "yes" or "no"
end

function diagnostics.snapshot(npc)
	local _, isDead = util.call(npc, "isDead")
	local _, isUnconscious = util.call(npc, "isUnconscious")
	local _, patrolRoute = util.call(npc, "getActivePatrolRoute")
	local _, patrolPoints = util.call(patrolRoute, "getIndexes")
	local _, hasRadio = util.call(npc, "hasRadio")
	local _, experience = util.call(npc, "getExperienceLevel")
	local _, keycard = util.call(npc, "getKeycard")
	local _, weapon = util.call(npc, "getWeapon")
	local _, follower = util.call(npc, "getFollower")
	local _, mapNameKey, mapName = util.call(npc, "getMapNameData")
	local _, stateObject = util.call(npc, "getState")

	return {
		id = util.getID(npc) or "missing",
		class = util.getClass(npc),
		dead = isDead == true,
		unconscious = isUnconscious == true,
		patrol = util.describeReference(patrolRoute),
		hasPatrol = patrolRoute ~= nil,
		patrolPointCount = type(patrolPoints) == "table" and #patrolPoints or 0,
		radio = hasRadio == true,
		experience = tonumber(experience) or 0,
		keycard = util.describeReference(keycard),
		weapon = util.describeReference(weapon),
		follower = util.describeReference(follower),
		mapNameKey = util.cleanText(mapNameKey),
		mapName = util.cleanText(mapName),
		stateID = stateObject and tostring(stateObject.id or stateObject.ID or "unknown") or "unknown"
	}
end

function diagnostics.printReport(mapID, report)
	if not config.DIAGNOSTICS_ENABLED then
		return
	end

	util.log(config, "probe map=" .. tostring(mapID) .. " npcs=" .. tostring(report.total) .. " eligible=" .. tostring(#report.eligible))

	for _, entry in ipairs(report.entries) do
		local data = entry.data
		local rejection = #entry.reasons > 0 and table.concat(entry.reasons, ",") or "none"

		util.log(config, table.concat({
			"npc=" .. data.id,
			"class=" .. data.class,
			"eligible=" .. boolText(entry.eligible),
			"patrol=" .. data.patrol,
			"nodes=" .. tostring(data.patrolPointCount),
			"radio=" .. boolText(data.radio),
			"xp=" .. tostring(data.experience),
			"keycard=" .. data.keycard,
			"weapon=" .. data.weapon,
			"follower=" .. data.follower,
			"named=" .. boolText(data.mapNameKey ~= "" or data.mapName ~= ""),
			"state=" .. data.stateID,
			"reject=" .. rejection
		}, " "))
	end
end

return diagnostics
