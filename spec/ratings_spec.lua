local helper = dofile("spec/helper.lua")
local NOW, DAY = helper.NOW, helper.DAY

describe("Ratings.Save", function()
	local ns, db, Ratings, pid

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
		Ratings = ns.Ratings
		ns.Players.BuildIndex(db)
		pid = ns.Players.Resolve(db, { name = "Bob", guid = "Player-1-0001" }, NOW)
	end)

	it("stores a valid rating with a unique id", function()
		local a = Ratings.Save(db, pid, { score = 4, role = "tank", tags = { "efficient" }, note = "ok" }, NOW)
		local b = Ratings.Save(db, pid, { score = 2, role = "tank" }, NOW + 1)
		assert.equals(4, a.score)
		assert.equals("tank", a.role)
		assert.same({ "efficient" }, a.tags)
		assert.equals(NOW, a.createdAt)
		assert.is_true(a.id ~= b.id)
		assert.equals(2, #db.players[pid].ratings)
	end)

	it("rejects bad scores and roles", function()
		local _, err = Ratings.Save(db, pid, { score = 6, role = "tank" }, NOW)
		assert.equals("score", err)
		_, err = Ratings.Save(db, pid, { score = 2.5, role = "tank" }, NOW)
		assert.equals("score", err)
		_, err = Ratings.Save(db, pid, { score = 3, role = "wizard" }, NOW)
		assert.equals("role", err)
		_, err = Ratings.Save(db, "n:nobody", { score = 3, role = "dps" }, NOW)
		assert.equals("player", err)
		assert.equals(0, #db.players[pid].ratings)
	end)

	it("keeps an unknown role unknown instead of guessing DPS", function()
		-- The client says NONE for a manual group; the compat layer turns that into nil.
		local clean = Ratings.Validate({ score = 4, role = nil })
		assert.is_nil(clean.role)
		local r = Ratings.Save(db, pid, { score = 4 }, NOW)
		assert.equals(4, r.score)
		assert.is_nil(r.role)
		-- NONE is not a role we store, and it is certainly not DPS.
		local none, err = Ratings.Save(db, pid, { score = 4, role = "NONE" }, NOW + 1)
		assert.is_nil(none)
		assert.equals("role", err)
		assert.equals(1, #db.players[pid].ratings)
	end)

	it("drops unknown and duplicate tags and orders the rest", function()
		local r =
			Ratings.Save(db, pid, { score = 3, role = "dps", tags = { "toxic", "hacker", "efficient", "toxic" } }, NOW)
		assert.same({ "efficient", "toxic" }, r.tags)
	end)

	it("sanitizes and limits the note", function()
		local r =
			Ratings.Save(db, pid, { score = 3, role = "dps", note = "|cffff0000" .. string.rep("x", 300) .. "|r" }, NOW)
		assert.equals(140, #r.note)
		assert.is_nil(r.note:find("|", 1, true))
	end)

	it("keeps one rating per run and edits it on a second save", function()
		local first = Ratings.Save(db, pid, { score = 2, role = "healer", runId = "run1" }, NOW)
		local second = Ratings.Save(db, pid, { score = 5, role = "healer", runId = "run1", note = "better" }, NOW + 60)
		assert.equals(first.id, second.id)
		assert.equals(1, #db.players[pid].ratings)
		assert.equals(5, second.score)
		assert.equals(NOW, second.createdAt)
		assert.equals(NOW + 60, second.updatedAt)
		assert.equals(second, Ratings.ForRun(db.players[pid], "run1"))
		assert.is_nil(Ratings.ForRun(db.players[pid], "run2"))
	end)

	it("edits by id and deletes by id", function()
		local r = Ratings.Save(db, pid, { score = 2, role = "dps" }, NOW)
		Ratings.Save(db, pid, { id = r.id, score = 3, role = "tank" }, NOW + 5)
		assert.equals(1, #db.players[pid].ratings)
		assert.equals("tank", db.players[pid].ratings[1].role)
		assert.is_true(Ratings.Delete(db, pid, r.id))
		assert.is_false(Ratings.Delete(db, pid, r.id))
		assert.equals(0, #db.players[pid].ratings)
	end)
end)

describe("Ratings.Summary", function()
	local ns, Ratings

	local function rec(list)
		local ratings = {}
		for i, r in ipairs(list) do
			ratings[i] = {
				id = "r" .. i,
				score = r[1],
				role = r[2],
				createdAt = NOW - (r[3] or 0) * DAY,
				updatedAt = NOW - (r[3] or 0) * DAY,
				tags = r.tags or {},
				note = r.note or "",
			}
		end
		return { name = "Bob", ratings = ratings }
	end

	before_each(function()
		ns = helper.load()
		Ratings = ns.Ratings
	end)

	it("shows New below the minimum number of ratings", function()
		local s = Ratings.Summary(rec({ { 5, "tank" }, { 5, "tank" } }), NOW, 3)
		assert.equals("new", s.label)
		assert.equals(2, s.count)
		assert.equals("new", Ratings.Summary(rec({}), NOW, 3).label)
	end)

	it("labels Trusted, Mixed and Caution by score", function()
		assert.equals("trusted", Ratings.Summary(rec({ { 5, "tank" }, { 4, "tank" }, { 4, "tank" } }), NOW, 3).label)
		assert.equals("mixed", Ratings.Summary(rec({ { 5, "tank" }, { 3, "tank" }, { 2, "tank" } }), NOW, 3).label)
		assert.equals("caution", Ratings.Summary(rec({ { 1, "dps" }, { 2, "dps" }, { 3, "dps" } }), NOW, 3).label)
	end)

	it("respects a different minimum threshold", function()
		assert.equals("trusted", Ratings.Summary(rec({ { 5, "tank" } }), NOW, 1).label)
	end)

	it("weights recent ratings more than old ones", function()
		-- Plain mean is 3.0 (mixed). Three recent 1s outweigh three year-old 5s.
		local s = Ratings.Summary(
			rec({
				{ 5, "dps", 365 },
				{ 5, "dps", 365 },
				{ 5, "dps", 365 },
				{ 1, "dps", 0 },
				{ 1, "dps", 0 },
				{ 1, "dps", 0 },
			}),
			NOW,
			3
		)
		assert.equals("caution", s.label)
		assert.is_true(s.weighted < 2)
	end)

	it("reports per-role averages", function()
		local s = Ratings.Summary(rec({ { 5, "healer" }, { 4, "healer" }, { 1, "dps" } }), NOW, 3)
		assert.equals(4.5, s.roles.healer.avg)
		assert.equals(2, s.roles.healer.count)
		assert.equals(1, s.roles.dps.count)
		assert.is_nil(s.roles.tank)
	end)

	it("keeps each role's scores and each player's history separate", function()
		local s = Ratings.Summary(rec({ { 5, "tank" }, { 1, "healer" }, { 3, "dps" } }), NOW, 3)
		assert.equals(5, s.roles.tank.avg)
		assert.equals(1, s.roles.healer.avg)
		assert.equals(3, s.roles.dps.avg)
		assert.equals(1, s.roles.tank.count)
		assert.equals(1, s.roles.healer.count)
		assert.equals(1, s.roles.dps.count)

		local other = Ratings.Summary({
			name = "Eve",
			ratings = {
				{ id = "e1", score = 2, role = "healer", createdAt = NOW, updatedAt = NOW, tags = {} },
			},
		}, NOW, 3)
		assert.equals(2, other.roles.healer.avg)
		assert.is_nil(other.roles.tank)
		assert.is_nil(other.roles.dps)
		assert.equals(5, s.roles.tank.avg)
	end)

	it("ranks tags by count, then by list order", function()
		local s = Ratings.Summary(
			rec({
				{ 4, "dps", tags = { "toxic", "efficient" } },
				{ 4, "dps", tags = { "toxic" } },
				{ 4, "dps", tags = { "afk" } },
			}),
			NOW,
			3
		)
		assert.equals("toxic", s.topTags[1].id)
		assert.equals(2, s.topTags[1].count)
		assert.equals("efficient", s.topTags[2].id)
		assert.equals("afk", s.topTags[3].id)
	end)

	it("returns the most recent note and role", function()
		local s = Ratings.Summary(
			rec({ { 4, "tank", 10, note = "old note" }, { 4, "healer", 2, note = "new note" }, { 4, "dps", 0 } }),
			NOW,
			3
		)
		assert.equals("new note", s.lastNote)
		assert.equals("dps", s.lastRole)
	end)

	it("copes with imported ratings that have no role", function()
		local r = rec({ { 5 }, { 5 }, { 5 } })
		local s = Ratings.Summary(r, NOW, 3)
		assert.equals("trusted", s.label)
		assert.is_nil(next(s.roles))
	end)
end)
