local helper = dofile("spec/helper.lua")
local NOW, DAY = helper.NOW, helper.DAY

local function legacy()
	return {
		players = {
			["Stormrage-Bob-Alliance"] = {
				name = "Bob",
				realm = "Stormrage",
				class = "MAGE",
				lastRank = "GOOD",
				lastGrouped = "2025-05-31 20:15",
				groupedCount = 3,
			},
			["Stormrage-Eve-Horde"] = { name = "Eve", realm = "Stormrage", class = "UNKNOWN", lastRank = "BAD" },
			["Stormrage-Zed-Alliance"] = { name = "Zed", realm = "Stormrage", class = "ROGUE", lastRank = "" },
			["broken"] = "not a table",
		},
		squadHistory = {
			["2025-05-31 20:15-1234"] = {
				date = "2025-05-31 20:15",
				location = "Deadmines",
				type = "party",
				players = { ["Stormrage-Bob-Alliance"] = {}, ["Stormrage-Zed-Alliance"] = {}, ["gone"] = {} },
			},
		},
		settings = { showToast = false, minimapIconAngle = 1.5 },
	}
end

describe("DB.Open", function()
	local ns

	before_each(function()
		ns = helper.load()
	end)

	it("creates a fresh database with defaults", function()
		local db, info = ns.DB.Open(nil, NOW)
		assert.is_true(info.created)
		assert.is_false(info.readOnly)
		assert.equals(1, db.schema)
		assert.equals(true, db.settings.toastEnabled)
		assert.equals(3, db.settings.minRatings)
		assert.is_nil(db.backup)
	end)

	it("adds new default settings to an existing database and keeps user values", function()
		local raw = { schema = 1, nextId = 7, settings = { toastDuration = 12 }, players = {}, runs = {} }
		local db = ns.DB.Open(raw, NOW)
		assert.equals(raw, db)
		assert.equals(12, db.settings.toastDuration)
		assert.equals(true, db.settings.promptAfterRun)
		assert.equals(7, db.nextId)
	end)

	it("clamps out-of-range settings", function()
		local db = ns.DB.Open({ schema = 1, settings = { toastDuration = 999, minRatings = 0 } }, NOW)
		assert.equals(30, db.settings.toastDuration)
		assert.equals(1, db.settings.minRatings)
	end)

	it("repairs missing tables", function()
		local db = ns.DB.Open({ schema = 1, players = "oops" }, NOW)
		assert.equals("table", type(db.players))
		assert.equals("table", type(db.runs))
	end)

	it("does not touch a database from a newer addon version", function()
		local raw = { schema = 99, players = { x = { name = "X" } } }
		local db, info = ns.DB.Open(raw, NOW)
		assert.is_true(info.readOnly)
		assert.is_true(db ~= raw)
		assert.equals(99, raw.schema)
		assert.is_not_nil(raw.players.x)
	end)
end)

