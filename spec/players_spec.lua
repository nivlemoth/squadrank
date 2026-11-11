local helper = dofile("spec/helper.lua")
local NOW = helper.NOW

describe("Players.Resolve", function()
	local ns, db, Players

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Players = ns.Players
		Players.BuildIndex(db)
	end)

	it("keys by GUID when one is known", function()
		local pid, rec = Players.Resolve(db, { name = "Bob", suffix = "Vale", guid = "Player-1-0001" }, NOW, "Normal")
		assert.equals("g:Player-1-0001", pid)
		assert.equals("Bob", rec.name)
		assert.is_true(rec.rulesets.Normal)
	end)

	it("falls back to a name key without a GUID", function()
		local pid = Players.Resolve(db, { name = "Bob", suffix = "Vale" }, NOW)
		assert.equals("n:bob-vale", pid)
	end)

	it("returns the same record on a second sighting", function()
		local pid1 = Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW)
		local pid2, rec = Players.Resolve(db, { name = "Bob", guid = "Player-1-0001", level = 20 }, NOW + 60)
		assert.equals(pid1, pid2)
		assert.equals(NOW + 60, rec.lastSeen)
		assert.equals(NOW, rec.firstSeen)
		assert.equals(20, rec.level)
		assert.equals(1, ns.Util.Count(db.players))
	end)

	it("re-keys a name record when its GUID appears, and updates runs and session", function()
		local namePid = Players.Resolve(db, { name = "bob" }, NOW)
		db.players[namePid].ratings[1] = { id = "r1", score = 4, createdAt = NOW }
		db.runs.run1 = { id = "run1", members = { { pid = namePid } } }
		db.session = { startedAt = NOW, seen = { [namePid] = true } }

		local pid, rec = Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW + 5)
		assert.equals("g:Player-1-0001", pid)
		assert.equals(1, #rec.ratings)
		assert.equals("Bob", rec.name)
		assert.is_nil(db.players[namePid])
		assert.equals(pid, db.runs.run1.members[1].pid)
		assert.is_true(db.session.seen[pid])
		assert.is_nil(db.session.seen[namePid])
	end)

	it("merges a name record into an existing GUID record", function()
		local gpid = Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW)
		db.players[gpid].ratings[1] = { id = "r1", score = 5, createdAt = NOW }
		db.players["n:bob"] = {
			name = "Bob",
			firstSeen = NOW - 10,
			ratings = { { id = "r2", score = 1, createdAt = NOW - 10 } },
			rulesets = {},
		}
		db.runs.run1 = { id = "run1", members = { { pid = "n:bob" }, { pid = gpid } } }

		Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW + 5)
		assert.is_nil(db.players["n:bob"])
		assert.equals(2, #db.players[gpid].ratings)
		assert.equals("r2", db.players[gpid].ratings[1].id)
		assert.equals(1, #db.runs.run1.members)
	end)

	it("finds a GUID record by name when the GUID is not available this time", function()
		local gpid = Players.Resolve(db, { name = "Bob", suffix = "Vale", guid = "Player-1-0001" }, NOW)
		local pid = Players.Resolve(db, { name = "Bob", suffix = "Vale" }, NOW + 5)
		assert.equals(gpid, pid)
		assert.equals(1, ns.Util.Count(db.players))
	end)

	it("rebuilds the name index from saved data", function()
		local gpid = Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW)
		Players.index = {}
		Players.BuildIndex(db)
		assert.equals(gpid, Players.Resolve(db, { name = "Bob" }, NOW))
	end)
end)

describe("Players lookup and purge", function()
	local ns, db, Players

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Players = ns.Players
		Players.BuildIndex(db)
		Players.Resolve(db, { name = "Bob", suffix = "Vale", guid = "Player-1-0001" }, NOW)
		Players.Resolve(db, { name = "Bobby" }, NOW)
	end)

	it("finds by exact name, ignoring case", function()
		assert.same({ "g:Player-1-0001" }, Players.Find(db, "bob"))
		assert.same({ "g:Player-1-0001" }, Players.Find(db, " BOB-vale "))
		assert.same({}, Players.Find(db, "bo"))
		assert.same({}, Players.Find(db, ""))
	end)

	it("escapes pipes in display names", function()
		assert.equals("Bob-Vale", Players.DisplayName(db.players["g:Player-1-0001"]))
		assert.equals("a||b", Players.DisplayName({ name = "a|b" }))
		assert.equals("?", Players.DisplayName(nil))
	end)

	it("purges a player from records, runs and the session", function()
		local pid = "g:Player-1-0001"
		db.runs.run1 = { id = "run1", members = { { pid = pid }, { pid = "n:bobby" } } }
		db.session = { startedAt = NOW, seen = { [pid] = true } }
		assert.is_true(Players.Purge(db, pid))
		assert.is_nil(db.players[pid])
		assert.equals(1, #db.runs.run1.members)
		assert.is_nil(db.session.seen[pid])
		assert.same({}, Players.Find(db, "bob"))
		assert.is_false(Players.Purge(db, pid))
	end)
end)
