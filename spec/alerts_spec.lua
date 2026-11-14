local helper = dofile("spec/helper.lua")
local NOW = helper.NOW

local function setup(ns, settings)
	local db = ns.DB.Open(nil, NOW)
	for key, value in pairs(settings or {}) do
		db.settings[key] = value
	end
	return db
end

local function player(ns, db, name, score)
	local pid = ns.Players.Resolve(db, { name = name, guid = "Player-1-" .. name }, NOW, "Realm")
	if score then
		ns.Ratings.Save(db, pid, { score = score, role = "dps" }, NOW)
	end
	return pid
end

describe("context alert defaults", function()
	local ns

	before_each(function()
		ns = helper.load()
	end)

	it("are opt-in and share a 60-minute cooldown", function()
		local db = setup(ns)
		for _, context in ipairs({ "whisper", "target", "trade", "duel" }) do
			assert.is_false(ns.Alerts.Enabled(db, context))
		end
		assert.equals(60, db.settings.alertCooldown)
		assert.equals(60, ns.Alerts.Cooldown(db))
	end)

	it("clamps a saved cooldown to 0-180 minutes", function()
		local high = ns.DB.Open({ schema = 1, settings = { alertCooldown = 999 } }, NOW)
		local low = ns.DB.Open({ schema = 1, settings = { alertCooldown = -5 } }, NOW)
		assert.equals(180, high.settings.alertCooldown)
		assert.equals(0, low.settings.alertCooldown)
	end)
end)

describe("Alerts.ResolveName", function()
	local ns, db, bob

	before_each(function()
		ns = helper.load()
		db = setup(ns)
		bob = player(ns, db, "Bob", 4)
	end)

	it("finds a saved player by name, case-insensitively", function()
		assert.equals(bob, ns.Alerts.ResolveName(db, "bob"))
		assert.equals(bob, ns.Alerts.ResolveName(db, " Bob "))
	end)

	it("refuses unknown, blank and ambiguous names", function()
		assert.is_nil(ns.Alerts.ResolveName(db, "Nobody"))
		assert.is_nil(ns.Alerts.ResolveName(db, "   "))
		assert.is_nil(ns.Alerts.ResolveName(db, nil))
		ns.Players.Resolve(db, { name = "Bob", guid = "Player-1-OTHER" }, NOW, "Realm")
		assert.is_nil(ns.Alerts.ResolveName(db, "Bob"))
	end)
end)

describe("Alerts.ShouldAlert", function()
	local ns, db, bob

	before_each(function()
		ns = helper.load()
		ns.Alerts.Reset()
		db = setup(ns, { alertWhisper = true, alertTarget = true, alertCooldown = 60 })
		bob = player(ns, db, "Bob", 4)
	end)

	it("requires the context switch for a rated player", function()
		ns.Alerts.Reset()
		db.settings.alertTarget = false
		assert.is_false(ns.Alerts.ShouldAlert(db, bob, "target", NOW))
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW))
	end)

	it("never alerts about an unrated player who is not avoided", function()
		local eve = player(ns, db, "Eve")
		assert.is_false(ns.Alerts.ShouldAlert(db, eve, "whisper", NOW))
	end)

	it("records a cooldown shared by every context", function()
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW))
		assert.is_false(ns.Alerts.ShouldAlert(db, bob, "target", NOW + 3599))
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "target", NOW + 3600))
	end)

	it("treats a zero cooldown as no cooldown", function()
		db.settings.alertCooldown = 0
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW))
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW))
	end)

	it("lets an avoided player through even when the context is off", function()
		local eve = player(ns, db, "Eve")
		db.players[eve].avoid = true
		db.settings.alertTarget = false
		assert.is_true(ns.Alerts.ShouldAlert(db, eve, "target", NOW))
	end)

	it("does not warn about an avoided player when the avoid warning is off", function()
		local eve = player(ns, db, "Eve")
		db.players[eve].avoid = true
		db.settings.avoidWarning = false
		assert.is_false(ns.Alerts.ShouldAlert(db, eve, "whisper", NOW))
	end)

	it("ignores unknown players and unknown contexts", function()
		assert.is_false(ns.Alerts.ShouldAlert(db, "g:missing", "whisper", NOW))
		assert.is_false(ns.Alerts.ShouldAlert(db, bob, "mail", NOW))
	end)

	it("forgets every cooldown when reset", function()
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW))
		assert.is_false(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW + 1))
		ns.Alerts.Reset()
		assert.is_true(ns.Alerts.ShouldAlert(db, bob, "whisper", NOW + 1))
	end)
end)
