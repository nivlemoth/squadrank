-- Loads the whole addon against the fake client in spec/wowmock.lua and plays a session.
-- Every step also asserts that none of our handlers raised an error.
local mock = dofile("spec/wowmock.lua")

local BOB = { name = "Bob", guid = "Player-1-000000B0", class = "MAGE", role = "HEALER" }
local EVE = { name = "Eve", suffix = "Vale", guid = "Player-1-000000E0", class = "ROGUE" }
local ME = { name = "Me", guid = "Player-1-00000001" }

describe("whole addon against a fake client", function()
	local world, ns

	local function noErrors()
		assert.equals("", table.concat(ns.Debug.errors, " | "))
	end

	local function boot()
		ns = mock.loadAddon()
		mock.fire(ns, "ADDON_LOADED", "SquadRank")
		mock.fire(ns, "PLAYER_LOGIN")
		mock.fire(ns, "PLAYER_ENTERING_WORLD", true, false)
		mock.flush()
	end

	local function roster()
		mock.fire(ns, "GROUP_ROSTER_UPDATE")
		mock.flush()
	end

	local function printed(text)
		for _, line in ipairs(world.printed) do
			if line:find(text, 1, true) then
				return true
			end
		end
		return false
	end

	before_each(function()
		SquadRankDB, SquadRankDebug = nil, nil
		world = mock.install()
		world.units.player = ME
		boot()
	end)

	it("loads, creates the database and registers its pieces", function()
		noErrors()
		assert.equals(1, SquadRankDB.schema)
		assert.equals(ns.db, SquadRankDB)
		assert.equals("function", type(SlashCmdList.SQUADRANK))
		assert.equals("function", type(SquadRank_OnAddonCompartmentClick))
		assert.equals("ok, 7 of 7 controls", ns.Debug.notes.settings)
		assert.equals("ok, 5 of 5 menus", ns.Debug.notes.unitMenu)
	end)

	it("runs the self-test and builds the debug report without errors", function()
		SlashCmdList.SQUADRANK("selftest")
		SlashCmdList.SQUADRANK("debug")
		noErrors()
		-- The fake client leaves ScrollBox out on purpose; those three checks must fail, nothing else.
		for _, result in ipairs(ns.Debug.selftest.results) do
			if result.status == "FAIL" then
				assert.is_not_nil(
					result.name:find("Scroll", 1, true) or result.name:find("CreateDataProvider", 1, true)
				)
			end
		end
		assert.equals(3, ns.Debug.selftest.fail)
		assert.is_true(ns.Debug.selftest.pass > 10)
		assert.equals("SquadRank debug report", SquadRankDebug.report[1])
	end)

	it("opens the main window, switches tabs, filters and prints help", function()
		SlashCmdList.SQUADRANK("")
		assert.equals("simple", ns.Debug.notes.listMode)
		assert.is_true(mock.click("Runs"))
		assert.is_true(mock.click("Players"))
		assert.is_true(mock.click("Label: All"))
		world.lastMenu.entries.Trusted()
		assert.is_true(mock.click("Label: Trusted"))
		SquadRank_OnAddonCompartmentClick("SquadRank", "LeftButton")
		SlashCmdList.SQUADRANK("nonsense")
		SlashCmdList.SQUADRANK("list")
		noErrors()
		assert.is_true(printed("/sr rate"))
	end)

	it("records group members but shows no toast for unrated players", function()
		world.units.party1 = BOB
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()
		noErrors()
		assert.is_not_nil(ns.db.players["g:" .. BOB.guid])
		assert.is_nil(ns.Toast.current)
	end)

	it("rates by name, then toasts once when that player joins, and never in combat", function()
		SlashCmdList.SQUADRANK("rate bob")
		assert.is_true(mock.click("4"))
		assert.is_true(mock.click("Great at role"))
		assert.is_true(mock.click("Save"))
		noErrors()
		local rec = ns.db.players["n:bob"]
		assert.equals(1, #rec.ratings)
		assert.equals(4, rec.ratings[1].score)
		assert.same({ "role_good" }, rec.ratings[1].tags)

		-- Bob joins: the name record is re-keyed to his GUID and a toast appears.
		world.units.party1 = BOB
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()
		noErrors()
		assert.is_nil(ns.db.players["n:bob"])
		assert.equals(1, #ns.db.players["g:" .. BOB.guid].ratings)
		assert.is_not_nil(ns.Toast.current)
		assert.is_not_nil(ns.Toast.current.lines[1]:find("Bob", 1, true))

		-- Combat hides it and brings it back afterwards.
		world.combat = true
		mock.fire(ns, "PLAYER_REGEN_DISABLED")
		assert.is_nil(ns.Toast.current)
		world.combat = false
		mock.fire(ns, "PLAYER_REGEN_ENABLED")
		assert.is_not_nil(ns.Toast.current)
		ns.Toast.Dismiss()

		-- More roster events in the same session do not repeat it.
		roster()
		roster()
		assert.is_nil(ns.Toast.current)
		noErrors()

		-- A toast that is left alone goes away when its timer runs out.
		ns.Toast.ShowJoin({ "g:" .. BOB.guid })
		assert.is_not_nil(ns.Toast.current)
		mock.flushLong()
		assert.is_nil(ns.Toast.current)
		noErrors()
	end)

	it("does not scan the roster during combat, and catches up afterwards", function()
		world.combat = true
		world.units.party1 = BOB
		roster()
		assert.is_nil(ns.db.players["g:" .. BOB.guid])
		world.combat = false
		mock.fire(ns, "PLAYER_REGEN_ENABLED")
		assert.is_not_nil(ns.db.players["g:" .. BOB.guid])
		noErrors()
	end)

	it("never stores a secret name or GUID", function()
		world.units.party1 = { name = world.secret, guid = "Player-1-000000C0" }
		world.units.party2 = { name = "Dan", guid = world.secret }
		roster()
		noErrors()
		assert.equals(1, ns.Util.Count(ns.db.players))
		local rec = ns.db.players["n:dan"]
		assert.equals("Dan", rec.name)
		assert.is_nil(rec.guid)
	end)

	it("tracks a dungeon run across a reload, prompts afterwards and ties ratings to the run", function()
		world.units.party1 = BOB
		world.units.party2 = EVE
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()

		world.instance = { name = "Deadmines", type = "party", id = 36 }
		mock.fire(ns, "PLAYER_ENTERING_WORLD", false, false)
		mock.flush()
		assert.equals(36, SquadRankDB.currentRun.instanceID)
		assert.equals(2, #SquadRankDB.currentRun.members)
		assert.equals("healer", SquadRankDB.currentRun.members[1].role)
		mock.fire(ns, "ENCOUNTER_END", 1, "Boss", 1, 5, 1)
		mock.flush()
		local runId = SquadRankDB.currentRun.id

		-- /reload inside the dungeon: same saved table, everything else rebuilt.
		world.now = world.now + 600
		boot()
		noErrors()
		assert.equals(runId, SquadRankDB.currentRun.id)
		assert.equals(2, #SquadRankDB.currentRun.members)
		assert.equals(1, SquadRankDB.currentRun.bossKills)

		-- Dying puts you outside: the run stays open.
		world.instance = nil
		world.now = world.now + 60
		mock.fire(ns, "ZONE_CHANGED_NEW_AREA")
		mock.flush(1)
		assert.is_not_nil(SquadRankDB.currentRun)

		-- The group breaks up: the run ends and the prompt appears.
		world.units.party1, world.units.party2 = nil, nil
		mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
		mock.flush()
		noErrors()
		assert.is_nil(SquadRankDB.currentRun)
		assert.equals("pending", SquadRankDB.runs[runId].prompt)
		assert.equals(3, SquadRankDB.runs[runId].groupSize)
		assert.equals("Rate your squad", ns.Toast.current.title)

		-- Rate both members from the prompt.
		assert.is_true(mock.click("Rate"))
		assert.is_true(mock.click("5"))
		assert.is_true(mock.click("Save"))
		assert.equals("pending", SquadRankDB.runs[runId].prompt)
		assert.is_true(mock.click("2"))
		assert.is_true(mock.click("Toxic"))
		assert.is_true(mock.click("Save"))
		noErrors()
		assert.equals("done", SquadRankDB.runs[runId].prompt)
		local bob = SquadRankDB.players["g:" .. BOB.guid]
		assert.equals(runId, bob.ratings[1].runId)
		assert.equals("healer", bob.ratings[1].role)
		assert.equals(2, SquadRankDB.players["g:" .. EVE.guid].ratings[1].score)

		-- Reopening the run edits the rating instead of adding one.
		SlashCmdList.SQUADRANK("")
		assert.is_true(mock.click("Runs"))
		ns.RateFrame.OpenRun(SquadRankDB.runs[runId])
		assert.is_true(mock.click("3"))
		assert.is_true(mock.click("Save"))
		noErrors()
		assert.equals(1, #bob.ratings)
		assert.equals(3, bob.ratings[1].score)
	end)

	it("adds a working entry to unit menus for other players only", function()
		world.units.party1 = BOB
		local root = mock.menuRoot()
		world.menus.MENU_UNIT_PARTY(nil, root, { unit = "party1" })
		assert.is_not_nil(root.entries["Rate in SquadRank"])
		root.entries["Rate in SquadRank"]()
		assert.is_true(mock.click("3"))
		assert.is_true(mock.click("Save"))
		noErrors()
		local rec = ns.db.players["g:" .. BOB.guid]
		assert.equals(3, rec.ratings[1].score)
		assert.equals("healer", rec.ratings[1].role)

		local own = mock.menuRoot()
		world.menus.MENU_UNIT_PLAYER(nil, own, { unit = "player" })
		assert.is_nil(next(own.entries))
		local npc = mock.menuRoot()
		world.menus.MENU_UNIT_TARGET(nil, npc, { unit = "target" })
		assert.is_nil(next(npc.entries))
	end)

	it("shows history and purges one player, then everything", function()
		SlashCmdList.SQUADRANK("rate Bob")
		mock.click("1")
		mock.click("Save")
		SlashCmdList.SQUADRANK("rate Eve-Vale")
		mock.click("5")
		mock.click("Save")
		ns.PlayerDetail.Open("n:bob")
		noErrors()

		SlashCmdList.SQUADRANK("purge Bob")
		assert.is_nil(ns.db.players["n:bob"])
		assert.is_not_nil(ns.db.players["n:eve-vale"])
		SlashCmdList.SQUADRANK("purge Nobody")
		assert.is_true(printed("No saved player named"))

		world.settingsButtons[#world.settingsButtons]()
		noErrors()
		assert.is_nil(next(ns.db.players))
		assert.equals(true, ns.db.settings.toastEnabled)
	end)

	it("refuses to save without a score and blocks commands in combat", function()
		SlashCmdList.SQUADRANK("rate Bob")
		mock.click("Save")
		assert.equals(0, #ns.db.players["n:bob"].ratings)
		assert.is_true(printed("Pick a score"))

		world.combat = true
		SlashCmdList.SQUADRANK("rate Someone")
		SlashCmdList.SQUADRANK("list")
		assert.is_nil(ns.db.players["n:someone"])
		assert.is_true(printed("Not available in combat"))
		noErrors()
	end)

	it("leaves a newer database untouched and says so", function()
		SquadRankDB = { schema = 99, players = { keep = { name = "Keep" } } }
		world.printed = {}
		boot()
		noErrors()
		assert.is_true(ns.readOnly)
		assert.equals(99, SquadRankDB.schema)
		assert.is_not_nil(SquadRankDB.players.keep)
		assert.is_true(printed("Read-only mode"))
	end)

	it("writes the debug report at logout without identities", function()
		world.units.party1 = BOB
		roster()
		SlashCmdList.SQUADRANK("rate Bob")
		mock.click("4")
		mock.click("Save")
		mock.fire(ns, "PLAYER_LOGOUT")
		local text = table.concat(SquadRankDebug.report, "\n")
		assert.is_nil(text:find("Bob", 1, true))
		assert.is_nil(text:find(BOB.guid, 1, true))
		assert.is_not_nil(text:find("ratings: 1", 1, true))
	end)
end)