describe("migration 0 to 1", function()
	local ns, db, info

	before_each(function()
		ns = helper.load()
		db, info = ns.DB.Open(legacy(), NOW)
	end)

	it("reports the migration and sets the schema", function()
		assert.equals(0, info.migratedFrom)
		assert.equals(1, db.schema)
		assert.is_false(info.readOnly)
	end)

	it("keeps a backup copy of the original data", function()
		assert.equals(0, db.backup.schema)
		assert.equals("GOOD", db.backup.data.players["Stormrage-Bob-Alliance"].lastRank)
		assert.is_nil(db.backup.data.backup)
	end)

	it("re-keys players by name and moves faction to a field", function()
		local bob = db.players["n:bob-stormrage"]
		assert.equals("Bob", bob.name)
		assert.equals("Stormrage", bob.suffix)
		assert.equals("MAGE", bob.classFile)
		assert.equals("Alliance", bob.faction)
		assert.is_nil(db.players["n:eve-stormrage"].classFile)
		assert.is_nil(db.players["Stormrage-Bob-Alliance"])
		assert.is_nil(db.players.broken)
	end)

	it("turns the last rank into one imported rating", function()
		local bob = db.players["n:bob-stormrage"]
		assert.equals(1, #bob.ratings)
		assert.equals(5, bob.ratings[1].score)
		assert.is_true(bob.ratings[1].imported)
		assert.equals(1, db.players["n:eve-stormrage"].ratings[1].score)
		assert.equals(0, #db.players["n:zed-stormrage"].ratings)
	end)

	it("converts squad history into runs with known members only", function()
		local run = select(2, next(db.runs))
		assert.equals("Deadmines", run.instanceName)
		assert.equals("done", run.prompt)
		assert.equals(2, #run.members)
	end)

	it("maps the toast setting and drops the rest", function()
		assert.equals(false, db.settings.toastEnabled)
		assert.is_nil(db.settings.minimapIconAngle)
		assert.is_nil(db.squadHistory)
	end)

	it("hands out ids that do not collide with migrated ones", function()
		local id = ns.DB.NextId(db, "r")
		for _, rec in pairs(db.players) do
			for _, rating in ipairs(rec.ratings) do
				assert.is_true(rating.id ~= id)
			end
		end
	end)

	it("restores the original and goes read-only when a step fails", function()
		ns = helper.load()
		ns.Migrations.steps[0] = function(d)
			d.players = nil
			error("boom")
		end
		local raw = legacy()
		local opened, openInfo = ns.DB.Open(raw, NOW)
		assert.is_true(openInfo.readOnly)
		assert.is_true(opened ~= raw)
		assert.equals("GOOD", raw.players["Stormrage-Bob-Alliance"].lastRank)
		assert.is_nil(raw.schema)
	end)
end)

describe("DB.Prune", function()
	local ns, db

	before_each(function()
		ns = helper.load()
		db = ns.DB.Open(nil, NOW)
	end)

	it("keeps only the newest runs", function()
		for i = 1, ns.DB.LIMITS.runs + 5 do
			db.runs["run" .. i] = { id = "run" .. i, startedAt = NOW + i, members = {} }
		end
		local removed = ns.DB.Prune(db, NOW)
		assert.equals(5, removed.runs)
		assert.is_nil(db.runs.run1)
		assert.is_not_nil(db.runs.run6)
	end)

	it("caps ratings per player, dropping the oldest", function()
		local ratings = {}
		for i = 1, ns.DB.LIMITS.ratingsPerPlayer + 3 do
			ratings[i] = { id = "r" .. i, createdAt = NOW + i, score = 3 }
		end
		db.players["n:a"] = { name = "A", lastSeen = NOW, ratings = ratings, rulesets = {} }
		local removed = ns.DB.Prune(db, NOW + 1000)
		assert.equals(3, removed.ratings)
		assert.equals("r4", db.players["n:a"].ratings[1].id)
	end)

	it("removes unrated players not seen for a long time, and only those", function()
		local old = NOW - (ns.DB.LIMITS.staleDays + 1) * DAY
		db.players["n:stale"] = { name = "Stale", lastSeen = old, ratings = {}, rulesets = {} }
		db.players["n:recent"] = { name = "Recent", lastSeen = NOW - DAY, ratings = {}, rulesets = {} }
		db.players["n:rated"] =
			{ name = "Rated", lastSeen = old, ratings = { { id = "r1", score = 4 } }, rulesets = {} }
		ns.DB.Prune(db, NOW)
		assert.is_nil(db.players["n:stale"])
		assert.is_not_nil(db.players["n:recent"])
		assert.is_not_nil(db.players["n:rated"])
	end)

	it("purges all data but keeps settings", function()
		db.settings.toastDuration = 15
		db.players["n:a"] = { name = "A", ratings = {} }
		db.currentRun = { members = {} }
		ns.DB.PurgeAll(db)
		assert.is_nil(next(db.players))
		assert.is_nil(db.currentRun)
		assert.equals(15, db.settings.toastDuration)
	end)
end)
