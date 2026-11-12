-- Database shape, defaults, loading and pruning. Pure Lua: time is passed in.
local _, ns = ...

local Util = ns.Util

local DB = {}
ns.DB = DB

DB.DEFAULT_SETTINGS = {
	toastEnabled = true,
	toastDuration = 8,
	minRatings = 3,
	promptAfterRun = true,
	recentAllies = false,
	simpleLists = false,
	minimapButton = true,
	minimapAngle = 200,
}

DB.LIMITS = {
	runs = 300,
	ratingsPerPlayer = 50,
	staleDays = 180,
}

local function fresh()
	return { schema = ns.SCHEMA, nextId = 1, settings = {}, players = {}, runs = {} }
end

local function repair(db)
	for _, key in ipairs({ "settings", "players", "runs" }) do
		if type(db[key]) ~= "table" then
			db[key] = {}
		end
	end
	if type(db.nextId) ~= "number" then
		db.nextId = 1
	end
	for _, key in ipairs({ "currentRun", "session", "backup" }) do
		if db[key] ~= nil and type(db[key]) ~= "table" then
			db[key] = nil
		end
	end
	Util.MergeDefaults(db.settings, DB.DEFAULT_SETTINGS)
	db.settings.toastDuration = Util.Clamp(db.settings.toastDuration, 3, 30)
	db.settings.minRatings = Util.Clamp(math.floor(db.settings.minRatings), 1, 10)
	db.settings.minimapAngle = db.settings.minimapAngle % 360
end

-- Turns whatever was loaded from SavedVariables into a usable database.
-- Returns db, info. When info.readOnly is true, db is a throwaway in-memory table and the
-- caller must NOT assign it to the SavedVariable (the saved file is newer than this addon,
-- or a migration failed, and must be left untouched).
function DB.Open(raw, now)
	local info = { created = false, readOnly = false }
	local db = raw
	if type(db) ~= "table" then
		db = fresh()
		info.created = true
	end

	local schema = db.schema
	if type(schema) ~= "number" then
		schema = 0
	end

	if schema > ns.SCHEMA then
		info.readOnly = true
		info.reason = "newer schema " .. schema
		db = fresh()
	elseif schema < ns.SCHEMA then
		local ok, err = ns.Migrations.Run(db, schema, ns.SCHEMA, now)
		if ok then
			info.migratedFrom = schema
		else
			info.readOnly = true
			info.reason = "migration failed: " .. tostring(err)
			db = fresh()
		end
	end

	repair(db)
	info.pruned = DB.Prune(db, now)
	return db, info
end

-- Keeps the saved file small. Rated players are never removed.
function DB.Prune(db, now)
	local removed = { runs = 0, ratings = 0, players = 0 }
	local limits = DB.LIMITS

	local ids = {}
	for id in pairs(db.runs) do
		ids[#ids + 1] = id
	end
	if #ids > limits.runs then
		table.sort(ids, function(a, b)
			local ta, tb = db.runs[a].startedAt or 0, db.runs[b].startedAt or 0
			if ta ~= tb then
				return ta < tb
			end
			return tostring(a) < tostring(b)
		end)
		for i = 1, #ids - limits.runs do
			db.runs[ids[i]] = nil
			removed.runs = removed.runs + 1
		end
	end

	local inCurrentRun = {}
	if db.currentRun and type(db.currentRun.members) == "table" then
		for _, member in ipairs(db.currentRun.members) do
			inCurrentRun[member.pid] = true
		end
	end

	local cutoff = now - limits.staleDays * 86400
	for pid, rec in pairs(db.players) do
		if type(rec) ~= "table" then
			db.players[pid] = nil
			removed.players = removed.players + 1
		else
			if type(rec.ratings) ~= "table" then
				rec.ratings = {}
			end
			if type(rec.rulesets) ~= "table" then
				rec.rulesets = {}
			end
			local ratings = rec.ratings
			if #ratings > limits.ratingsPerPlayer then
				table.sort(ratings, function(a, b)
					return (a.createdAt or 0) < (b.createdAt or 0)
				end)
				while #ratings > limits.ratingsPerPlayer do
					table.remove(ratings, 1)
					removed.ratings = removed.ratings + 1
				end
			end
			if #ratings == 0 and (rec.lastSeen or 0) < cutoff and not inCurrentRun[pid] then
				db.players[pid] = nil
				removed.players = removed.players + 1
			end
		end
	end
	return removed
end

function DB.Stats(db)
	local s = { players = 0, rated = 0, ratings = 0, runs = 0, pendingRuns = 0 }
	for _, rec in pairs(db.players) do
		s.players = s.players + 1
		local n = type(rec.ratings) == "table" and #rec.ratings or 0
		if n > 0 then
			s.rated = s.rated + 1
			s.ratings = s.ratings + n
		end
	end
	for _, run in pairs(db.runs) do
		s.runs = s.runs + 1
		if run.prompt == "pending" then
			s.pendingRuns = s.pendingRuns + 1
		end
	end
	return s
end

function DB.NextId(db, prefix)
	local n = db.nextId
	db.nextId = n + 1
	return prefix .. n
end

-- Removes all player and run data. Settings are kept.
function DB.PurgeAll(db)
	db.players = {}
	db.runs = {}
	db.currentRun = nil
	db.session = nil
	db.backup = nil
end
