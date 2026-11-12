-- The Players and Runs pages of the SquadRank window. Players: stat tiles, search, filters and
-- a list; clicking a player slides their history in from the right (UI/PlayerDetail.lua).
-- Runs: every recorded group, click one to rate it.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Util = ns.Util
local Compat = ns.Compat
local Events = ns.Events

local MainWindow = {}
ns.MainWindow = MainWindow

local C = UI.C
local ROW_H = 30
local PLAYER_COLS = { 196, 104, 64, 130, 90 }
local RUN_COLS = { 230, 96, 70, 120, 80 }

local view = { search = "", label = nil, role = nil, tag = nil }
local pages = {}

local function hasTag(summary, tagId)
	for _, tag in ipairs(summary.topTags) do
		if tag.id == tagId then
			return true
		end
	end
	return false
end

local function classColor(classFile)
	local color = classFile and C_ClassColor and C_ClassColor.GetClassColor(classFile)
	if type(color) == "table" and type(color.r) == "number" then
		return { color.r, color.g, color.b }
	end
	return C.muted
end

local LABEL_COLORS = { trusted = C.good, mixed = C.gold, caution = C.bad, new = C.muted }

local function playerItems()
	local db = ns.db
	local now, minRatings = Compat.Now(), db.settings.minRatings
	local items, stats = {}, { players = 0, ratings = 0, trusted = 0 }
	for pid, rec in pairs(db.players) do
		local summary = ns.Ratings.Summary(rec, now, minRatings)
		stats.players = stats.players + 1
		stats.ratings = stats.ratings + #rec.ratings
		if summary.label == "trusted" then
			stats.trusted = stats.trusted + 1
		end
		local name = ns.Players.DisplayName(rec)
		local pass = (view.search == "" or name:lower():find(view.search, 1, true))
			and (not view.label or summary.label == view.label)
			and (not view.role or summary.roles[view.role])
			and (not view.tag or hasTag(summary, view.tag))
		if pass then
			items[#items + 1] = {
				kind = "player",
				pid = pid,
				rec = rec,
				summary = summary,
				name = name,
				rated = summary.lastRatedAt or 0,
				seen = rec.lastSeen or 0,
			}
		end
	end
	table.sort(items, function(a, b)
		if a.rated ~= b.rated then
			return a.rated > b.rated
		end
		if a.seen ~= b.seen then
			return a.seen > b.seen
		end
		return a.name < b.name
	end)
	return items, stats
end

