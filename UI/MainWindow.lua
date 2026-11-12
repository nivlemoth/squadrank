-- Main window: searchable, filterable player list and the list of recorded runs.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Util = ns.Util
local Compat = ns.Compat
local Events = ns.Events

local MainWindow = {}
ns.MainWindow = MainWindow

local COLUMNS = { 190, 100, 70, 150, 90 }
local HEADERS = {
	players = { "COL_PLAYER", "COL_LABEL", "COL_RATINGS", "COL_ROLES", "COL_SEEN" },
	runs = { "COL_INSTANCE", "COL_DATE", "COL_PLAYERS", "COL_RATED", "COL_BOSSES" },
}

local frame, list
local w = {}
local view = { tab = "players", search = "", label = nil, role = nil, tag = nil }

local function hasTag(summary, tagId)
	for _, tag in ipairs(summary.topTags) do
		if tag.id == tagId then
			return true
		end
	end
	return false
end

local function playerItems()
	local db = ns.db
	local now, minRatings = Compat.Now(), db.settings.minRatings
	local items = {}
	for pid, rec in pairs(db.players) do
		local summary = ns.Ratings.Summary(rec, now, minRatings)
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
	return items
end

local function runItems()
	local db = ns.db
	local items = {}
	for _, run in ipairs(ns.Runs.List(db)) do
		local name = UI.RunName(run)
		if view.search == "" or name:lower():find(view.search, 1, true) then
			items[#items + 1] = { kind = "run", run = run, name = name, rated = ns.Runs.RatedCount(db, run) }
		end
	end
	return items
end

local function rolesText(summary)
	local parts = {}
	for _, role in ipairs(ns.Ratings.ROLES) do
		local stat = summary.roles[role]
		if stat then
			parts[#parts + 1] = ("%s %.1f"):format(L["ROLE_" .. role], stat.avg)
		end
	end
	return table.concat(parts, ", ")
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

local function layoutColumns(parent, font)
	local cols, x = {}, 6
	for i, width in ipairs(COLUMNS) do
		local text = UI.Text(parent, font)
		text:SetPoint("LEFT", x, 0)
		text:SetWidth(width - 6)
		text:SetWordWrap(false)
		cols[i] = text
		x = x + width
	end
	return cols
end

local function buildRow(row)
	row.cols = layoutColumns(row, "GameFontHighlightSmall")
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", ns.Safe("main row", onRowClick))
end

local function fillRow(row, item)
	row.srItem = item
	local cols = row.cols
	if item.kind == "player" then
		cols[1]:SetText(Compat.ClassColored(item.name, item.rec.classFile))
		cols[2]:SetText(UI.LabelText(item.summary.label))
		cols[3]:SetText(tostring(item.summary.count))
		cols[4]:SetText(rolesText(item.summary))
		cols[5]:SetText(UI.Date(item.rec.lastSeen))
	else
		local run = item.run
		cols[1]:SetText(item.name)
		cols[2]:SetText(UI.Date(run.endedAt or run.startedAt))
		cols[3]:SetText(L.RUN_PLAYERS_FMT:format(run.groupSize or (#run.members + 1)))
		cols[4]:SetText(L.RUN_RATED_FMT:format(item.rated, #run.members))
		cols[5]:SetText(tostring(run.bossKills or 0))
	end
end

local function doRefresh()
	if not frame or not frame:IsShown() then
		return
	end
	local players = view.tab == "players"
	local items = players and playerItems() or runItems()
	list:SetData(items)

	for i, key in ipairs(HEADERS[view.tab]) do
		w.headers[i]:SetText(L[key])
	end
	UI.SetChosen(w.tabPlayers, players)
	UI.SetChosen(w.tabRuns, not players)
	w.filterLabel:SetShown(players)
	w.filterRole:SetShown(players)
	w.filterTag:SetShown(players)
	w.filterLabel:SetText(L.FILTER_FMT:format(L.FILTER_LABEL, view.label and L["LABEL_" .. view.label] or L.FILTER_ALL))
	w.filterRole:SetText(L.FILTER_FMT:format(L.FILTER_ROLE, view.role and L["ROLE_" .. view.role] or L.FILTER_ALL))
	w.filterTag:SetText(L.FILTER_FMT:format(L.FILTER_TAG, view.tag and L["TAG_" .. view.tag] or L.FILTER_ALL))
	w.count:SetText(L.COUNT_FMT:format(#items))
	w.empty:SetShown(#items == 0)
	w.empty:SetText(players and L.EMPTY_PLAYERS or L.EMPTY_RUNS)
end

-- Reading the database for display also waits for combat to end.
function MainWindow.Refresh()
	if frame and frame:IsShown() then
		Events.RunOutOfCombat("main refresh", doRefresh)
	end
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

local function build()
	frame = UI.CreateWindow(660, 480, L.MAIN_TITLE)
	local content = frame.content

	w.tabPlayers = UI.Button(content, L.TAB_PLAYERS, 80, 22, function()
		view.tab = "players"
		MainWindow.Refresh()
	end)
	w.tabPlayers:SetPoint("TOPLEFT", 0, 0)
	w.tabRuns = UI.Button(content, L.TAB_RUNS, 80, 22, function()
		view.tab = "runs"
		MainWindow.Refresh()
	end)
	w.tabRuns:SetPoint("LEFT", w.tabPlayers, "RIGHT", 4, 0)

	local ok, search = pcall(CreateFrame, "EditBox", nil, content, "SearchBoxTemplate")
	if not ok then
		search = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
	end
	search:SetSize(130, 20)
	search:SetPoint("LEFT", w.tabRuns, "RIGHT", 16, 0)
	search:SetAutoFocus(false)
	search:SetMaxLetters(48)
	search:HookScript(
		"OnTextChanged",
		ns.Safe("search", function(self)
			view.search = Util.Sanitize(self:GetText(), 48):lower()
			MainWindow.Refresh()
		end)
	)
	search:SetScript("OnEscapePressed", search.ClearFocus)
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

	w.filterTag = UI.Button(content, "", 150, 22, function(self)
		filterMenu(self, "tag", tagOptions)
	end)
	w.filterTag:SetPoint("TOPRIGHT", 0, 0)
	w.filterRole = UI.Button(content, "", 90, 22, function(self)
		filterMenu(self, "role", roleOptions)
	end)
	w.filterRole:SetPoint("RIGHT", w.filterTag, "LEFT", -4, 0)
	w.filterLabel = UI.Button(content, "", 100, 22, function(self)
		filterMenu(self, "label", labelOptions)
	end)
	w.filterLabel:SetPoint("RIGHT", w.filterRole, "LEFT", -4, 0)

	local header = CreateFrame("Frame", nil, content)
	header:SetPoint("TOPLEFT", 0, -28)
	header:SetPoint("TOPRIGHT", 0, -28)
	header:SetHeight(18)
	w.headers = layoutColumns(header, "GameFontNormalSmall")

	local holder = CreateFrame("Frame", nil, content)
	holder:SetPoint("TOPLEFT", 0, -48)
	holder:SetPoint("BOTTOMRIGHT", 0, 20)
	list = UI.CreateList(holder, 20, buildRow, fillRow)

	w.empty = UI.Text(holder, "GameFontDisable", "CENTER")
	w.empty:SetPoint("CENTER")

	w.count = UI.Text(content, "GameFontHighlightSmall")
	w.count:SetPoint("BOTTOMLEFT", 2, 2)
	local hint = UI.Text(content, "GameFontDisableSmall", "RIGHT")
	hint:SetPoint("BOTTOMRIGHT", -2, 2)
	hint:SetText(L.MAIN_HINT)
end

function MainWindow.Show()
	if not ns.db then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if not frame then
		build()
	end
	frame:Show()
	doRefresh()
end

function MainWindow.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		MainWindow.Show()
	end
end
