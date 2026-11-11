-- Optional, read-only use of Blizzard's Recent Allies list. Off by default (setting
-- recentAllies). It only looks a player up by name to learn their GUID when the user rates
-- someone by typing a name. It never writes: no notes, no pins. The addon works without it.
local _, ns = ...

local Util = ns.Util
local Compat = ns.Compat
local Debug = ns.Debug

local RecentAllies = {}
ns.RecentAllies = RecentAllies

function RecentAllies.Available()
	if not (C_RecentAllies and C_RecentAllies.GetRecentAllyByFullName and C_RecentAllies.IsSystemEnabled) then
		return false
	end
	local ok, enabled = pcall(C_RecentAllies.IsSystemEnabled)
	return ok and enabled == true
end

-- Returns an identity { name, suffix, guid, level } for a typed name, or nil.
function RecentAllies.Lookup(name, suffix)
	if not ns.db.settings.recentAllies or not RecentAllies.Available() then
		return nil
	end
	local ok, data = pcall(C_RecentAllies.GetRecentAllyByFullName, Util.FullName(name, suffix))
	if not ok or type(data) ~= "table" or type(data.characterData) ~= "table" then
		return nil
	end
	local character = data.characterData
	local guid = Compat.Clean(character.guid, "string")
	if not guid or guid:sub(1, 7) ~= "Player-" then
		return nil
	end
	Debug.Log("ALLIES", "typed name matched a recent ally")
	return {
		name = Compat.Clean(character.name, "string") or name,
		suffix = suffix,
		guid = guid,
		level = Compat.Clean(character.level, "number"),
	}
end
