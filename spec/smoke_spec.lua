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
		assert.equals("ok, 8 of 8 controls", ns.Debug.notes.settings)
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

	it("keeps every page in one window, with a minimap button, settings and the About page", function()
		assert.is_true(ns.MinimapButton.IsShown())
		SlashCmdList.SQUADRANK("minimap")
		assert.is_false(ns.MinimapButton.IsShown())
		assert.is_false(ns.db.settings.minimapButton)
		SlashCmdList.SQUADRANK("minimap")
		assert.is_true(ns.MinimapButton.IsShown())

		SlashCmdList.SQUADRANK("")
		assert.is_true(ns.Hub.IsShown("players"))
		assert.is_true(mock.click("Rate"))
		assert.is_true(ns.Hub.IsShown("rate"))
		assert.is_true(mock.click("Settings"))
		assert.is_true(ns.Hub.IsShown("settings"))
		assert.is_true(mock.click("+"))
		assert.equals(4, ns.db.settings.minRatings)
		assert.is_true(mock.click("About"))
		assert.is_true(ns.Hub.IsShown("about"))
		SlashCmdList.SQUADRANK("settings")
		assert.is_true(ns.Hub.IsShown("settings"))
		noErrors()

		-- A player's history slides in over the Players page, in the same window.
		SlashCmdList.SQUADRANK("rate Bob")
		assert.is_true(mock.click("4"))
		ns.PlayerDetail.Open("n:bob")
		assert.is_true(ns.Hub.IsShown("players"))
		assert.equals("n:bob", ns.PlayerDetail.Current())
		ns.PlayerDetail.Close()
		assert.is_nil(ns.PlayerDetail.Current())

		-- Groups waiting for a rating show on the Rate page and count on the badge.
		world.units.party1 = EVE
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()
		world.now = world.now + 900
		world.units.party1 = nil
		mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
		mock.flush()
		assert.equals(1, ns.Hub.PendingCount())
		assert.is_true(mock.click("Rate"))
		assert.is_not_nil(ns.RateFrame.FindCard("g:" .. EVE.guid))
		assert.is_true(mock.click("Done"))
		mock.flush()
		assert.is_false(ns.Hub.IsShown())
		noErrors()
	end)

	-- Players shown in the (simple, fake-client) player list right now.
	local function listedPlayers()
		local pids = {}
		for _, frame in ipairs(world.frames) do
			local item = rawget(frame, "srItem")
			if item and item.kind == "player" and frame:IsShown() then
				pids[item.pid] = true
			end
		end
		return pids
	end

	it("keeps stored identifiers and scores when the client language changes", function()
		world.locale = "deDE"
		boot()
		local L = ns.L
		assert.equals("deDE", ns.Locale.code)
		SlashCmdList.SQUADRANK("rate Bob")
		assert.is_true(mock.click("4"))
		assert.is_true(mock.click(L.TAG_fair_loot))
		SlashCmdList.SQUADRANK("rate Eve-Vale")
		assert.is_true(mock.click("2"))
		noErrors()
		local bob = SquadRankDB.players["n:bob"].ratings[1]
		assert.equals(4, bob.score)
		assert.same({ "fair_loot" }, bob.tags)
		assert.is_true(ns.Ratings.ROLE_SET[bob.role])

		-- A translated tag filter matches the stored id.
		ns.Hub.Show("players")
		assert.is_true(mock.click(L.FILTER_FMT:format(L.FILTER_TAG, L.FILTER_ALL)))
		world.lastMenu.entries[L.TAG_fair_loot]()
		assert.is_true(mock.click(L.FILTER_FMT:format(L.FILTER_TAG, L.TAG_fair_loot)))
		local shown = listedPlayers()
		assert.is_true(shown["n:bob"])
		assert.is_nil(shown["n:eve-vale"])
		noErrors()

		-- Same saved data under Russian: nothing stored changes, filters still match.
		local before = SquadRankDB.players["n:bob"].ratings[1]
		local snapshot = { score = before.score, role = before.role, tag = before.tags[1], id = before.id }
		world.locale = "ruRU"
		boot()
		L = ns.L
		assert.equals("ruRU", ns.Locale.code)
		local after = SquadRankDB.players["n:bob"].ratings[1]
		assert.same(snapshot, { score = after.score, role = after.role, tag = after.tags[1], id = after.id })
		assert.equals(1, #SquadRankDB.players["n:bob"].ratings)
		ns.Hub.Show("players")
		assert.is_true(mock.click(L.FILTER_FMT:format(L.FILTER_ROLE, L.FILTER_ALL)))
		world.lastMenu.entries[L["ROLE_" .. after.role]]()
		assert.is_true(listedPlayers()["n:bob"])
		noErrors()
	end)

	it("renders every page and message without errors in every supported language", function()
		for _, code in ipairs({
			"enUS",
			"enGB",
			"deDE",
			"frFR",
			"esES",
			"esMX",
			"ptBR",
			"itIT",
			"ruRU",
			"koKR",
			"zhCN",
			"zhTW",
		}) do
			SquadRankDB, SquadRankDebug = nil, nil
			world.locale = code
			world.units.party1 = nil
			boot()
			local L = ns.L

			-- An open-world group ends: the alert, the Rate page, one-click scoring, a tag.
			world.units.party1 = BOB
			mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
			roster()
			world.now = world.now + 900
			world.units.party1 = nil
			mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
			mock.flush()
			assert.is_true(ns.SquadAlert.IsShown(), code)
			ns.SquadAlert.Open()
			local pid = "g:" .. BOB.guid
			mock.press(ns.RateFrame.FindCard(pid).pips[2])
			assert.is_true(mock.click(L.TAG_toxic), code)
			assert.same({ "toxic" }, SquadRankDB.players[pid].ratings[1].tags)

			-- Every page, the drawer, chat output and the debug report.
			ns.Hub.Show("players")
			ns.PlayerDetail.Open(pid)
			ns.Hub.Show("runs")
			ns.Hub.Show("settings")
			ns.Hub.Show("about")
			ns.Hub.Show("rate")
			SlashCmdList.SQUADRANK("list")
			SlashCmdList.SQUADRANK("help")
			SlashCmdList.SQUADRANK("debug")
			mock.flush()
			noErrors()
			assert.is_nil(next(ns.Locale.missing), code .. " looked up a missing key")
			assert.is_nil(next(ns.Locale.rejected), code .. " rejected a translation")
		end
	end)

	it("switches language for development only through the override, and back", function()
		SlashCmdList.SQUADRANK("debug locale frfr")
		assert.equals("frFR", SquadRankDB.settings.devLocale)
		boot()
		assert.equals("frFR", ns.Locale.code)
		assert.equals("enUS", ns.Locale.client)
		SlashCmdList.SQUADRANK("debug locale xx")
		assert.equals("frFR", SquadRankDB.settings.devLocale)
		SlashCmdList.SQUADRANK("debug locale off")
		assert.is_nil(SquadRankDB.settings.devLocale)
		boot()
		assert.equals("enUS", ns.Locale.code)
		noErrors()
	end)

	it("remembers bosses and quests of a run, even from combat, and shows them by type", function()
		world.questTitles = { [501] = "Rats in the Cellar" }
		world.units.party1 = BOB
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()
		-- Quest progress arrives in combat: kept in memory, written after the fight.
		world.combat = true
		mock.fire(ns, "QUEST_WATCH_UPDATE", 501)
		mock.fire(ns, "QUEST_WATCH_UPDATE", 502)
		mock.flush()
		assert.is_nil(SquadRankDB.currentRun.quests)
		world.combat = false
		mock.fire(ns, "PLAYER_REGEN_ENABLED")
		mock.fire(ns, "QUEST_TURNED_IN", 501, 100, 0)
		mock.flush()
		local run = SquadRankDB.currentRun
		assert.equals(2, #run.quests)
		assert.is_true(run.quests[1].done)
		assert.equals("Rats in the Cellar", run.quests[1].title)
		assert.equals("quest", ns.Runs.Category(run))

		-- The group walks into a dungeon: bosses from both events count once.
		world.instance = { name = "The Deadmines", type = "party", id = 36 }
		mock.fire(ns, "PLAYER_ENTERING_WORLD", false, false)
		mock.flush()
		mock.fire(ns, "ENCOUNTER_END", 1, "Rhahk'Zor", 1, 5, 1)
		mock.fire(ns, "BOSS_KILL", 1, "Rhahk'Zor")
		mock.fire(ns, "ENCOUNTER_END", 2, "Sneed", 1, 5, 0)
		mock.flush()
		run = SquadRankDB.currentRun
		assert.equals("dungeon", ns.Runs.Category(run))
		assert.equals(1, run.bossKills)
		assert.equals("Rhahk'Zor", run.bosses[1].name)
		assert.equals(2, #run.quests)

		-- It shows on the Runs page and in the tooltip without errors.
		world.instance = nil
		world.units.party1 = nil
		mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
		mock.flush()
		local stored = ns.Runs.List(SquadRankDB)[1]
		assert.equals("Dungeon  ·  1 boss  ·  2 quests", ns.UI.RunSummary(stored))
		ns.Hub.Show("runs")
		assert.is_true(mock.click("Type: All"))
		world.lastMenu.entries.Dungeon()
		assert.is_true(mock.click("Type: Dungeon"))
		ns.UI.RunTooltip(UIParent, stored)
		ns.Hub.Show("about")
		noErrors()
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

	it("tracks a dungeon run across a reload, alerts afterwards and ties ratings to the run", function()
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

		-- The group breaks up: the run ends and the alert slides in.
		world.units.party1, world.units.party2 = nil, nil
		mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
		mock.flush()
		noErrors()
		assert.is_nil(SquadRankDB.currentRun)
		assert.equals("pending", SquadRankDB.runs[runId].prompt)
		assert.equals(3, SquadRankDB.runs[runId].groupSize)
		assert.is_true(ns.SquadAlert.IsShown())

		-- Click the alert: one card per member. One click on a score saves it.
		ns.SquadAlert.Open()
		mock.tick()
		assert.is_true(ns.RateFrame.IsShown())
		assert.is_false(ns.SquadAlert.IsShown())
		local bobPid, evePid = "g:" .. BOB.guid, "g:" .. EVE.guid
		mock.press(ns.RateFrame.FindCard(bobPid).pips[5])
		assert.equals(1, #SquadRankDB.players[bobPid].ratings)
		assert.equals("pending", SquadRankDB.runs[runId].prompt)
		mock.press(ns.RateFrame.FindCard(evePid).pips[2])
		assert.is_true(mock.click("Toxic"))
		mock.flush()
		noErrors()
		assert.equals("done", SquadRankDB.runs[runId].prompt)
		local bob = SquadRankDB.players[bobPid]
		assert.equals(runId, bob.ratings[1].runId)
		assert.equals("healer", bob.ratings[1].role)
		local eve = SquadRankDB.players[evePid].ratings[1]
		assert.equals(2, eve.score)
		assert.same({ "toxic" }, eve.tags)
		assert.is_false(ns.SquadAlert.IsShown())

		-- Reopening the run edits the rating instead of adding one.
		SlashCmdList.SQUADRANK("")
		assert.is_true(mock.click("Runs"))
		ns.RateFrame.OpenRun(SquadRankDB.runs[runId])
		mock.press(ns.RateFrame.FindCard(bobPid).pips[3])
		noErrors()
		assert.equals(1, #bob.ratings)
		assert.equals(3, bob.ratings[1].score)
	end)

	it("asks about an open-world group after it breaks up, and steps aside in combat", function()
		world.units.party1 = BOB
		mock.fire(ns, "GROUP_JOINED", 0, "Party-1-AAAA")
		roster()
		assert.equals("group", SquadRankDB.currentRun.kind)
		assert.equals("Elwynn Forest", SquadRankDB.currentRun.instanceName)
		assert.equals(1, #SquadRankDB.currentRun.members)
		assert.is_false(ns.SquadAlert.IsShown())

		world.now = world.now + 900
		world.units.party1 = nil
		mock.fire(ns, "GROUP_LEFT", 0, "Party-1-AAAA")
		mock.flush()
		noErrors()
		assert.is_true(ns.SquadAlert.IsShown())

		-- Combat hides the alert; it comes back when the fight is over.
		world.combat = true
		mock.fire(ns, "PLAYER_REGEN_DISABLED")
		assert.is_false(ns.SquadAlert.IsShown())
		world.combat = false
		mock.fire(ns, "PLAYER_REGEN_ENABLED")
		mock.flush()
		assert.is_true(ns.SquadAlert.IsShown())

		-- The rating window steps aside in combat too.
		ns.SquadAlert.Open()
		assert.is_not_nil(ns.RateFrame.FindCard("g:" .. BOB.guid))
		world.combat = true
		mock.fire(ns, "PLAYER_REGEN_DISABLED")
		assert.is_false(ns.RateFrame.IsShown())
		world.combat = false
		mock.fire(ns, "PLAYER_REGEN_ENABLED")
		assert.is_true(ns.RateFrame.IsShown())

		-- Skip all: the run is marked skipped, the window closes and the alert stays away.
		assert.is_true(mock.click("Skip all"))
		mock.flush()
		noErrors()
		assert.equals("skipped", ns.Runs.List(SquadRankDB)[1].prompt)
		assert.is_false(ns.RateFrame.IsShown())
		assert.is_false(ns.SquadAlert.IsShown())
	end)

	it("adds a working entry to unit menus for other players only", function()
		world.units.party1 = BOB
		local root = mock.menuRoot()
		world.menus.MENU_UNIT_PARTY(nil, root, { unit = "party1" })
		assert.is_not_nil(root.entries["Rate in SquadRank"])
		root.entries["Rate in SquadRank"]()
		assert.is_true(mock.click("3"))
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
		assert.is_true(mock.click("1"))
		SlashCmdList.SQUADRANK("rate Eve-Vale")
		assert.is_true(mock.click("5"))
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

	it("saves on the first score click, keeps later edits on that rating, and blocks commands in combat", function()
		SlashCmdList.SQUADRANK("rate Bob")
		local card = ns.RateFrame.FindCard("n:bob")
		mock.press(card.role)
		mock.press(card)
		assert.is_true(mock.click("Great at role"))
		assert.equals(0, #ns.db.players["n:bob"].ratings)

		assert.is_true(mock.click("3"))
		local ratings = ns.db.players["n:bob"].ratings
		assert.equals(1, #ratings)
		assert.equals("tank", ratings[1].role)
		assert.same({ "role_good" }, ratings[1].tags)
		assert.is_true(mock.click("5"))
		assert.equals(1, #ratings)
		assert.equals(5, ratings[1].score)
		noErrors()

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
		assert.is_true(mock.click("4"))
		mock.fire(ns, "PLAYER_LOGOUT")
		local text = table.concat(SquadRankDebug.report, "\n")
		assert.is_nil(text:find("Bob", 1, true))
		assert.is_nil(text:find(BOB.guid, 1, true))
		assert.is_not_nil(text:find("ratings: 1", 1, true))
	end)
end)
