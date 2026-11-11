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

local TRACKED = { party = true, raid = true }

local function start(db, state, now, ruleset)
	local run = {
		id = ns.DB.NextId(db, "run"),
		instanceID = state.instanceID,
		instanceName = state.instanceName,
		instanceType = state.instanceType,
		maxPlayers = state.maxPlayers,
		startedAt = now,
		lastInside = now,
		ruleset = ruleset,
		bossKills = 0,
		members = {},
	}
	db.currentRun = run
	return run
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
	run.endedAt = run.outsideSince or run.lastInside or now
	run.outsideSince = nil
	run.lastInside = nil
	run.groupSize = #run.members + 1
	run.prompt = "pending"
	db.runs[run.id] = run
	return run
end

-- state = { inInstance, instanceType, instanceID, instanceName, maxPlayers, inGroup }
-- Returns an action and, when a run was closed and stored, that run:
--   "idle"      nothing is being tracked
--   "started"   a new run began (a previous one may have been finished and is returned)
--   "resumed"   still (or again) inside the current run's instance
--   "pending"   outside the instance, waiting for the grace period or the group to end
--   "finished"  the current run ended
function Runs.Evaluate(db, state, now, ruleset)
	local run = db.currentRun
	local inside = state.inInstance and TRACKED[state.instanceType] and state.instanceID ~= nil

	if not run then
		if inside then
			start(db, state, now, ruleset)
			return "started"
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
		return "finished", Runs.Finish(db, now)
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
