local config = require("hco/config")
local util = require("hco/util")

local registry = {}

local unsupportedExact = {
	iv2_hideout = true,
	iv2_map0 = true,
	iv2_map9_intro = true,
	iv2_merc_intro = true,
	iv2_merc_outro = true
}

local unsupportedFragments = {
	"prologue",
	"intro",
	"outro",
	"tutorial",
	"hideout"
}

local campaignProfiles = {}

local function addCampaign(ids, data)
	for _, id in ipairs(ids) do
		campaignProfiles[id] = data
	end
end

addCampaign({"iv2_map3", "iv2_map6", "iv2_map7", "iv2_map8_1", "iv2_map8_2"}, {
	id = "early_campaign",
	rewardMultiplier = 1,
	archetypes = {"broker", "fixer", "executive"}
})
addCampaign({"iv2_map8_side_1", "iv2_map9", "iv2_map9_side_1", "iv2_map9_side_2", "iv2_map10", "iv2_map10_side_1"}, {
	id = "mid_campaign",
	rewardMultiplier = 1.15,
	archetypes = {"broker", "fixer", "commander"}
})
addCampaign({"iv2_map11", "iv2_map11_side", "iv2_map12", "iv2_map12_side", "iv2_map13", "iv2_map13_side"}, {
	id = "high_security",
	rewardMultiplier = 1.3,
	archetypes = {"executive", "fixer", "commander"}
})
addCampaign({"iv2_map14", "iv2_map15", "iv2_map16", "iv2_map16_side", "iv2_map17", "iv2_map17_side", "iv2_map18_1", "iv2_map18_2", "iv2_map18_3", "iv2_map18_4"}, {
	id = "late_campaign",
	rewardMultiplier = 1.45,
	archetypes = {"executive", "fixer", "commander", "broker"}
})
addCampaign({"iv2_merc_map1", "iv2_merc_map2"}, {
	id = "mercenary_campaign",
	rewardMultiplier = 1.25,
	archetypes = {"fixer", "commander"}
})

local function cloneProfile(source, mapID, authored)
	local result = {
		id = source.id,
		mapID = mapID,
		authored = authored == true,
		rewardMultiplier = tonumber(source.rewardMultiplier) or 1,
		archetypes = {}
	}

	for _, id in ipairs(source.archetypes or {}) do
		table.insert(result.archetypes, id)
	end

	return result
end

function registry.resolve(mapID)
	mapID = tostring(mapID or "unknown")

	if mapID == "unknown" or unsupportedExact[mapID] then
		return nil, "unsupported-map"
	end

	local lower = string.lower(mapID)

	for _, fragment in ipairs(unsupportedFragments) do
		if string.find(lower, fragment, 1, true) then
			return nil, "unsupported-mission-phase"
		end
	end

	if campaignProfiles[mapID] then
		return cloneProfile(campaignProfiles[mapID], mapID, true)
	end

	if not config.ALLOW_GENERIC_MAPS then
		return nil, "no-authored-profile"
	end

	return cloneProfile({
		id = "generic_conservative",
		rewardMultiplier = 0.9,
		archetypes = {"broker", "fixer"}
	}, mapID, false)
end

function registry.chooseArchetype(profile, seed)
	local list = profile and profile.archetypes or {}

	if #list == 0 then
		return nil
	end

	return list[(tonumber(seed) or util.stableHash(profile.mapID)) % #list + 1]
end

return registry