local function runItems(search)
	local db = ns.db
	local items = {}
	for _, run in ipairs(ns.Runs.List(db)) do
		local name = UI.RunName(run)
		if search == "" or name:lower():find(search, 1, true) then
			items[#items + 1] = { kind = "run", run = run, name = name, rated = ns.Runs.RatedCount(db, run) }
		end
	end
	return items
end

-- Rows ------------------------------------------------------------------------------------------

local function columns(parent, widths, font, x0)
	local cols, x = {}, x0 or 14
	for i, width in ipairs(widths) do
		local text = UI.Text(parent, font)
		text:SetPoint("LEFT", x, 0)
		text:SetWidth(width - 8)
		text:SetWordWrap(false)
		cols[i] = text
		cols[i].x = x
		x = x + width
	end
	return cols
end

local function miniBar(row, x, width)
	local track = row:CreateTexture(nil, "ARTWORK")
	track:SetPoint("LEFT", x, 0)
	track:SetSize(width, 4)
	track:SetColorTexture(1, 1, 1, 0.08)
	local fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
	fill:SetPoint("LEFT", track, "LEFT")
	fill:SetHeight(4)
	fill:SetWidth(1)
	return track, fill
end

local function playerMenu(row, item)
	UI.ContextMenu(row, function(root)
		root:CreateTitle(item.name)
		root:CreateButton(
			L.MENU_RATE,
			ns.Safe("menu rate", function()
				ns.RateFrame.OpenPlayers({ item.pid })
			end)
		)
		root:CreateButton(
			L.MENU_HISTORY,
			ns.Safe("menu history", function()
				ns.PlayerDetail.Open(item.pid)
			end)
		)
		root:CreateButton(
			L.MENU_PURGE,
			ns.Safe("menu purge", function()
				ns.Slash.ConfirmPurgePlayer(item.pid)
			end)
		)
	end)
end

local function onRowClick(row, button)
	local item = row.srItem
	if not item then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if item.kind == "run" then
		if ns.db.runs[item.run.id] then
			ns.RateFrame.OpenRun(item.run)
		end
	elseif button == "RightButton" then
		playerMenu(row, item)
	else
		ns.PlayerDetail.Open(item.pid)
	end
end

local function baseRow(row)
	row.zebra = row:CreateTexture(nil, "BACKGROUND")
	row.zebra:SetAllPoints()
	row.zebra:SetColorTexture(1, 1, 1, 0.025)
	row.stripe = row:CreateTexture(nil, "ARTWORK")
	row.stripe:SetPoint("TOPLEFT", 0, -4)
	row.stripe:SetPoint("BOTTOMLEFT", 0, 4)
	row.stripe:SetWidth(3)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", ns.Safe("main row", onRowClick))
end

local function buildPlayerRow(row)
	baseRow(row)
	row.cols = columns(row, PLAYER_COLS, "GameFontHighlight")
	row.pill = UI.Pill(row)
	row.pill:SetPoint("LEFT", row.cols[2].x, 0)
	row.cols[2]:Hide()
	row.track, row.fill = miniBar(row, row.cols[4].x, 70)
	row.cols[4]:ClearAllPoints()
	row.cols[4]:SetPoint("LEFT", row.cols[4].x + 78, 0)
	row.cols[4]:SetWidth(48)
	row.cols[3]:SetFontObject("GameFontHighlightSmall")
	row.cols[5]:SetFontObject("GameFontDisableSmall")
end

local function fillPlayerRow(row, item)
	row.srItem = item
	local cols, summary = row.cols, item.summary
	cols[1]:SetText(Compat.ClassColored(item.name, item.rec.classFile))
	UI.SetColor(row.stripe, classColor(item.rec.classFile), 0.9)
	row.pill:Set(L["LABEL_" .. summary.label], LABEL_COLORS[summary.label] or C.muted, 0.2)
	cols[3]:SetText(tostring(summary.count))
	local avg = summary.weighted
	if summary.count > 0 and avg then
		local color = UI.ScoreColor(avg)
		row.fill:SetWidth(math.max(1, 70 * avg / 5))
		UI.SetColor(row.fill, color)
		row.fill:Show()
		cols[4]:SetText(UI.Colorize(("%.1f"):format(avg), color))
	else
		row.fill:Hide()
		cols[4]:SetText("|cff808080-|r")
	end
	cols[5]:SetText(UI.Date(item.rec.lastSeen))
	row.zebra:SetShown(item.index and item.index % 2 == 0 or false)
end

local STATUS = {
	pending = { "RUN_STATUS_PENDING", C.gold },
	done = { "RUN_STATUS_DONE", C.good },
	skipped = { "RUN_STATUS_SKIPPED", C.muted },
}

local function buildRunRow(row)
	baseRow(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(18, 18)
	row.icon:SetPoint("LEFT", 12, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.cols = columns(row, RUN_COLS, "GameFontHighlight", 38)
	row.cols[2]:SetFontObject("GameFontDisableSmall")
	row.cols[3]:SetFontObject("GameFontHighlightSmall")
	row.track, row.fill = miniBar(row, row.cols[4].x, 60)
	row.cols[4]:ClearAllPoints()
	row.cols[4]:SetPoint("LEFT", row.cols[4].x + 66, 0)
	row.cols[4]:SetWidth(50)
	row.cols[4]:SetFontObject("GameFontHighlightSmall")
	row.pill = UI.Pill(row)
	row.pill:SetPoint("LEFT", row.cols[5].x, 0)
	row.cols[5]:Hide()
end

local function fillRunRow(row, item)
	row.srItem = item
	local run, cols = item.run, row.cols
	row.icon:SetTexture(
		run.kind == "group" and "Interface\\Icons\\INV_Misc_GroupLooking" or "Interface\\Icons\\INV_Misc_Map_01"
	)
	cols[1]:SetText(item.name)
	cols[2]:SetText(UI.Date(run.endedAt or run.startedAt))
	cols[3]:SetText(L.RUN_PLAYERS_FMT:format(run.groupSize or (#run.members + 1)))
	local total = #run.members
	local share = total > 0 and item.rated / total or 0
	row.fill:SetWidth(math.max(1, 60 * share))
	UI.SetColor(row.fill, share >= 1 and C.good or C.accent)
	cols[4]:SetText(L.RUN_RATED_SHORT:format(item.rated, total))
	local status = STATUS[run.prompt] or STATUS.skipped
	row.pill:Set(L[status[1]], status[2], 0.2)
	UI.SetColor(row.stripe, status[2], run.prompt == "pending" and 0.9 or 0)
	row.zebra:SetShown(item.index and item.index % 2 == 0 or false)
end

-- Pages -----------------------------------------------------------------------------------------

local function header(page, widths, keys, y, x0)
	local bar = CreateFrame("Frame", nil, page)
	bar:SetPoint("TOPLEFT", 0, y)
	bar:SetPoint("TOPRIGHT", 0, y)
	bar:SetHeight(18)
	local cols = columns(bar, widths, "GameFontDisableSmall", x0)
	for i, key in ipairs(keys) do
		cols[i]:SetText(L[key]:upper())
	end
	return bar
end

local function listArea(page, top, buildRow, fillRow)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetPoint("TOPLEFT", 0, top)
	holder:SetPoint("BOTTOMRIGHT", 0, 24)
	local list = UI.CreateList(holder, ROW_H, buildRow, fillRow)
	local empty = UI.Text(holder, "GameFontDisable", "CENTER")
	empty:SetPoint("CENTER", 0, 20)
	empty:SetWidth(360)
	return list, empty, holder
end

local function footer(page, hintText)
	local count = UI.Text(page, "GameFontDisableSmall")
	count:SetPoint("BOTTOMLEFT", 2, 4)
	local hint = UI.Text(page, "GameFontDisableSmall", "RIGHT")
	hint:SetPoint("BOTTOMRIGHT", -2, 4)
	hint:SetText(hintText)
	return count
end

local function statTile(page, index, label)
	local tile = CreateFrame("Frame", nil, page)
	tile:SetSize(196, 52)
	tile:SetPoint("TOPLEFT", (index - 1) * 204, 0)
	UI.Fill(tile, C.card)
	local accent = tile:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetWidth(2)
	tile.value = UI.Text(tile, "GameFontHighlightHuge")
	tile.value:SetPoint("TOPLEFT", 14, -8)
	tile.label = UI.Text(tile, "GameFontDisableSmall")
	tile.label:SetPoint("BOTTOMLEFT", 14, 8)
	tile.label:SetText(label)
	tile.accent = accent
	return tile
end

local function filterMenu(owner, key, options)
	UI.ContextMenu(owner, function(root)
		local function choose(value)
			return ns.Safe("filter", function()
				view[key] = value
				MainWindow.Refresh()
			end)
		end
		root:CreateRadio(L.FILTER_ALL, function()
			return view[key] == nil
		end, choose(nil))
		for _, option in ipairs(options) do
			root:CreateRadio(option.text, function()
				return view[key] == option.value
			end, choose(option.value))
		end
	end)
end

local function buildPlayers(page)
	local w = { page = page }
	pages.players = w

	w.tiles = {
		statTile(page, 1, L.STAT_PLAYERS),
		statTile(page, 2, L.STAT_RATINGS),
		statTile(page, 3, L.STAT_TRUSTED),
	}
	UI.SetColor(w.tiles[1].accent, C.accent)
	UI.SetColor(w.tiles[2].accent, C.gold)
	UI.SetColor(w.tiles[3].accent, C.good)

	local holder, search = UI.TextBox(page, 186, 26, L.SEARCH_HINT, 48)
	holder:SetPoint("TOPLEFT", 0, -64)
	search:HookScript(
		"OnTextChanged",
		ns.Safe("search", function(self)
			view.search = Util.Sanitize(self:GetText(), 48):lower()
			MainWindow.Refresh()
		end)
	)
	w.search = search

	local labelOptions, roleOptions, tagOptions = {}, {}, {}
	for _, label in ipairs({ "trusted", "mixed", "caution", "new" }) do
		labelOptions[#labelOptions + 1] = { value = label, text = L["LABEL_" .. label] }
	end
	for _, role in ipairs(ns.Ratings.ROLES) do
		roleOptions[#roleOptions + 1] = { value = role, text = L["ROLE_" .. role] }
	end
	for _, tag in ipairs(ns.Ratings.TAGS) do
		tagOptions[#tagOptions + 1] = { value = tag.id, text = L["TAG_" .. tag.id] }
	end
	w.filterTag = UI.FlatButton(page, "", 150, 26, function(self)
		filterMenu(self, "tag", tagOptions)
	end)
	w.filterTag:SetPoint("TOPRIGHT", 0, -64)
	w.filterRole = UI.FlatButton(page, "", 100, 26, function(self)
		filterMenu(self, "role", roleOptions)
	end)
	w.filterRole:SetPoint("RIGHT", w.filterTag, "LEFT", -6, 0)
	w.filterLabel = UI.FlatButton(page, "", 116, 26, function(self)
		filterMenu(self, "label", labelOptions)
	end)
	w.filterLabel:SetPoint("RIGHT", w.filterRole, "LEFT", -6, 0)

	header(page, PLAYER_COLS, { "COL_PLAYER", "COL_LABEL", "COL_RATINGS", "COL_SCORE", "COL_SEEN" }, -100)
	w.list, w.empty = listArea(page, -120, buildPlayerRow, fillPlayerRow)
	w.count = footer(page, L.MAIN_HINT)
end

local function buildRuns(page)
	local w = { page = page }
	pages.runs = w
	local holder, search = UI.TextBox(page, 186, 26, L.SEARCH_RUNS_HINT, 48)
	holder:SetPoint("TOPLEFT", 0, 0)
	search:HookScript(
		"OnTextChanged",
		ns.Safe("run search", function(self)
			w.searchText = Util.Sanitize(self:GetText(), 48):lower()
			MainWindow.Refresh()
		end)
	)
	w.searchText = ""
	header(page, RUN_COLS, { "COL_INSTANCE", "COL_DATE", "COL_PLAYERS", "COL_RATED", "COL_STATUS" }, -36, 38)
	w.list, w.empty = listArea(page, -56, buildRunRow, fillRunRow)
	w.count = footer(page, L.RUNS_HINT)
end

local function index(items)
	for i, item in ipairs(items) do
		item.index = i
	end
	return items
end

local function refreshPlayers()
	local w = pages.players
	local items, stats = playerItems()
	w.list:SetData(index(items))
	w.tiles[1].value:SetText(tostring(stats.players))
	w.tiles[2].value:SetText(tostring(stats.ratings))
	w.tiles[3].value:SetText(tostring(stats.trusted))
	w.filterLabel:SetText(L.FILTER_FMT:format(L.FILTER_LABEL, view.label and L["LABEL_" .. view.label] or L.FILTER_ALL))
	w.filterRole:SetText(L.FILTER_FMT:format(L.FILTER_ROLE, view.role and L["ROLE_" .. view.role] or L.FILTER_ALL))
	w.filterTag:SetText(L.FILTER_FMT:format(L.FILTER_TAG, view.tag and L["TAG_" .. view.tag] or L.FILTER_ALL))
	w.count:SetText(L.COUNT_FMT:format(#items))
	w.empty:SetShown(#items == 0)
	w.empty:SetText(L.EMPTY_PLAYERS)
end

local function refreshRuns()
	local w = pages.runs
	local items = runItems(w.searchText)
	w.list:SetData(index(items))
	w.count:SetText(L.COUNT_FMT:format(#items))
	w.empty:SetShown(#items == 0)
	w.empty:SetText(L.EMPTY_RUNS)
end

local function doRefresh()
	local Hub = ns.Hub
	if Hub.IsShown("players") and pages.players then
		refreshPlayers()
	elseif Hub.IsShown("runs") and pages.runs then
		refreshRuns()
	end
	Hub.UpdateBadges()
end

-- Reading the database for display also waits for combat to end.
function MainWindow.Refresh()
	if ns.Hub.IsShown() then
		Events.RunOutOfCombat("main refresh", doRefresh)
	end
end

function MainWindow.Show(key)
	ns.Hub.Show(key or "players")
end

function MainWindow.Toggle()
	ns.Hub.Toggle()
end

ns.Hub.AddPage("players", {
	label = L.TAB_PLAYERS,
	build = buildPlayers,
	show = refreshPlayers,
})

ns.Hub.AddPage("runs", {
	label = L.TAB_RUNS,
	title = L.RUNS_TITLE,
	build = buildRuns,
	show = refreshRuns,
})
