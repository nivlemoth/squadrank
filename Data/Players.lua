-- Player identity. A record is keyed "g:<GUID>" once a GUID is known, otherwise
-- "n:<name>-<suffix>". Pure Lua: the caller passes identities that are already checked
-- for secret values (see Core/Compat.lua).
local _, ns = ...

local Util = ns.Util

local Players = { index = {} }
ns.Players = Players

-- name key -> pid, rebuilt at load. Not saved.
function Players.BuildIndex(db)
	local index = {}
	for pid, rec in pairs(db.players) do
		if type(rec.name) == "string" then
			index[Util.NameKey(rec.name, rec.suffix)] = pid
		end
	end
	Players.index = index
end

local function newRecord(ident, now)
	return {
		name = ident.name,
		suffix = ident.suffix,
		firstSeen = now,
		lastSeen = now,
		rulesets = {},
		ratings = {},
	}
end

local function replaceInRun(run, oldPid, newPid)
	if type(run) ~= "table" or type(run.members) ~= "table" then
		return
	end
	local seen = false
	for i = #run.members, 1, -1 do
		local member = run.members[i]
		if member.pid == oldPid or member.pid == newPid then
			if seen then
				table.remove(run.members, i)
			else
				member.pid = newPid
				seen = true
			end
		end
	end
end

local function replacePid(db, oldPid, newPid)
	for _, run in pairs(db.runs) do
		replaceInRun(run, oldPid, newPid)
	end
	replaceInRun(db.currentRun, oldPid, newPid)
	local session = db.session
	if session and type(session.seen) == "table" and session.seen[oldPid] then
		session.seen[oldPid] = nil
		session.seen[newPid] = true
	end
end

-- Moves everything from one record into another and deletes the first.
function Players.Merge(db, fromPid, toPid)
	local from, to = db.players[fromPid], db.players[toPid]
	if not from or not to or fromPid == toPid then
		return
	end
	for _, rating in ipairs(from.ratings) do
		to.ratings[#to.ratings + 1] = rating
	end
	table.sort(to.ratings, function(a, b)
		return (a.createdAt or 0) < (b.createdAt or 0)
	end)
	to.firstSeen = math.min(to.firstSeen or from.firstSeen or 0, from.firstSeen or to.firstSeen or 0)
	for tag in pairs(from.rulesets or {}) do
		to.rulesets[tag] = true
	end
	db.players[fromPid] = nil
	replacePid(db, fromPid, toPid)
end

-- Finds or creates the record for an identity { name, suffix, guid, classFile, level, faction }.
-- Returns pid, record.
function Players.Resolve(db, ident, now, ruleset)
	local nameKey = Util.NameKey(ident.name, ident.suffix)
	local pid

	if ident.guid then
		pid = "g:" .. ident.guid
		local byName = db.players[nameKey]
		if not db.players[pid] then
			if byName then
				db.players[pid] = byName
				db.players[nameKey] = nil
				replacePid(db, nameKey, pid)
			else
				db.players[pid] = newRecord(ident, now)
			end
		elseif byName then
			Players.Merge(db, nameKey, pid)
		end
	else
		pid = Players.index[nameKey]
		if not pid or not db.players[pid] then
			pid = nameKey
			if not db.players[pid] then
				db.players[pid] = newRecord(ident, now)
			end
		end
	end

	local rec = db.players[pid]
	if ident.guid or not rec.guid then
		rec.name = ident.name
		rec.suffix = ident.suffix
	end
	rec.guid = ident.guid or rec.guid
	rec.classFile = ident.classFile or rec.classFile
	rec.level = ident.level or rec.level
	rec.faction = ident.faction or rec.faction
	rec.lastSeen = now
	if ruleset then
		rec.rulesets[ruleset] = true
	end
	Players.index[nameKey] = pid
	return pid, rec
end

-- The pid of an identity already saved, or nil. Never creates a record (used by tooltips).
function Players.Lookup(db, ident)
	if type(ident) ~= "table" or type(ident.name) ~= "string" then
		return nil
	end
	if ident.guid and db.players["g:" .. ident.guid] then
		return "g:" .. ident.guid
	end
	local nameKey = Util.NameKey(ident.name, ident.suffix)
	local pid = Players.index[nameKey] or nameKey
	return db.players[pid] and pid or nil
end

-- The avoid list is a flag on the player record (true or nil), never a translated label.
function Players.SetAvoid(db, pid, on)
	local rec = db.players[pid]
	if not rec then
		return false
	end
	rec.avoid = on and true or nil
	return true
end

-- Exact, case-insensitive match on "Name" or "Name-Suffix". Returns a list of pids.
function Players.Find(db, query)
	local q = Util.Trim(tostring(query or "")):lower()
	local found = {}
	if q == "" then
		return found
	end
	local exact = {}
	for pid, rec in pairs(db.players) do
		if type(rec.name) == "string" then
			if Util.FullName(rec.name, rec.suffix):lower() == q then
				exact[#exact + 1] = pid
			elseif rec.name:lower() == q then
				found[#found + 1] = pid
			end
		end
	end
	-- "Bob" names the Bob from your own realm even when a "Bob-Vale" is also saved.
	if #exact > 0 then
		found = exact
	end
	table.sort(found)
	return found
end

-- Name ready for display: pipes escaped, suffix appended.
function Players.DisplayName(rec)
	if type(rec) ~= "table" or type(rec.name) ~= "string" then
		return "?"
	end
	return Util.Escape(Util.FullName(rec.name, rec.suffix))
end

function Players.Purge(db, pid)
	if not db.players[pid] then
		return false
	end
	db.players[pid] = nil
	local function strip(run)
		if type(run) == "table" and type(run.members) == "table" then
			for i = #run.members, 1, -1 do
				if run.members[i].pid == pid then
					table.remove(run.members, i)
				end
			end
		end
	end
	for _, run in pairs(db.runs) do
		strip(run)
	end
	strip(db.currentRun)
	if db.session and type(db.session.seen) == "table" then
		db.session.seen[pid] = nil
	end
	Players.BuildIndex(db)
	return true
end
