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
-- Re-entering the same instance shortly after a run ended, with a player from that run,
-- continues the run instead of saving a second copy of the same dungeon visit.
Runs.REOPEN_WINDOW = 15 * 60
-- An open-world group shorter than this (a quick summon, a trade) is not worth a prompt.
Runs.GROUP_MIN = 300
-- The "Rate your squad" alert offers runs that ended within this window.
Runs.ALERT_WINDOW = 3 * 86400

local TRACKED = { party = true, raid = true, pvp = true, arena = true }

-- What kind of group a run was. Instance runs take it from the instance type; open-world
-- group runs from what happened while grouped. Worked out on display, so older runs get one too.
Runs.CATEGORIES = { "quest", "world", "dungeon", "raid", "worldraid", "pvp", "wpvp" }
local INSTANCE_CATEGORY = { party = "dungeon", raid = "raid", pvp = "pvp", arena = "pvp", scenario = "dungeon" }
-- Zone PvP types (C_PvP.GetZonePVPInfo) where an open-world group counts as world PvP.
local WORLD_PVP_ZONES = { combat = true, arena = true }

-- Per-run caps, so a long questing session cannot grow the saved file without limit.
Runs.MAX_BOSSES = 30
Runs.MAX_QUESTS = 40

-- Records what an open-world group is doing (raid group, PvP zone) while it lasts.
local function markGroup(run, state)
	if state.inRaid then
		run.raid = true
	end
	-- A PvP zone, or a raid group roaming with War Mode on, is world PvP.
	if WORLD_PVP_ZONES[state.zonePvP] or (state.inRaid and state.warMode) then
		run.wpvp = true
	end
end

-- The PvP area: battlegrounds, arenas, world PvP and open-world raids. These groups have their own
-- page, so the main Players, Runs and Rate views stay about the groups you actually play with.
Runs.PVE_CATEGORIES = { "quest", "world", "dungeon", "raid" }
Runs.PVP_CATEGORIES = { "pvp", "wpvp", "worldraid" }
local PVP_AREA = { pvp = true, wpvp = true, worldraid = true }

function Runs.InPvPArea(run)
	return PVP_AREA[Runs.Category(run)] == true
end

-- A crowd: a PvP-area group too big to rate one by one (everything there but an arena team).
-- Crowds never raise the "Rate your squad" alert, and their strangers stay off the main lists.
function Runs.IsCrowd(run)
	return Runs.InPvPArea(run) and run.instanceType ~= "arena"
end

-- Returns two sets of pids: players met only in crowds (never in another group), and players
-- met in any PvP-area group. The current run counts too.
function Runs.PlayerAreas(db)
	local crowd, normal, pvp = {}, {}, {}
	local function scan(run)
		if type(run) ~= "table" or type(run.members) ~= "table" then
			return
		end
		local isCrowd, inArea = Runs.IsCrowd(run), Runs.InPvPArea(run)
		for _, member in ipairs(run.members) do
			if isCrowd then
				crowd[member.pid] = true
			else
				normal[member.pid] = true
			end
			if inArea then
				pvp[member.pid] = true
			end
		end
	end
	for _, run in pairs(db.runs) do
		scan(run)
	end
	scan(db.currentRun)
	local crowdOnly = {}
	for pid in pairs(crowd) do
		if not normal[pid] then
			crowdOnly[pid] = true
		end
	end
	return crowdOnly, pvp
end

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
		markGroup(run, state)
	else
		setInstance(run, state)
	end
	db.currentRun = run
	return run
end

