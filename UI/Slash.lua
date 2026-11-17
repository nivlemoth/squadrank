-- /sr and /squadrank, plus the Addon Compartment click handler.
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Compat = ns.Compat
local UI = ns.UI

local Slash = {}
ns.Slash = Slash

local function toggleMain()
	if ns.Hub then
		ns.Hub.Toggle()
	end
end

local function blockedByCombat()
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return true
	end
	return false
end

-- Returns the pid for a typed name, or nil after telling the user why not.
local function findOne(text)
	local pids = ns.Players.Find(ns.db, text)
	if #pids == 1 then
		return pids[1]
	end
	if #pids == 0 then
		return nil, "none"
	end
	ns.Print(L.MSG_AMBIGUOUS:format(Util.Sanitize(text, 64)))
	for _, pid in ipairs(pids) do
		print("  " .. ns.Players.DisplayName(ns.db.players[pid]))
	end
	return nil, "many"
end

local commands = {}

function commands.rate(arg)
	if blockedByCombat() or not ns.RateFrame then
		return
	end
	if arg == "" then
		local run = ns.Runs.LatestPending(ns.db)
		if run then
			ns.RateFrame.OpenRun(run)
		else
			ns.Print(L.MSG_NO_PENDING)
		end
		return
	end
	local pid, why = findOne(arg)
	if not pid and why == "none" then
		-- Not seen before: create a record from the typed name so it can be rated.
		local name, suffix = Util.SplitTypedName(arg)
		if not name then
			return
		end
		local ident = { name = name, suffix = suffix }
		if ns.RecentAllies then
			ident = ns.RecentAllies.Lookup(name, suffix) or ident
		end
		pid = ns.Players.Resolve(ns.db, ident, Compat.Now())
	end
	if pid then
		ns.RateFrame.OpenPlayers({ pid })
	end
end

