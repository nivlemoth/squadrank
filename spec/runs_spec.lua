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
	return { inInstance = false, instanceType = "none", inGroup = inGroup ~= false }
end

describe("Runs.Evaluate", function()
	local ns, db, Runs

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Runs = ns.Runs
	end)

	it("is idle in the open world", function()
		assert.equals("idle", Runs.Evaluate(db, outside(), NOW))
		assert.is_nil(db.currentRun)
	end)

	it("ignores battlegrounds and other instance types", function()
		local state = inside()
		state.instanceType = "pvp"
		assert.equals("idle", Runs.Evaluate(db, state, NOW))
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
		assert.is_nil(db.currentRun)
		assert.equals(run, db.runs[run.id])
	end)

	it("finishes at once when the group is left", function()
		Runs.Evaluate(db, inside(), NOW)
		Runs.AddMember(db, "n:a")
		local action, run = Runs.Evaluate(db, outside(false), NOW + 50)
		assert.equals("finished", action)
		assert.is_not_nil(run)
	end)

	it("discards a run with no other members", function()
		Runs.Evaluate(db, inside(), NOW)
		local action, run = Runs.Evaluate(db, outside(false), NOW + 50)
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

	it("never deletes earlier runs of the same instance", function()
		for i = 0, 2 do
			local t = NOW + i * 10000
			Runs.Evaluate(db, inside(36), t)
			Runs.AddMember(db, "n:a")
			Runs.Evaluate(db, outside(false), t + 1800)
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
