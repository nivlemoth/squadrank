-- Run records and the rules for when a run starts, resumes and ends.
-- Pure Lua: the caller passes the current state and time.
local _, ns = ...

local Runs = {}
ns.Runs = Runs

-- Dying in a Vanilla-style game puts you outside the instance, so being outside does not
-- end a run by itself. It ends after this many seconds outside, or when the group is left.
Runs.OUTSIDE_GRACE = 300
-- A saved run older than this is never resumed (logged out inside, came back next day).
Runs.RESUME_LIMIT = 4 * 3600
-- An open-world group shorter than this (a quick summon, a trade) is not worth a prompt.
Runs.GROUP_MIN = 300
-- The "Rate your squad" alert offers runs that ended within this window.
Runs.ALERT_WINDOW = 3 * 86400

local TRACKED = { party = true, raid = true }

local function setInstance(run, state)
	run.kind = nil
	run.instanceID = state.instanceID
	run.instanceName = state.instanceName
	run.instanceType = state.instanceType
	run.maxPlayers = state.maxPlayers
end

-- kind is nil for a dungeon or raid run, "group" for an open-world group.
local function start(db, state, now, ruleset, kind)
	local run = {
		id = ns.DB.NextId(db, "run"),
		startedAt = now,
		lastInside = now,
		ruleset = ruleset,
		bossKills = 0,
		members = {},
	}
	if kind == "group" then
		run.kind = "group"
		run.instanceName = state.zoneName
	else
		setInstance(run, state)
	end
	db.currentRun = run
	return run
end

-- True when the group run carried on straight from a dungeon run (run.after) and has nobody
-- new: that squad is already up for rating, so the group run is not worth a second prompt.
local function coveredByPrevious(db, run)
	local previous = run.after and db.runs[run.after]
	if not previous then
		return false
	end
	local inPrevious = {}
	for _, member in ipairs(previous.members or {}) do
		inPrevious[member.pid] = true
	end
	for _, member in ipairs(run.members) do
		if not inPrevious[member.pid] then
			return false
		end
	end
	return true
end

-- Closes the current run. Returns the stored run, or nil if it was discarded (nobody else in it).
function Runs.Finish(db, now)
	local run = db.currentRun
	db.currentRun = nil
	if not run then
		return nil
	end
	if type(run.members) ~= "table" or #run.members == 0 then
		return nil
	end
	if run.kind == "group" then
		local last = run.lastInside or now
		run.endedAt = (now - last > Runs.RESUME_LIMIT) and last or now
		if run.endedAt - (run.startedAt or now) < Runs.GROUP_MIN or coveredByPrevious(db, run) then
			return nil
		end
	else
		run.endedAt = run.outsideSince or run.lastInside or now
	end
	run.outsideSince = nil
	run.lastInside = nil
	run.groupSize = #run.members + 1
	run.prompt = "pending"
	db.runs[run.id] = run
	return run
end

-- state = { inInstance, instanceType, instanceID, instanceName, maxPlayers, inGroup, zoneName }
-- Returns an action and, when a run was closed and stored, that run:
--   "idle"      nothing is being tracked
--   "grouped"   in a group outside any dungeon: an open-world group run is open
--   "started"   a new run began (a previous one may have been finished and is returned)
--   "resumed"   still (or again) inside the current run's instance
--   "pending"   outside the instance, waiting for the grace period or the group to end
--   "finished"  the current run ended
function Runs.Evaluate(db, state, now, ruleset)
	local run = db.currentRun
	local inside = state.inInstance and TRACKED[state.instanceType] and state.instanceID ~= nil

	if run and run.kind == "group" then
		if inside then
			-- The group walked into a dungeon together: same squad, now a dungeon run.
			setInstance(run, state)
			run.lastInside = now
			return "started"
		end
		if state.inGroup then
			run.lastInside = now
			return "grouped"
		end
		return "finished", Runs.Finish(db, now)
	end

	if not run then
		if inside then
			start(db, state, now, ruleset)
			return "started"
		end
		if state.inGroup and not state.inInstance then
			start(db, state, now, ruleset, "group")
			return "grouped"
		end
		return "idle"
	end

	if inside then
		local stale = now - (run.lastInside or run.startedAt or now) > Runs.RESUME_LIMIT
		if state.instanceID == run.instanceID and not stale then
			run.lastInside = now
			run.outsideSince = nil
			return "resumed"
		end
		local finished = Runs.Finish(db, now)
		start(db, state, now, ruleset)
		return "started", finished
	end

	run.outsideSince = run.outsideSince or now
	if not state.inGroup or now - run.outsideSince >= Runs.OUTSIDE_GRACE then
		local finished = Runs.Finish(db, now)
		if state.inGroup and not state.inInstance then
			-- Still together after the dungeon: carry on as an open-world group run.
			local group = start(db, state, now, ruleset, "group")
			group.after = finished and finished.id
		end
		return "finished", finished
	end
	return "pending"
end

-- True while the player is inside the instance of the current run.
function Runs.IsInside(db)
	local run = db.currentRun
	return run ~= nil and run.outsideSince == nil
end

function Runs.AddMember(db, pid, role)
	local run = db.currentRun
	if not run then
		return false
	end
	for _, member in ipairs(run.members) do
		if member.pid == pid then
			member.role = role or member.role
			return false
		end
	end
	run.members[#run.members + 1] = { pid = pid, role = role }
	return true
end

function Runs.AddBossKill(db)
	local run = db.currentRun
	if run then
		run.bossKills = (run.bossKills or 0) + 1
	end
end

-- Stored runs, newest first.
function Runs.List(db)
	local list = {}
	for _, run in pairs(db.runs) do
		list[#list + 1] = run
	end
	table.sort(list, function(a, b)
		local ta, tb = a.endedAt or a.startedAt or 0, b.endedAt or b.startedAt or 0
		if ta ~= tb then
			return ta > tb
		end
		return tostring(a.id) > tostring(b.id)
	end)
	return list
end

-- The newest run the user has not rated or dismissed yet.
function Runs.LatestPending(db)
	for _, run in ipairs(Runs.List(db)) do
		if run.prompt == "pending" then
			return run
		end
	end
	return nil
end

-- Runs for the "Rate your squad" alert: still pending, recent, and newer than the last time
-- the user closed the alert. Newest first.
function Runs.AlertList(db, now)
	local list = {}
	local since = math.max(now - Runs.ALERT_WINDOW, db.alertDismissedAt or 0)
	for _, run in ipairs(Runs.List(db)) do
		if run.prompt == "pending" and (run.endedAt or 0) > since then
			list[#list + 1] = run
		end
	end
	return list
end

function Runs.SetPrompt(db, runId, value)
	local run = db.runs[runId]
	if run then
		run.prompt = value
	end
end

-- How many members of a run have a rating for that run.
function Runs.RatedCount(db, run)
	local rated = 0
	for _, member in ipairs(run.members or {}) do
		if ns.Ratings.ForRun(db.players[member.pid], run.id) then
			rated = rated + 1
		end
	end
	return rated
end
