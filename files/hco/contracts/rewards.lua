local feedback = require("hco/feedback")
local persistence = require("hco/contracts/persistence")
local stateModule = require("hco/state")

local rewards = {}

function rewards.pay(state)
	local record = state and state.contract

	if not record then
		return false, "contract-unavailable"
	end

	if record.rewardPaid then
		return true
	end

	local playthrough = game and game.playthrough
	local amount = math.max(0, math.floor(tonumber(record.resolvedReward or record.reward or record.baseReward) or 0))

	if not playthrough or type(playthrough.changeMoney) ~= "function" then
		record.status = "payout_pending"
		persistence.save(record)

		return false, "playthrough-money-unavailable"
	end

	local ok, err = pcall(playthrough.changeMoney, playthrough, amount)

	if not ok then
		record.status = "payout_pending"
		persistence.save(record)

		return false, tostring(err)
	end

	record.rewardPaid = true
	record.status = "completed"
	record.resolvedReward = amount
	state.targetStatus = "completed"
	state.pendingRewardPayment = nil
	persistence.save(record)
	if state.root then stateModule.syncPrimary(state.root) end
	feedback.complete(record, amount)

	return true
end

return rewards
