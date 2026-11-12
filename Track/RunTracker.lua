-- Decides when a dungeon, raid or open-world group run starts and ends, using only events verified in the
-- Forever client. The rules themselves live in Data/Runs.lua (and are unit-tested there).
local _, ns = ...

local Debug = ns.Debug
local Compat = ns.Compat
local Events = ns.Events

local RunTracker = { pendingKills = 0, ticking = false, lastAction = nil }
ns.RunTracker = RunTracker

local RECHECK_SECONDS = 30

local function onFinished(run)
	local db = ns.db
	Debug.Log("RUN", "finished: %d members, %d boss kills", #run.members, run.bossKills or 0)
	ns.DB.Prune(db, Compat.Now())
	if ns.SquadAlert then
		ns.SquadAlert.Schedule()
	end
	if ns.MainWindow then
		ns.MainWindow.Refresh()
	end
end

local function check()
	local db = ns.db
	if not db then
		return
	end
	while RunTracker.pendingKills > 0 do
		ns.Runs.AddBossKill(db)
		RunTracker.pendingKills = RunTracker.pendingKills - 1
	end

	local state = Compat.InstanceState()
	local action, finished = ns.Runs.Evaluate(db, state, Compat.Now(), Compat.Ruleset())
	if action ~= RunTracker.lastAction then
		Debug.Log(
			"RUN",
			"%s (inInstance=%s type=%s maxPlayers=%s inGroup=%s)",
			action,
			tostring(state.inInstance),
			tostring(state.instanceType),
			tostring(state.maxPlayers),
			tostring(state.inGroup)
		)
		RunTracker.lastAction = action
	end

	if finished then
		onFinished(finished)
	end
	if ns.Runs.IsInside(db) then
		ns.Roster.Schedule()
	end
	if action == "pending" and not RunTracker.ticking then
		-- Outside the instance: look again until the grace period or the group ends.
		RunTracker.ticking = true
		C_Timer.After(RECHECK_SECONDS, function()
			RunTracker.ticking = false
			RunTracker.Request()
		end)
	end
end

function RunTracker.Request()
	Events.RunOutOfCombat("run", check)
end

local function schedule()
	Events.Debounce("run", 1.5, RunTracker.Request)
end

Events.On("PLAYER_ENTERING_WORLD", "RunTracker", schedule)
Events.On("ZONE_CHANGED_NEW_AREA", "RunTracker", schedule)
Events.On("GROUP_ROSTER_UPDATE", "RunTracker", schedule)
Events.On("GROUP_LEFT", "RunTracker", schedule)

-- Boss kills are metadata only. Nothing depends on this event firing in Forever dungeons.
Events.On("ENCOUNTER_END", "RunTracker", function(_, _, _, _, _, success)
	if Compat.Clean(success, "number") == 1 then
		RunTracker.pendingKills = RunTracker.pendingKills + 1
		schedule()
	end
end)
