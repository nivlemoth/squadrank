local helper = dofile("spec/helper.lua")
local NOW = helper.NOW

local function inside(id, inGroup)
	return {
		inInstance = true,
		instanceType = "party",
		instanceID = id or 36,
		instanceName = "Deadmines",
		maxPlayers = 5,
		inGroup = inGroup ~= false,
	}
end

local function outside(inGroup)
	return { inInstance = false, instanceType = "none", inGroup = inGroup ~= false, zoneName = "Elwynn Forest" }
end

describe("Runs.Evaluate", function()
	local ns, db, Runs

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		db.settings.minRunMinutes = 0
		Runs = ns.Runs
	end)

	it("keeps a very short dungeon visit without asking for a rating", function()
		db.settings.minRunMinutes = 3
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "g:x", "dps")
		local short = Runs.Finish(db, NOW + 60)
		assert.equals("skipped", short.prompt)
		Runs.Evaluate(db, inside(), NOW + 100)
		Runs.AddMember(db, "g:x", "dps")
		Runs.Evaluate(db, inside(), NOW + 400)
		local long = Runs.Finish(db, NOW + 400)
		assert.equals("pending", long.prompt)
	end)

	it("counts wipes on the current run only", function()
		assert.is_false(Runs.AddWipe(db))
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddWipe(db)
		Runs.AddWipe(db)
		assert.equals(2, db.currentRun.wipes)
	end)

	it("is idle in the open world when not grouped", function()
		assert.equals("idle", Runs.Evaluate(db, outside(false), NOW))
		assert.is_nil(db.currentRun)
	end)

	it("tracks battlegrounds and arenas, ignores other instance types", function()
		local state = inside()
		state.instanceType = "scenario"
		assert.equals("idle", Runs.Evaluate(db, state, NOW))
		state.instanceType = "pvp"
		assert.equals("started", Runs.Evaluate(db, state, NOW))
		assert.equals("pvp", Runs.Category(db.currentRun))
		ns.Runs.AddMember(db, "g:x", "dps")
		local finished = Runs.Finish(db, NOW + 600)
		assert.equals("skipped", finished.prompt)
	end)

	describe("the PvP area keeps crowds out of the main views", function()
		local function stored(id, fields, members)
			local run = { id = id, members = {}, prompt = "pending", endedAt = NOW - 60, startedAt = NOW - 3600 }
			for k, v in pairs(fields) do
				run[k] = v
			end
			for _, pid in ipairs(members) do
				run.members[#run.members + 1] = { pid = pid }
			end
			db.runs[id] = run
			return run
		end

		it("treats a raid group roaming with War Mode on as world PvP", function()
			local state = outside(true)
			state.inRaid, state.warMode = true, true
			Runs.Evaluate(db, state, NOW)
			assert.equals("wpvp", Runs.Category(db.currentRun))
		end)

		it("knows crowds from small groups", function()
			assert.is_true(Runs.IsCrowd({ kind = "group", wpvp = true }))
			assert.is_true(Runs.IsCrowd({ kind = "group", raid = true }))
			assert.is_true(Runs.IsCrowd({ instanceType = "pvp" }))
			assert.is_false(Runs.IsCrowd({ instanceType = "arena" }))
			assert.is_true(Runs.InPvPArea({ instanceType = "arena" }))
			assert.is_false(Runs.InPvPArea({ instanceType = "party" }))
			assert.is_false(Runs.IsCrowd({ kind = "group", quests = { { id = 1 } } }))
		end)

		it("never offers a crowd in the alert, even one saved as pending by an older version", function()
			stored("old", { kind = "group", wpvp = true, instanceName = "Hillsbrad" }, { "g:a", "g:b" })
			stored("dm", { instanceType = "party", instanceName = "Deadmines" }, { "g:c" })
			local list = Runs.AlertList(db, NOW)
			assert.equals(1, #list)
			assert.equals("dm", list[1].id)
		end)

		it("finishes a world PvP raid without asking", function()
			local state = outside(true)
			state.inRaid, state.zonePvP = true, "combat"
			Runs.Evaluate(db, state, NOW)
			Runs.AddMember(db, "g:x", "dps")
			assert.equals("skipped", Runs.Finish(db, NOW + 1800).prompt)
		end)

		it("splits players met only in crowds from everyone else", function()
			stored("raid", { kind = "group", raid = true }, { "g:stranger", "g:friend" })
			stored("dm", { instanceType = "party" }, { "g:friend" })
			stored("arena", { instanceType = "arena" }, { "g:mate" })
			local crowdOnly, pvp = Runs.PlayerAreas(db)
			assert.is_true(crowdOnly["g:stranger"])
			assert.is_nil(crowdOnly["g:friend"])
			assert.is_nil(crowdOnly["g:mate"])
			assert.is_true(pvp["g:stranger"] and pvp["g:friend"] and pvp["g:mate"])
		end)

		it("forgets unrated crowd strangers after two weeks, keeps everyone who matters", function()
			local old = NOW - 20 * 86400
			for _, pid in ipairs({ "g:stranger", "g:rated", "g:avoided", "g:friend" }) do
				db.players[pid] = { name = pid, lastSeen = old, ratings = {}, rulesets = {} }
			end
			db.players["g:rated"].ratings = { { score = 4, createdAt = old } }
			db.players["g:avoided"].avoid = true
			stored("raid", { kind = "group", wpvp = true }, { "g:stranger", "g:rated", "g:avoided", "g:friend" })
			stored("dm", { instanceType = "party" }, { "g:friend" })
			ns.DB.Prune(db, NOW)
			assert.is_nil(db.players["g:stranger"])
			assert.is_not_nil(db.players["g:rated"])
			assert.is_not_nil(db.players["g:avoided"])
			assert.is_not_nil(db.players["g:friend"])
		end)
	end)

	describe("group types, bosses and quests", function()
		local function run(fields)
			local r = { members = {} }
			for k, v in pairs(fields) do
				r[k] = v
			end
			return r
		end

		it("names the type of every run, old runs included", function()
			assert.equals("dungeon", Runs.Category(run({ instanceType = "party" })))
			assert.equals("raid", Runs.Category(run({ instanceType = "raid" })))
			assert.equals("pvp", Runs.Category(run({ instanceType = "arena" })))
			assert.equals("dungeon", Runs.Category(run({})))
			assert.equals("world", Runs.Category(run({ kind = "group" })))
			assert.equals("quest", Runs.Category(run({ kind = "group", quests = { { id = 1 } } })))
			assert.equals("worldraid", Runs.Category(run({ kind = "group", raid = true, quests = { { id = 1 } } })))
			assert.equals("wpvp", Runs.Category(run({ kind = "group", raid = true, wpvp = true })))
		end)

		it("marks an open-world group as a raid or world PvP from what it saw", function()
			local state = outside(true)
			Runs.Evaluate(db, state, NOW)
			assert.equals("world", Runs.Category(db.currentRun))
			state.inRaid = true
			Runs.Evaluate(db, state, NOW + 60)
			assert.equals("worldraid", Runs.Category(db.currentRun))
			state.zonePvP = "combat"
			Runs.Evaluate(db, state, NOW + 120)
			assert.equals("wpvp", Runs.Category(db.currentRun))
		end)

		it("keeps each boss once, with its name, and counts unnamed kills", function()
			Runs.Evaluate(db, inside(), NOW)
			assert.is_true(Runs.AddBoss(db, 101, "Boss A", NOW))
			assert.is_false(Runs.AddBoss(db, 101, "Boss A", NOW + 1))
			assert.is_true(Runs.AddBoss(db, 102, "Boss B", NOW + 2))
			Runs.AddBossKill(db)
			assert.equals(3, db.currentRun.bossKills)
			assert.equals("Boss B", db.currentRun.bosses[2].name)
		end)

		it("records quests progressed and completed, once each, capped", function()
			assert.is_false(Runs.AddQuest(db, 7, "Nope", true))
			Runs.Evaluate(db, outside(true), NOW)
			Runs.AddQuest(db, 7, "Kill ten rats", false)
			Runs.AddQuest(db, 8, nil, false)
			Runs.AddQuest(db, 7, nil, true)
			Runs.AddQuest(db, 8, "Deliver", false)
			local done, progressed = Runs.QuestCounts(db.currentRun)
			assert.equals(1, done)
			assert.equals(1, progressed)
			assert.equals("Kill ten rats", db.currentRun.quests[1].title)
			assert.equals("Deliver", db.currentRun.quests[2].title)
			for id = 100, 200 do
				Runs.AddQuest(db, id, nil, true)
			end
			assert.equals(Runs.MAX_QUESTS, #db.currentRun.quests)
			assert.equals("quest", Runs.Category(db.currentRun))
		end)
	end)

	it("starts a run on entering a dungeon and saves it in the database", function()
		assert.equals("started", Runs.Evaluate(db, inside(), NOW, "Normal"))
		assert.equals(36, db.currentRun.instanceID)
		assert.equals("Normal", db.currentRun.ruleset)
		assert.is_true(Runs.IsInside(db))
	end)

	it("resumes the same run after a reload inside the instance", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a", "tank")
		local id = db.currentRun.id
		assert.equals("resumed", Runs.Evaluate(db, inside(), NOW + 600))
		assert.equals(id, db.currentRun.id)
		assert.equals(1, #db.currentRun.members)
	end)

	it("keeps the run open while outside for less than the grace period", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		assert.equals("pending", Runs.Evaluate(db, outside(), NOW + 100))
		assert.is_false(Runs.IsInside(db))
		assert.equals("pending", Runs.Evaluate(db, outside(), NOW + 100 + Runs.OUTSIDE_GRACE - 1))
		assert.equals("resumed", Runs.Evaluate(db, inside(), NOW + 200))
		assert.is_true(Runs.IsInside(db))
	end)

	it("finishes after the grace period outside", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		Runs.Evaluate(db, outside(), NOW + 100)
		local action, run = Runs.Evaluate(db, outside(), NOW + 100 + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.equals(NOW + 100, run.endedAt)
		assert.equals("pending", run.prompt)
		assert.equals(2, run.groupSize)
		assert.equals(run, db.runs[run.id])
		-- Still grouped: the squad carries on as an open-world group run.
		assert.equals("group", db.currentRun.kind)
		assert.equals(run.id, db.currentRun.after)
	end)

	it("finishes after the grace period when the group is left", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		local id = db.currentRun.id
		assert.equals("pending", Runs.Evaluate(db, outside(false), NOW + 50))
		assert.equals(id, db.currentRun.id)
		local action, run = Runs.Evaluate(db, outside(false), NOW + 50 + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.equals(id, run.id)
		assert.is_nil(db.currentRun)
	end)

	it("does not finish on a single false group reading", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		local id = db.currentRun.id
		assert.equals("pending", Runs.Evaluate(db, outside(false), NOW + 50))
		assert.equals(id, db.currentRun.id)
		assert.equals("resumed", Runs.Evaluate(db, inside(), NOW + 60))
		assert.equals(id, db.currentRun.id)
		assert.is_true(Runs.IsInside(db))
	end)

	it("keeps the run open when a member leaves while the player stays inside", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a", "healer")
		Runs.AddMember(db, "n:b", "dps")
		local id = db.currentRun.id
		assert.equals("resumed", Runs.Evaluate(db, inside(36, false), NOW + 60))
		assert.equals(id, db.currentRun.id)
		assert.equals(2, #db.currentRun.members)
	end)

	it("discards a run with no other members", function()
		Runs.Evaluate(db, inside(), NOW)
		assert.equals("pending", Runs.Evaluate(db, outside(false), NOW + 50))
		local action, run = Runs.Evaluate(db, outside(false), NOW + 50 + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.is_nil(run)
		assert.is_nil(next(db.runs))
	end)

	it("closes the old run and starts a new one in a different instance", function()
		Runs.Evaluate(db, inside(36), NOW)
		Runs.AddMember(db, "n:a")
		local action, finished = Runs.Evaluate(db, inside(48), NOW + 900)
		assert.equals("started", action)
		assert.equals(36, finished.instanceID)
		assert.equals(48, db.currentRun.instanceID)
	end)

	local function finishRun(now)
		Runs.Evaluate(db, inside(36), now)
		Runs.AddMember(db, "n:a", "healer")
		local id = db.currentRun.id
		assert.equals("pending", Runs.Evaluate(db, outside(false), now + 50))
		local action, run = Runs.Evaluate(db, outside(false), now + 50 + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.equals(id, run.id)
		return id, run
	end

	it("reopens the same run when the group re-enters within 15 minutes", function()
		local id, finished = finishRun(NOW)
		local state = inside(36)
		state.memberPids = { "n:a" }
		local action = Runs.Evaluate(db, state, finished.endedAt + 600)
		assert.equals("resumed", action)
		assert.equals(id, db.currentRun.id)
		assert.is_nil(db.currentRun.endedAt)
		assert.equals("pending", db.currentRun.prompt)
		assert.is_nil(db.runs[id])
		assert.equals(1, #db.currentRun.members)
	end)

	it("keeps a rated run rated when it is reopened", function()
		local id, finished = finishRun(NOW)
		db.players["n:a"] = { name = "A", ratings = {} }
		ns.Ratings.Save(db, "n:a", { score = 4, role = "healer", runId = id }, NOW + 100)
		db.runs[id].prompt = "done"
		local state = inside(36)
		state.memberPids = { "n:a" }
		assert.equals("resumed", Runs.Evaluate(db, state, finished.endedAt + 600))
		assert.equals("done", db.currentRun.prompt)
	end)

	it("starts a new run when re-entering the same instance with nobody from the old run", function()
		local id, finished = finishRun(NOW)
		local state = inside(36)
		state.memberPids = { "n:new" }
		assert.equals("started", Runs.Evaluate(db, state, finished.endedAt + 60))
		assert.is_not_nil(db.currentRun)
		assert.is_true(db.currentRun.id ~= id)
		assert.is_not_nil(db.runs[id])
	end)

	it("starts a new run when re-entering a different instance", function()
		local id, finished = finishRun(NOW)
		local state = inside(48)
		state.memberPids = { "n:a" }
		assert.equals("started", Runs.Evaluate(db, state, finished.endedAt + 60))
		assert.is_not_nil(db.currentRun)
		assert.is_true(db.currentRun.id ~= id)
		assert.equals(48, db.currentRun.instanceID)
	end)

	it("starts a new run when re-entering after the 15-minute window", function()
		local id, finished = finishRun(NOW)
		local state = inside(36)
		state.memberPids = { "n:a" }
		assert.equals("started", Runs.Evaluate(db, state, finished.endedAt + Runs.REOPEN_WINDOW + 1))
		assert.is_not_nil(db.currentRun)
		assert.is_true(db.currentRun.id ~= id)
	end)

	it("never deletes earlier runs of the same instance", function()
		for i = 0, 2 do
			local t = NOW + i * 10000
			Runs.Evaluate(db, inside(36), t)
			Runs.AddMember(db, "n:a")
			Runs.Evaluate(db, outside(false), t + 1800)
			Runs.Evaluate(db, outside(false), t + 1800 + Runs.OUTSIDE_GRACE)
		end
		assert.equals(3, ns.Util.Count(db.runs))
	end)

	it("does not resume a run that is many hours old", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		local oldId = db.currentRun.id
		local action, finished = Runs.Evaluate(db, inside(), NOW + Runs.RESUME_LIMIT + 1)
		assert.equals("started", action)
		assert.equals(oldId, finished.id)
		assert.is_true(db.currentRun.id ~= oldId)
	end)
end)

describe("Runs.Evaluate for open-world groups", function()
	local ns, db, Runs

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Runs = ns.Runs
	end)

	it("opens a group run named after the zone", function()
		assert.equals("grouped", Runs.Evaluate(db, outside(), NOW))
		assert.equals("group", db.currentRun.kind)
		assert.equals("Elwynn Forest", db.currentRun.instanceName)
		assert.is_true(Runs.IsInside(db))
		assert.equals("grouped", Runs.Evaluate(db, outside(), NOW + 60))
	end)

	it("stores a group of 5 minutes or more when it breaks up, with the end time", function()
		Runs.Evaluate(db, outside(), NOW)
		Runs.AddMember(db, "n:a")
		local leave = NOW + Runs.GROUP_MIN + 30
		assert.equals("pending", Runs.Evaluate(db, outside(false), leave))
		local action, run = Runs.Evaluate(db, outside(false), leave + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.equals("pending", run.prompt)
		assert.equals(leave, run.endedAt)
		assert.equals(run, db.runs[run.id])
	end)

	it("drops a short group (a summon, a trade)", function()
		Runs.Evaluate(db, outside(), NOW)
		Runs.AddMember(db, "n:a")
		local leave = NOW + Runs.GROUP_MIN - 1
		assert.equals("pending", Runs.Evaluate(db, outside(false), leave))
		local action, run = Runs.Evaluate(db, outside(false), leave + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.is_nil(run)
		assert.is_nil(next(db.runs))
	end)

	it("becomes a dungeon run when the group walks into a dungeon", function()
		Runs.Evaluate(db, outside(), NOW)
		Runs.AddMember(db, "n:a")
		local id = db.currentRun.id
		assert.equals("started", Runs.Evaluate(db, inside(), NOW + 900))
		assert.equals(id, db.currentRun.id)
		assert.is_nil(db.currentRun.kind)
		assert.equals(36, db.currentRun.instanceID)
		assert.equals("Deadmines", db.currentRun.instanceName)
		assert.equals(1, #db.currentRun.members)
	end)

	it("does not ask twice about a group that stayed together after its dungeon", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		Runs.Evaluate(db, outside(), NOW + 100)
		local action, dungeon = Runs.Evaluate(db, outside(), NOW + 100 + Runs.OUTSIDE_GRACE)
		assert.equals("finished", action)
		assert.is_not_nil(dungeon)
		assert.equals("group", db.currentRun.kind)
		assert.equals(dungeon.id, db.currentRun.after)
		assert.equals("grouped", Runs.Evaluate(db, outside(), NOW + 900))
		Runs.AddMember(db, "n:a")
		local leave = NOW + 900 + Runs.GROUP_MIN
		assert.equals("pending", Runs.Evaluate(db, outside(false), leave))
		local _, group = Runs.Evaluate(db, outside(false), leave + Runs.OUTSIDE_GRACE)
		assert.is_nil(group)
		assert.equals(1, ns.Util.Count(db.runs))
	end)

	it("keeps that group when someone new joined after the dungeon", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		Runs.Evaluate(db, outside(), NOW + 100)
		Runs.Evaluate(db, outside(), NOW + 100 + Runs.OUTSIDE_GRACE)
		Runs.AddMember(db, "n:a")
		Runs.AddMember(db, "n:b")
		local leave = NOW + 900 + Runs.GROUP_MIN
		assert.equals("pending", Runs.Evaluate(db, outside(false), leave))
		local _, group = Runs.Evaluate(db, outside(false), leave + Runs.OUTSIDE_GRACE)
		assert.is_not_nil(group)
		assert.equals(2, ns.Util.Count(db.runs))
	end)
end)

describe("Runs helpers", function()
	local ns, db, Runs

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Runs = ns.Runs
	end)

	it("adds each member once and updates the role", function()
		Runs.Evaluate(db, inside(), NOW)
		assert.is_true(Runs.AddMember(db, "n:a"))
		assert.is_false(Runs.AddMember(db, "n:a", "healer"))
		assert.equals(1, #db.currentRun.members)
		assert.equals("healer", db.currentRun.members[1].role)
	end)

	it("lists runs newest first and finds the latest pending one", function()
		db.runs.run1 = { id = "run1", endedAt = NOW, prompt = "done", members = {} }
		db.runs.run2 = { id = "run2", endedAt = NOW + 10, prompt = "pending", members = {} }
		db.runs.run3 = { id = "run3", endedAt = NOW + 20, prompt = "skipped", members = {} }
		assert.equals("run3", Runs.List(db)[1].id)
		assert.equals("run2", Runs.LatestPending(db).id)
		Runs.SetPrompt(db, "run2", "done")
		assert.is_nil(Runs.LatestPending(db))
	end)

	it("offers recent pending runs to the alert, newer than the last dismissal", function()
		db.runs.old = { id = "old", endedAt = NOW - Runs.ALERT_WINDOW - 1, prompt = "pending", members = {} }
		db.runs.a = { id = "a", endedAt = NOW - 100, prompt = "pending", members = {} }
		db.runs.b = { id = "b", endedAt = NOW - 10, prompt = "pending", members = {} }
		db.runs.c = { id = "c", endedAt = NOW - 5, prompt = "done", members = {} }
		local list = Runs.AlertList(db, NOW)
		assert.equals(2, #list)
		assert.equals("b", list[1].id)
		db.alertDismissedAt = NOW - 50
		list = Runs.AlertList(db, NOW)
		assert.equals(1, #list)
		assert.equals("b", list[1].id)
	end)

	it("counts rated members of a run", function()
		ns.Players.BuildIndex(db)
		local a = ns.Players.Resolve(db, { name = "A" }, NOW)
		local b = ns.Players.Resolve(db, { name = "B" }, NOW)
		db.runs.run1 = { id = "run1", members = { { pid = a }, { pid = b }, { pid = "n:gone" } } }
		ns.Ratings.Save(db, a, { score = 4, role = "dps", runId = "run1" }, NOW)
		assert.equals(1, Runs.RatedCount(db, db.runs.run1))
	end)
end)

describe("Session", function()
	local ns, db, Session

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Session = ns.Session
	end)

	it("returns each player as new only once per session", function()
		assert.same({ "n:a", "n:b" }, Session.TakeNew(db, { "n:a", "n:b" }, NOW))
		assert.same({ "n:c" }, Session.TakeNew(db, { "n:a", "n:b", "n:c" }, NOW + 5))
		assert.same({}, Session.TakeNew(db, { "n:a", "n:c" }, NOW + 10))
	end)

	it("survives a reload because it lives in the database", function()
		Session.TakeNew(db, { "n:a" }, NOW)
		local reloaded = ns.DB.Open(db, NOW + 30)
		assert.same({}, Session.TakeNew(reloaded, { "n:a" }, NOW + 30))
	end)

	it("starts over after the group ends", function()
		Session.TakeNew(db, { "n:a" }, NOW)
		Session.End(db)
		assert.same({ "n:a" }, Session.TakeNew(db, { "n:a" }, NOW + 5))
	end)

	it("starts over when the group key changes or the session is very old", function()
		Session.Ensure(db, NOW, "Party-1")
		Session.TakeNew(db, { "n:a" }, NOW)
		Session.Ensure(db, NOW + 5, "Party-1")
		assert.same({}, Session.TakeNew(db, { "n:a" }, NOW + 5))
		Session.Ensure(db, NOW + 10, "Party-2")
		assert.same({ "n:a" }, Session.TakeNew(db, { "n:a" }, NOW + 10))
		assert.same({ "n:a" }, Session.TakeNew(db, { "n:a" }, NOW + 10 + Session.MAX_AGE + 1))
	end)
end)
