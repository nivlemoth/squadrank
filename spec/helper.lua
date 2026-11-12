-- Loads the pure-Lua modules the way the game client would: each file receives
-- (addonName, namespace). Only the two Lua additions those modules rely on are stubbed.
time = os.time
date = os.date

local FILES = {
	"Core/Init.lua",
	"Locales/Locale.lua",
	"Locales/enUS.lua",
	"Core/Util.lua",
	"Core/Debug.lua",
	"Data/DB.lua",
	"Data/Migrations.lua",
	"Data/Players.lua",
	"Data/Ratings.lua",
	"Data/Runs.lua",
	"Data/Session.lua",
}

local helper = {}

function helper.load()
	local ns = {}
	for _, path in ipairs(FILES) do
		local chunk = assert(loadfile(path))
		chunk("SquadRank", ns)
	end
	return ns
end

helper.DAY = 86400
helper.NOW = 1800000000

return helper
