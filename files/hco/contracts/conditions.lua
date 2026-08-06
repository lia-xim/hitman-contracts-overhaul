local persistence = require("hco/contracts/persistence")

local conditions = {}

local definitions = {
	{
		id = "silent",
		bonusRate = 0.3,
		description = "Optional: finish before a confirmed alarm",
		check = function(metrics)
			return not metrics.alarmRaised
		end
	},
	{
		id = "protect_detail",
		bonusRate = 0.2,
		description = "Optional: leave the protection detail alive",
		check = function(metrics)
			return metrics.initialEscortCount > 0 and metrics.livingEscortCount >= metrics.initialEscortCount
		end
	},
	{
		id = "social_entry",
		bonusRate = 0.25,
		description = "Optional: acquire and use a disguise",
		check = function(metrics)
			return metrics.usedDisguise
		end
	}
}

function conditions.create(seed, baseReward)
	local definition = definitions[(tonumber(seed) or 0) % #definitions + 1]

	return {
		id = definition.id,
		bonus = math.floor((tonumber(baseReward) or 0) * definition.bonusRate),
		settled = false
	}
end

function conditions.getDefinition(id)
	for _, definition in ipairs(definitions) do
		if definition.id == id then
			return definition
		end
	end

	return nil
end

function conditions.getDescription(condition)
	local definition = condition and conditions.getDefinition(condition.id)

	return definition and definition.description or nil
end

function conditions.settle(state)
	local record = state and state.contract

	if not record then
		return 0, false
	end

	if record.condition and record.condition.settled and record.resolvedReward then
		return record.resolvedReward, record.condition.result == true
	end

	local metrics = record.metrics or {}
	local definition = record.condition and conditions.getDefinition(record.condition.id)
	local passed = definition and definition.check(metrics) or false
	local reward = record.baseReward or record.reward

	if passed and record.condition then
		reward = reward + (tonumber(record.condition.bonus) or 0)
	end

	record.resolvedReward = reward
	record.reward = reward

	if record.condition then
		record.condition.result = passed
		record.condition.settled = true
	end

	persistence.save(record)

	return reward, passed
end

return conditions
