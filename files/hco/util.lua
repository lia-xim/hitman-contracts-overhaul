local util = {}

function util.call(object, methodName, ...)
	if not object then
		return false, nil
	end

	local method = object[methodName]

	if type(method) ~= "function" then
		return false, nil
	end

	return pcall(method, object, ...)
end

function util.isValid(object)
	if not object then
		return false
	end

	local method = object.isValid

	if type(method) == "function" then
		local ok, valid = pcall(method, object)

		return ok and valid ~= false
	end

	return true
end

function util.isAlive(object)
	if not util.isValid(object) then
		return false
	end

	local okDead, dead = util.call(object, "isDead")
	local okUnconscious, unconscious = util.call(object, "isUnconscious")

	return (not okDead or dead ~= true) and (not okUnconscious or unconscious ~= true)
end

function util.getClass(object)
	local ok, value = util.call(object, "getClass")

	if ok and value then
		return tostring(value)
	end

	if object and object.class then
		return tostring(object.class)
	end

	return "unknown"
end

function util.getID(object)
	local ok, value = util.call(object, "getID")

	if ok and value ~= nil then
		return tostring(value)
	end

	if object and object.id ~= nil then
		return tostring(object.id)
	end

	return nil
end

function util.getPos(object)
	local ok, x, y = util.call(object, "getPos")

	if ok and tonumber(x) and tonumber(y) then
		return tonumber(x), tonumber(y)
	end

	if object and tonumber(object.x) and tonumber(object.y) then
		return tonumber(object.x), tonumber(object.y)
	end

	return nil, nil
end

function util.distance(a, b)
	local ax, ay = util.getPos(a)
	local bx, by = util.getPos(b)

	if not ax or not bx then
		return math.huge
	end

	local dx, dy = ax - bx, ay - by

	return math.sqrt(dx * dx + dy * dy)
end

function util.distanceToPoint(object, x, y)
	local ox, oy = util.getPos(object)

	if not ox or not x or not y then
		return math.huge
	end

	local dx, dy = ox - x, oy - y

	return math.sqrt(dx * dx + dy * dy)
end

function util.describeReference(object)
	if object == nil then
		return "none"
	end

	local id = util.getID(object)

	if id then
		return id
	end

	if object.name then
		return tostring(object.name)
	end

	if object.class then
		return tostring(object.class)
	end

	return "present"
end

function util.cleanText(value)
	if value == nil then
		return ""
	end

	return tostring(value):gsub("[%c]+", " ")
end

function util.stableHash(value)
	local hash = 5381
	local text = tostring(value or "")

	for index = 1, #text do
		hash = (hash * 33 + string.byte(text, index)) % 2147483647
	end

	return hash
end

function util.clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

function util.copyStringMap(source)
	local result = {}

	for key, value in pairs(source or {}) do
		if value then
			result[tostring(key)] = true
		end
	end

	return result
end

function util.listContains(list, value)
	for _, entry in ipairs(list or {}) do
		if entry == value then
			return true
		end
	end

	return false
end

function util.worldMatches(state, object)
	if not state or not state.worldToken or not object then
		return false
	end

	return object._hcoWorldToken == state.worldToken
end

function util.getNPCs(worldObject)
	local ok, npcs = util.call(worldObject, "getNPCs")

	if ok and type(npcs) == "table" then
		return npcs
	end

	return {}
end

function util.observerKnowsPlayerIdentity(state, observer, player)
	local root = state and (state.root or state)
	local active = root and root.disguise

	-- Without social cover the native game owns recognition completely.
	if not active then
		return true
	end

	local group = tostring(active.group or "")
	local compromised = root.compromisedDisguises or {}

	if active.compromised == true or compromised[group] == true then
		return true
	end

	local observerID = util.getID(observer)
	local localKnowledge = observerID and root.localCompromisedDisguises
		and root.localCompromisedDisguises[observerID]

	if localKnowledge and localKnowledge[group] == true then
		return true
	end

	local okSight, enemyInSight = util.call(observer, "getEnemyInSight", player)

	return okSight and enemyInSight == true
end

function util.log(config, message)
	print(config.LOG_PREFIX .. " " .. tostring(message))
end

return util
