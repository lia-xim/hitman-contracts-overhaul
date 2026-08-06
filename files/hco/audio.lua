local util = require("hco/util")

local audio = {oneshots = {}}

local function pruneOneshots()
	for index = #audio.oneshots, 1, -1 do
		local source = audio.oneshots[index]
		local playing = false
		if source and type(source.isPlaying) == "function" then
			local ok, state = pcall(source.isPlaying, source)
			playing = ok and state == true
		end
		if not playing then table.remove(audio.oneshots, index) end
	end
end

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
	local heavy = owner and owner.hcoType and owner.hcoType.heavy == true
	local source = sourcePath(heavy and "drone-rotor-heavy-loop.wav" or "drone-rotor-light-loop.wav") or sourcePath("drone-rotor-loop.wav")
	if not source then return nil end
	pcall(source.setLooping, source, true)
	pcall(source.setVolume, source, heavy and 0.065 or 0.055)
	local ok = pcall(source.play, source)
	return ok and source or nil
end

function audio.updateRotor(source, owner)
	if not source or not owner or not game or not game.playerActor then return end
	local distance = util.distance(owner, game.playerActor)
	local heavy = owner.hcoType and owner.hcoType.heavy == true
	local volume = (heavy and 0.022 or 0.016) + math.max(0, 1 - distance / (heavy and 1100 or 900)) * (heavy and 0.18 or 0.14)
	pcall(source.setVolume, source, volume)
end

function audio.stop(source)
	if source then pcall(source.stop, source) end
end

function audio.playCompletion()
	pruneOneshots()
	local source = sourcePath("contract-complete-chime.wav")
	if not source then return false end
	pcall(source.setVolume, source, 0.48)
	local ok = pcall(source.play, source)
	if ok then table.insert(audio.oneshots, source) end
	return ok
end

function audio.playDroneLaser(owner, heavy)
	pruneOneshots()
	local source = sourcePath(heavy and "drone-laser-heavy.wav" or "drone-laser-light.wav")
	if not source then return false end
	local distance = owner and game and game.playerActor and util.distance(owner, game.playerActor) or 0
	local attenuation = math.max(0.18, 1 - distance / 1250)
	pcall(source.setVolume, source, attenuation * (heavy and 0.62 or 0.48))
	local ok = pcall(source.play, source)
	if ok then table.insert(audio.oneshots, source) end
	return ok
end

return audio
