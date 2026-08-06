local util = require("hco/util")

local audio = {oneshots = {}}

local function sourcePath(file)
	if not love or not love.audio or type(love.audio.newSource) ~= "function" then return nil end
	local candidates = {
		"mods/Hitman-Contracts-Overhaul/files/assets/hco/" .. file,
		"mods/Hitman-Contracts-Overhaul/assets/hco/" .. file,
		"assets/hco/" .. file
	}
	for _, path in ipairs(candidates) do
		local ok, source = pcall(love.audio.newSource, path, "static")
		if ok and source then return source end
	end
	return nil
end

function audio.startRotor(owner)
	local source = sourcePath("drone-rotor-loop.wav")
	if not source then return nil end
	pcall(source.setLooping, source, true)
	pcall(source.setVolume, source, 0.08)
	local ok = pcall(source.play, source)
	return ok and source or nil
end

function audio.updateRotor(source, owner)
	if not source or not owner or not game or not game.playerActor then return end
	local distance = util.distance(owner, game.playerActor)
	local volume = 0.025 + math.max(0, 1 - distance / 950) * 0.19
	pcall(source.setVolume, source, volume)
end

function audio.stop(source)
	if source then pcall(source.stop, source) end
end

function audio.playCompletion()
	local source = sourcePath("contract-complete-chime.wav")
	if not source then return false end
	pcall(source.setVolume, source, 0.48)
	local ok = pcall(source.play, source)
	if ok then table.insert(audio.oneshots, source) end
	return ok
end

return audio
