-- Ring buffer, error capture and the debug report.
-- Rule: nothing logged here may contain another player's name, GUID or note. Callers log
-- counts and Util.Hash(pid) only. Secret values are dropped before formatting.
local _, ns = ...

local Util = ns.Util

local Debug = {
	lines = {},
	errors = {},
	maxLines = 200,
	maxErrors = 20,
	errorCount = 0,
	selftest = nil,
	notes = {},
}
ns.Debug = Debug

local function isSecret(v)
	return type(issecretvalue) == "function" and issecretvalue(v) == true
end

local function stamp()
	return date("%H:%M:%S")
end

local function push(list, max, text)
	list[#list + 1] = text
	while #list > max do
		table.remove(list, 1)
	end
end

function Debug.Log(kind, fmt, ...)
	local msg = fmt
	local n = select("#", ...)
	if n > 0 then
		local clean = true
		for i = 1, n do
			if isSecret((select(i, ...))) then
				clean = false
				break
			end
		end
		if clean then
			local ok, out = pcall(string.format, fmt, ...)
			if ok then
				msg = out
			end
		else
			msg = fmt .. " <secret argument dropped>"
		end
	end
	push(Debug.lines, Debug.maxLines, stamp() .. " [" .. kind .. "] " .. msg)
end

function Debug.Error(label, err)
	Debug.errorCount = Debug.errorCount + 1
	local text = isSecret(err) and "<secret>" or tostring(err)
	push(Debug.errors, Debug.maxErrors, stamp() .. " " .. label .. ": " .. text)
	Debug.Log("ERROR", "%s: %s", label, text)
end

-- Wraps one of our own handlers so an error is recorded instead of lost.
-- The global error handler is left alone.
function ns.Safe(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			Debug.Error(label, err)
		end
	end
end

-- Calls fn now; returns up to three results, or nil after recording the error.
function ns.Try(label, fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		Debug.Error(label, a)
		return nil
	end
	return a, b, c
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	return keys
end

-- Returns the report as an array of lines.
function Debug.BuildReport()
	local out = {}
	local function add(fmt, ...)
		out[#out + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
	end

	add("SquadRank debug report")
	add("generated: %s", date("%Y-%m-%d %H:%M:%S"))
	add("addon version: %s", ns.VERSION)
	if ns.Locale then
		add("locale: %s", ns.Locale.Summary())
	end
	local Compat = ns.Compat
	if Compat then
		local build = Compat.Build()
		add("client: %s build %s, interface %s", build.version, build.build, build.interface)
		add("ruleset: %s", Compat.Ruleset())
		add("in combat: %s", tostring(Compat.InCombat()))
	end

	add("")
	add("== database")
	local db = ns.db
	if db and ns.DB then
		local s = ns.DB.Stats(db)
		add("schema: %s (addon supports %d)", tostring(db.schema), ns.SCHEMA)
		add("read-only: %s", tostring(ns.readOnly == true))
		add("players: %d (rated: %d), ratings: %d", s.players, s.rated, s.ratings)
		add("runs: %d (waiting for a rating: %d)", s.runs, s.pendingRuns)
		add("current run: %s", db.currentRun and (db.currentRun.kind or "instance") or "no")
		add(
			"group session: %s, members seen: %d",
			db.session and "yes" or "no",
			db.session and Util.Count(db.session.seen) or 0
		)
		add("migration backup: %s", db.backup and ("yes, from schema " .. tostring(db.backup.schema)) or "no")
		add("")
		add("== settings")
		for _, k in ipairs(sortedKeys(db.settings)) do
			add("%s = %s", k, tostring(db.settings[k]))
		end
	else
		add("database not loaded")
	end

	if next(Debug.notes) then
		add("")
		add("== notes")
		for _, k in ipairs(sortedKeys(Debug.notes)) do
			add("%s: %s", k, tostring(Debug.notes[k]))
		end
	end

	add("")
	add("== self-test")
	if Debug.selftest then
		add(
			"ran at %s: %d pass, %d fail, %d info",
			Debug.selftest.at,
			Debug.selftest.pass,
			Debug.selftest.fail,
			Debug.selftest.info
		)
		for _, r in ipairs(Debug.selftest.results) do
			add("%-4s %s%s", r.status, r.name, r.detail ~= "" and (" -> " .. r.detail) or "")
		end
	else
		add("not run in this session (type /sr selftest)")
	end

	add("")
	add("== errors (%d in this session, last %d shown)", Debug.errorCount, #Debug.errors)
	for _, line in ipairs(Debug.errors) do
		add(line)
	end

	add("")
	add("== log (last %d entries)", #Debug.lines)
	for _, line in ipairs(Debug.lines) do
		add(line)
	end
	return out
end

function Debug.ReportText()
	return table.concat(Debug.BuildReport(), "\n")
end

-- Copies the report into the SquadRankDebug SavedVariable so it can be read from the
-- WTF folder after a /reload or logout.
function Debug.Mirror()
	local ok, report = pcall(Debug.BuildReport)
	SquadRankDebug = {
		version = ns.VERSION,
		updatedAt = time(),
		report = ok and report or { "report failed: " .. tostring(report) },
	}
end