function commands.list(arg)
	if blockedByCombat() then
		return
	end
	local needle = Util.Sanitize(arg, 64):lower()
	local now, minRatings = Compat.Now(), ns.db.settings.minRatings
	local rows = {}
	for _, rec in pairs(ns.db.players) do
		if #rec.ratings > 0 then
			local name = ns.Players.DisplayName(rec)
			if needle == "" or name:lower():find(needle, 1, true) then
				rows[#rows + 1] = { name = name, rec = rec }
			end
		end
	end
	if #rows == 0 then
		ns.Print(L.MSG_LIST_NONE)
		return
	end
	table.sort(rows, function(a, b)
		return a.name < b.name
	end)
	local shown = math.min(#rows, 15)
	for i = 1, shown do
		local summary = ns.Ratings.Summary(rows[i].rec, now, minRatings)
		print(
			ns.Locale.Count(
				"MSG_LIST",
				summary.count,
				UI.ColoredName(rows[i].rec),
				UI.LabelText(summary.label),
				summary.count
			)
		)
	end
	if #rows > shown then
		print(L.MSG_LIST_MORE:format(#rows - shown))
	end
end

local ALLIES_LIMIT = 15

function commands.allies()
	if blockedByCombat() then
		return
	end
	local RecentAllies = ns.RecentAllies
	if not RecentAllies then
		ns.Print(L.MSG_ALLIES_UNAVAILABLE)
		return
	end
	local list = RecentAllies.List()
	if not list then
		ns.Print(L.MSG_ALLIES_UNAVAILABLE)
		return
	end
	local matches = RecentAllies.Matches(ns.db, list)
	if #matches == 0 then
		ns.Print(L.MSG_ALLIES_NONE)
		return
	end
	ns.Print(L.MSG_ALLIES_HEADER)
	local now, minRatings = Compat.Now(), ns.db.settings.minRatings
	local shown = math.min(#matches, ALLIES_LIMIT)
	for i = 1, shown do
		local match = matches[i]
		local summary = ns.Ratings.Summary(match.rec, now, minRatings)
		for _, line in ipairs(RecentAllies.Lines(summary, match.rec)) do
			print("  " .. line)
		end
	end
	if #matches > shown then
		print("  " .. L.FMT_MORE:format(#matches - shown))
	end
end

function commands.purge(arg)
	if blockedByCombat() then
		return
	end
	if arg == "" then
		ns.Print(L.MSG_HELP_4)
	elseif arg:lower() == "all" then
		UI.Confirm(L.CONFIRM_PURGE_ALL, Slash.PurgeAll)
	else
		local pid, why = findOne(arg)
		if pid then
			Slash.ConfirmPurgePlayer(pid)
		elseif why == "none" then
			ns.Print(L.MSG_NOT_FOUND:format(Util.Sanitize(arg, 64)))
		end
	end
end

-- Developer-only: "/sr debug locale deDE" shows SquadRank in another language after /reload;
-- "/sr debug locale off" goes back to the client language. Never changes saved ratings.
local function setDeveloperLocale(code)
	local settings = ns.db.settings
	if code == "off" or code == "" then
		settings.devLocale = nil
		ns.Print(L.MSG_LOCALE_CLEARED)
		return
	end
	if not (ns.Locale.SUPPORTED[code] or code == "enGB") then
		ns.Print(L.MSG_LOCALE_USAGE)
		return
	end
	settings.devLocale = code
	ns.Print(L.MSG_LOCALE_SET:format(code))
end

function commands.debug(arg)
	local word, rest = arg:match("^(%S*)%s*(%S*)")
	if word and word:lower() == "locale" then
		local code = rest or ""
		setDeveloperLocale(code:lower() == "off" and "off" or (code:sub(1, 2):lower() .. code:sub(3, 4):upper()))
		return
	end
	if arg:lower() == "lists" then
		local settings = ns.db.settings
		settings.simpleLists = not settings.simpleLists
		ns.Print(L.MSG_LISTS_SIMPLE:format(settings.simpleLists and L.STATE_ON or L.STATE_OFF))
		return
	end
	ns.DebugPanel.Show()
end

function commands.settings()
	ns.Hub.Show("settings")
end
commands.config = commands.settings
commands.options = commands.settings

function commands.about()
	ns.Hub.Show("about")
end

function commands.whatsnew()
	if blockedByCombat() or not ns.WhatsNew then
		return
	end
	ns.WhatsNew.Show(true)
end

function commands.minimap()
	local settings = ns.db.settings
	settings.minimapButton = not settings.minimapButton
	ns.MinimapButton.Update()
end

function commands.selftest()
	ns.SelfTest.Run()
end

function commands.help()
	ns.Print(L.ADDON .. " " .. ns.VERSION)
	for _, line in ipairs({
		L.MSG_HELP_1,
		L.MSG_HELP_2,
		L.MSG_HELP_3,
		L.MSG_HELP_4,
		L.MSG_HELP_5,
		L.MSG_HELP_6,
		L.MSG_HELP_7,
		L.MSG_HELP_8,
	}) do
		print("  " .. line)
	end
end

function Slash.PurgeAll()
	if ns.readOnly or Compat.InCombat() then
		ns.Print(ns.readOnly and L.MSG_READONLY:format(tostring(ns.readOnlyReason)) or L.MSG_COMBAT)
		return
	end
	ns.DB.PurgeAll(ns.db)
	ns.Players.BuildIndex(ns.db)
	ns.Debug.Log("PURGE", "all data purged")
	ns.Print(L.MSG_PURGED_ALL)
	Slash.RefreshWindows()
end

function Slash.ConfirmPurgePlayer(pid)
	local rec = ns.db.players[pid]
	if not rec then
		return
	end
	local name = ns.Players.DisplayName(rec)
	UI.Confirm(L.CONFIRM_PURGE_PLAYER:format(name), function()
		if ns.readOnly or Compat.InCombat() then
			ns.Print(ns.readOnly and L.MSG_READONLY:format(tostring(ns.readOnlyReason)) or L.MSG_COMBAT)
			return
		end
		if ns.Players.Purge(ns.db, pid) then
			ns.Debug.Log("PURGE", "player purged, hash %d", Util.Hash(pid))
			ns.Print(L.MSG_PURGED:format(name))
			Slash.RefreshWindows()
		end
	end)
end

function Slash.RefreshWindows()
	if ns.MainWindow then
		ns.MainWindow.Refresh()
	end
	if ns.PlayerDetail then
		ns.PlayerDetail.Refresh()
	end
	if ns.Hub then
		ns.Hub.UpdateBadges()
	end
end

function Slash.Handle(message)
	if not ns.db then
		return
	end
	local text = Util.Trim(type(message) == "string" and message or "")
	local word, rest = text:match("^(%S+)%s*(.*)$")
	if not word then
		toggleMain()
		return
	end
	local command = commands[word:lower()]
	if command then
		command(rest or "")
	else
		commands.help()
	end
end

SLASH_SQUADRANK1 = "/sr"
SLASH_SQUADRANK2 = "/squadrank"
SlashCmdList.SQUADRANK = ns.Safe("slash", Slash.Handle)

-- Called by the client's Addon Compartment (see the TOC). It must be a global function.
SquadRank_OnAddonCompartmentClick = ns.Safe("compartment", toggleMain)

SquadRank.Toggle = ns.Safe("toggle", toggleMain)