-- The pids of the group as it is now. The tracker fills state.memberPids; tests may pass
-- either that or state.members = { pid, ... }.
local function currentPids(state)
	if type(state.memberPids) == "table" then
		return state.memberPids
	end
	if type(state.members) ~= "table" then
		return nil
	end
	local pids = {}
	for _, member in ipairs(state.members) do
		if type(member) == "string" then
			pids[#pids + 1] = member
		elseif type(member) == "table" and member.pid then
			pids[#pids + 1] = member.pid
		end
	end
	return pids
end

local function sharesMember(run, pids)
	if type(pids) ~= "table" then
		return false
	end
	local inRun = {}
	for _, member in ipairs(run.members or {}) do
		inRun[member.pid] = true
	end
	for _, pid in ipairs(pids) do
		if inRun[pid] then
			return true
		end
	end
	return false
end

-- A recent run for this instance that shares at least one player: the group reformed and
-- walked back in, so this is the same run rather than a second one.
local function recentRun(db, state, now)
	if state.instanceID == nil then
		return nil
	end
	local pids = currentPids(state)
	if not pids or #pids == 0 then
		return nil
	end
	local best
	for _, run in pairs(db.runs) do
		if
			type(run) == "table"
			and run.kind ~= "group"
			and run.instanceID == state.instanceID
			and type(run.endedAt) == "number"
			and now - run.endedAt <= Runs.REOPEN_WINDOW
			and sharesMember(run, pids)
		then
			if not best or (run.endedAt or 0) > (best.endedAt or 0) then
				best = run
			end
		end
	end
	return best
end

-- Moves a just-finished run back into the current slot. Its members stay as they were;
-- the roster adds anyone new and AddMember ignores duplicates.
local function reopen(db, state, now)
	local run = recentRun(db, state, now)
	if not run then
		return nil
	end
	db.runs[run.id] = nil
	db.currentRun = run
	run.endedAt = nil
	run.outsideSince = nil
	run.lastInside = now
	if Runs.RatedCount(db, run) == 0 then
		run.prompt = "pending"
	end
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
		local endedAt = run.outsideSince or now
		run.endedAt = (now - last > Runs.RESUME_LIMIT) and last or endedAt
		if run.endedAt - (run.startedAt or now) < Runs.GROUP_MIN or coveredByPrevious(db, run) then
			return nil
		end
	else
		run.endedAt = run.outsideSince or run.lastInside or now
	end
	run.outsideSince = nil
	run.lastInside = nil
	run.groupSize = #run.members + 1
	-- Crowds (battlegrounds, world PvP, open-world raids: up to 40 strangers) and a dungeon left after
	-- a minute or two are not worth asking about: both are kept, but without the alert.
	local minimum = (db.settings and tonumber(db.settings.minRunMinutes) or 0) * 60
	local short = run.kind ~= "group" and (run.endedAt - (run.startedAt or run.endedAt)) < minimum
	run.prompt = (Runs.IsCrowd(run) or short) and "skipped" or "pending"
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
			run.outsideSince = nil
			return "started"
		end
		if state.inGroup then
			run.outsideSince = nil
			run.lastInside = now
			markGroup(run, state)
			return "grouped"
		end
		-- One false group reading (a roster update, a reconnect) does not end the run.
		run.outsideSince = run.outsideSince or now
		if now - run.outsideSince >= Runs.OUTSIDE_GRACE then
			return "finished", Runs.Finish(db, now)
		end
		return "pending"
	end

	if not run then
		if inside then
			if reopen(db, state, now) then
				return "resumed"
			end
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

	-- Being outside is not proof the run ended (dying in Vanilla puts you outside), and a
	-- single false reading must not either. Wait for the grace period to pass.
	run.outsideSince = run.outsideSince or now
	if now - run.outsideSince >= Runs.OUTSIDE_GRACE then
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

-- A boss defeated during the current run. encounterID and name may be nil (count only).
-- The same encounter is counted once per run, whichever event reported it.
function Runs.AddBoss(db, encounterID, name, now)
	local run = db.currentRun
	if not run then
		return false
	end
	run.bosses = run.bosses or {}
	if encounterID then
		for _, boss in ipairs(run.bosses) do
			if boss.id == encounterID then
				return false
			end
		end
	end
	run.bossKills = (run.bossKills or 0) + 1
	if #run.bosses < Runs.MAX_BOSSES then
		run.bosses[#run.bosses + 1] = { id = encounterID, name = name, at = now }
	end
	return true
end

-- A failed boss attempt (a wipe) during the current run.
function Runs.AddWipe(db)
	local run = db.currentRun
	if not run then
		return false
	end
	run.wipes = (run.wipes or 0) + 1
	return true
end

function Runs.AddBossKill(db)
	return Runs.AddBoss(db, nil, nil, nil)
end

-- A quest completed (done = true) or progressed during the current run, by quest ID.
-- The title is kept only as a display fallback; it is looked up again when shown.
function Runs.AddQuest(db, questID, title, done)
	local run = db.currentRun
	if not run or type(questID) ~= "number" then
		return false
	end
	run.quests = run.quests or {}
	for _, quest in ipairs(run.quests) do
		if quest.id == questID then
			quest.done = quest.done or done or nil
			quest.title = title or quest.title
			return true
		end
	end
	if #run.quests >= Runs.MAX_QUESTS then
		return false
	end
	run.quests[#run.quests + 1] = { id = questID, title = title, done = done or nil }
	return true
end

-- Quests completed and quests only progressed during a run.
function Runs.QuestCounts(run)
	local done, progressed = 0, 0
	for _, quest in ipairs(run.quests or {}) do
		if quest.done then
			done = done + 1
		else
			progressed = progressed + 1
		end
	end
	return done, progressed
end

function Runs.Category(run)
	if run.kind == "group" then
		if run.wpvp then
			return "wpvp"
		end
		if run.raid then
			return "worldraid"
		end
		if run.quests and #run.quests > 0 then
			return "quest"
		end
		return "world"
	end
	return INSTANCE_CATEGORY[run.instanceType] or "dungeon"
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
		if run.prompt == "pending" and (run.endedAt or 0) > since and not Runs.IsCrowd(run) then
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
