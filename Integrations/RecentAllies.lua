-- Optional, read-only use of Blizzard's Recent Allies list. Off by default (setting
-- recentAllies). It looks a player up by name to learn their GUID when the user rates someone
-- by typing a name, and it can list recent allies that match players already saved locally.
-- It never writes: no notes, no pins, no Recent Allies records. The addon works without it.
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Compat = ns.Compat
local Debug = ns.Debug

local RecentAllies = {}
ns.RecentAllies = RecentAllies

-- The setting is opt-in. A saved value is never changed here.
function RecentAllies.Enabled()
	local db = ns.db
	return type(db) == "table" and type(db.settings) == "table" and db.settings.recentAllies == true
end

function RecentAllies.Available()
	if not (C_RecentAllies and C_RecentAllies.IsSystemEnabled) then
		return false
	end
	local ok, enabled = pcall(C_RecentAllies.IsSystemEnabled)
	return ok and Compat.Clean(enabled, "boolean") == true
end

-- The list view needs its own function; the typed-name lookup is not enough.
function RecentAllies.CanList()
	return type(C_RecentAllies) == "table"
		and type(C_RecentAllies.GetRecentAllies) == "function"
		and RecentAllies.Available()
end

-- A cleaned identity from one Recent Allies entry. Secret or malformed fields are dropped;
-- a missing GUID is fine because matching can fall back to the full or bare name.
local function cleanCharacter(character)
	if type(character) ~= "table" then
		return nil
	end
	local name = Compat.Clean(character.name, "string")
	if not name or name == "" then
		return nil
	end
	local guid = Compat.Clean(character.guid, "string")
	if guid and guid:sub(1, 7) ~= "Player-" then
		guid = nil
	end
	return {
		name = name,
		suffix = Compat.Clean(character.realmName, "string"),
		guid = guid,
		level = Compat.Clean(character.level, "number"),
		fullName = Compat.Clean(character.fullName, "string"),
	}
end

-- Returns an identity { name, suffix, guid, level } for a typed name, or nil.
function RecentAllies.Lookup(name, suffix)
	if not RecentAllies.Enabled() or not RecentAllies.Available() then
		return nil
	end
	if type(C_RecentAllies.GetRecentAllyByFullName) ~= "function" then
		return nil
	end
	local ok, data = pcall(C_RecentAllies.GetRecentAllyByFullName, Util.FullName(name, suffix))
	if not ok or type(data) ~= "table" or type(data.characterData) ~= "table" then
		return nil
	end
	local ident = cleanCharacter(data.characterData)
	if not ident then
		return nil
	end
	-- The user typed the suffix, so keep it for the local name lookup.
	ident.suffix = suffix
	Debug.Log("ALLIES", "typed name matched a recent ally")
	return ident
end

-- Returns a list of cleaned recent allies, or nil and a reason
-- ("disabled", "unavailable", "error"). It never returns raw client data.
function RecentAllies.List()
	if not RecentAllies.Enabled() then
		return nil, "disabled"
	end
	if not RecentAllies.CanList() then
		return nil, "unavailable"
	end
	local ok, raw = pcall(C_RecentAllies.GetRecentAllies)
	if not ok or type(raw) ~= "table" then
		return nil, "error"
	end
	local okList, list = pcall(function()
		local out = {}
		for i = 1, #raw do
			local entry = raw[i]
			if type(entry) == "table" then
				local ident = cleanCharacter(entry.characterData)
				if ident then
					out[#out + 1] = ident
				end
			end
		end
		return out
	end)
	if not okList then
		return nil, "error"
	end
	Debug.Log("ALLIES", "%d recent allies read", #list)
	return list
end

-- Matches cleaned recent allies to saved players without creating any record. GUID first,
-- then the full name, then a unique bare name.
function RecentAllies.Matches(db, list)
	local matches, seen = {}, {}
	if type(db) ~= "table" or type(list) ~= "table" then
		return matches
	end
	for _, ident in ipairs(list) do
		local pid = ns.Players.Lookup(db, { name = ident.name, suffix = ident.suffix, guid = ident.guid })
		if not pid and ident.name then
			local pids = ns.Players.Find(db, ident.name)
			if #pids == 1 then
				pid = pids[1]
			end
		end
		if pid and not seen[pid] and db.players[pid] then
			seen[pid] = true
			matches[#matches + 1] = { pid = pid, rec = db.players[pid], ally = ident }
		end
	end
	table.sort(matches, function(a, b)
		return ns.Players.DisplayName(a.rec) < ns.Players.DisplayName(b.rec)
	end)
	return matches
end

-- Chat lines for one match. Notes are left out: this is a compact local roster view.
function RecentAllies.Lines(summary, rec)
	if type(summary) ~= "table" or type(rec) ~= "table" then
		return {}
	end
	local UI = ns.UI
	local lines = { UI.ColoredName(rec) .. "   " .. UI.LabelText(summary.label) }
	if summary.count == 0 then
		lines[#lines + 1] = L.DETAIL_NO_RATINGS
	else
		for _, line in ipairs(UI.SummaryLines(summary, { noNote = true })) do
			lines[#lines + 1] = line
		end
	end
	return lines
end
