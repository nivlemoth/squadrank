-- Decides when a dungeon, raid or open-world group run starts and ends, using only events verified in the
-- Forever client. The rules themselves live in Data/Runs.lua (and are unit-tested there).
local _, ns = ...

local Debug = ns.Debug
local Compat = ns.Compat
local Events = ns.Events

local RunTracker = { pendingBosses = {}, pendingQuests = {}, pendingWipes = 0, ticking = false, lastAction = nil }
ns.RunTracker = RunTracker

local RECHECK_SECONDS = 30
-- Events can arrive in combat, when the database must not be touched: they wait here.
local QUEUE_LIMIT = 60

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
	local now = Compat.Now()
	for _, boss in ipairs(RunTracker.pendingBosses) do
		ns.Runs.AddBoss(db, boss.id, boss.name, now)
	end
	for _, quest in ipairs(RunTracker.pendingQuests) do
		ns.Runs.AddQuest(db, quest.id, quest.title, quest.done)
	end
	for _ = 1, RunTracker.pendingWipes do
		ns.Runs.AddWipe(db)
	end
	RunTracker.pendingBosses, RunTracker.pendingQuests, RunTracker.pendingWipes = {}, {}, 0

	local state = Compat.InstanceState()
	state.memberPids = {}
	for _, unit in ipairs(Compat.GroupUnits()) do
		local ident = Compat.UnitIdentity(unit)
		if ident then
			local pid = ns.Players.Lookup(db, ident)
			if pid then
				state.memberPids[#state.memberPids + 1] = pid
			end
		end
	end
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

local function queue(list, item)
	if #list < QUEUE_LIMIT then
		list[#list + 1] = item
		schedule()
	end
end

local function cleanName(value)
	local text = Compat.Clean(value, "string")
	if text and text ~= "" then
		return ns.Util.Sanitize(text, 80)
	end
	return nil
end

-- Bosses and quests are metadata only: nothing else depends on these events firing in Forever.
-- Outside a run (not grouped) they are dropped when the queue is applied.
Events.On("ENCOUNTER_END", "RunTracker", function(_, encounterID, encounterName, _, _, success)
	local result = Compat.Clean(success, "number")
	if result == 1 then
		queue(RunTracker.pendingBosses, { id = Compat.Clean(encounterID, "number"), name = cleanName(encounterName) })
	elseif result == 0 and RunTracker.pendingWipes < QUEUE_LIMIT then
		RunTracker.pendingWipes = RunTracker.pendingWipes + 1
		schedule()
	end
end)

Events.On("BOSS_KILL", "RunTracker", function(_, encounterID, encounterName)
	queue(RunTracker.pendingBosses, { id = Compat.Clean(encounterID, "number"), name = cleanName(encounterName) })
end)

local function questTitle(questID)
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
		if ok then
			return cleanName(title)
		end
	end
	return nil
end

local function onQuest(questID, done)
	questID = Compat.Clean(questID, "number")
	if questID then
		queue(RunTracker.pendingQuests, { id = questID, title = questTitle(questID), done = done })
	end
end

Events.On("QUEST_TURNED_IN", "RunTracker", function(_, questID)
	onQuest(questID, true)
end)

Events.On("QUEST_WATCH_UPDATE", "RunTracker", function(_, questID)
	onQuest(questID, false)
end)
