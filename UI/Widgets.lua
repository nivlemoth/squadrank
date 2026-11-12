-- Shared UI helpers built on Blizzard templates. Every template use is guarded so a
-- missing template degrades to a plainer frame instead of an error.
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Debug = ns.Debug
local Compat = ns.Compat

local UI = {}
ns.UI = UI

function ns.Print(text)
	print(L.MSG_PREFIX .. text)
end

local LABEL_COLOR = {
	new = "ffb0b0b0",
	trusted = "ff40ff40",
	mixed = "ffffd100",
	caution = "ffff4040",
}

function UI.LabelText(label)
	return "|c" .. (LABEL_COLOR[label] or LABEL_COLOR.new) .. L["LABEL_" .. label] .. "|r"
end

-- Upper case for small headings. string.upper only knows ASCII, so text with any other
-- letters (German umlauts, Cyrillic, Korean, Chinese) is shown as written instead of mangled.
function UI.Caps(text)
	text = tostring(text or "")
	if text:find("[\128-\255]") then
		return text
	end
	return text:upper()
end

local function tooltipOwnedBy(owner)
	return GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(owner) or false
end

-- Shows the full text of a font string in a tooltip when it does not fit its width.
function UI.TruncationTooltip(owner, fontString)
	owner:HookScript("OnEnter", function(self)
		local ok, truncated = pcall(fontString.IsTruncated, fontString)
		if ok and truncated and GameTooltip and not tooltipOwnedBy(self) then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(fontString:GetText() or "", 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	owner:HookScript("OnLeave", function(self)
		if tooltipOwnedBy(self) then
			GameTooltip:Hide()
		end
	end)
end

function UI.Date(t)
	if type(t) ~= "number" then
		return "?"
	end
	return date("%Y-%m-%d", t)
end

function UI.TagNames(tagIds, limit)
	local names = {}
	for i, id in ipairs(tagIds) do
		if limit and i > limit then
			break
		end
		names[#names + 1] = L["TAG_" .. id]
	end
	return table.concat(names, L.LIST_SEP)
end

-- Text lines describing a player's reputation, shared by the toast and the history window.
function UI.SummaryLines(summary)
	local lines = {}
	if summary.count == 1 then
		lines[#lines + 1] = L.FMT_RATED_ONCE:format(summary.weighted or 0)
	elseif summary.count > 1 then
		lines[#lines + 1] = ns.Locale.Count("FMT_RATED_TIMES", summary.count, summary.count, summary.weighted or 0)
	end
	for _, role in ipairs(ns.Ratings.ROLES) do
		local stat = summary.roles[role]
		if stat then
			if stat.count == 1 then
				lines[#lines + 1] = L.FMT_ROLE_ONCE:format(L["ROLE_" .. role], stat.avg)
			else
				lines[#lines + 1] =
					ns.Locale.Count("FMT_ROLE_RUNS", stat.count, L["ROLE_" .. role], stat.avg, stat.count)
			end
		end
	end
	if #summary.topTags > 0 then
		local ids = {}
		for i = 1, math.min(3, #summary.topTags) do
			ids[i] = summary.topTags[i].id
		end
		lines[#lines + 1] = L.FMT_TAGS:format(UI.TagNames(ids))
	end
	if summary.lastNote and summary.lastNote ~= "" then
		lines[#lines + 1] = L.FMT_NOTE:format(Util.Sanitize(summary.lastNote))
	end
	return lines
end

function UI.ColoredName(rec)
	return Compat.ClassColored(ns.Players.DisplayName(rec), rec and rec.classFile)
end

function UI.ClassName(classFile)
	local names = _G.LOCALIZED_CLASS_NAMES_MALE
	local name = type(names) == "table" and names[classFile] or nil
	return type(name) == "string" and name or classFile
end

UI.CATEGORY_COLORS = {
	quest = { 1, 0.80, 0.30 },
	world = { 0.56, 0.59, 0.65 },
	dungeon = { 0.25, 0.72, 1 },
	raid = { 0.64, 0.45, 0.95 },
	worldraid = { 0.95, 0.55, 0.20 },
	pvp = { 0.90, 0.32, 0.28 },
	wpvp = { 0.85, 0.30, 0.55 },
}

-- Open-world group types that have their own "<type> in <zone>" name.
local NAMED_GROUPS = { quest = true, worldraid = true, wpvp = true }

-- Display name of a run: the dungeon, or "Group in <zone>" (questing, world raid, world PvP)
-- for an open-world group.
function UI.RunName(run)
	if run.kind == "group" then
		local zone = Util.Escape(run.instanceName or L.UNKNOWN_ZONE)
		local category = ns.Runs.Category(run)
		local format = NAMED_GROUPS[category] and L["RUN_IN_" .. category] or L.RUN_GROUP_FMT
		return format:format(zone)
	end
	return Util.Escape(run.instanceName or L.UNKNOWN_INSTANCE)
end

function UI.CategoryName(run)
	local category = ns.Runs.Category(run)
	return L["CAT_" .. category], UI.CATEGORY_COLORS[category] or UI.CATEGORY_COLORS.world
end

-- One short line: "Dungeon  ·  3 bosses  ·  2 quests".
function UI.RunSummary(run)
	local parts = { (UI.CategoryName(run)) }
	local bosses = run.bossKills or 0
	if bosses > 0 then
		parts[#parts + 1] = ns.Locale.Count("RUN_BOSSES", bosses, bosses)
	end
	local quests = #(run.quests or {})
	if quests > 0 then
		parts[#parts + 1] = ns.Locale.Count("RUN_QUESTS", quests, quests)
	end
	return table.concat(parts, "  ·  ")
end

local function questName(quest)
	local title
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, value = pcall(C_QuestLog.GetTitleForQuestID, quest.id)
		title = ok and Compat.Clean(value, "string") or nil
	end
	title = title or quest.title
	if not title or title == "" then
		return L.QUEST_FALLBACK:format(tonumber(quest.id) or 0)
	end
	return Util.Escape(Util.Sanitize(title, 80))
end

local TIP_LIMIT = 10

-- Fills GameTooltip with what happened in a run: type, date, length, bosses and quests.
function UI.RunTooltip(owner, run)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(UI.RunName(run), 1, 1, 1)
	local category, color = UI.CategoryName(run)
	GameTooltip:AddLine(category, color[1], color[2], color[3])
	GameTooltip:AddLine(UI.Date(run.endedAt or run.startedAt), 0.7, 0.7, 0.7)
	if run.startedAt and run.endedAt and run.endedAt > run.startedAt then
		local minutes = math.max(1, math.floor((run.endedAt - run.startedAt) / 60 + 0.5))
		GameTooltip:AddLine(L.RUN_TIP_DURATION:format(minutes), 0.7, 0.7, 0.7)
	end

	local function section(title, names)
		if #names == 0 then
			return
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(title, 1, 0.82, 0)
		for i, name in ipairs(names) do
			if i > TIP_LIMIT then
				GameTooltip:AddLine(L.FMT_MORE:format(#names - TIP_LIMIT), 0.7, 0.7, 0.7)
				break
			end
			GameTooltip:AddLine("  " .. name, 1, 1, 1)
		end
	end

	local bosses = {}
	for _, boss in ipairs(run.bosses or {}) do
		bosses[#bosses + 1] = boss.name and Util.Escape(boss.name) or L.UNKNOWN_BOSS
	end
	for _ = #bosses + 1, run.bossKills or 0 do
		bosses[#bosses + 1] = L.UNKNOWN_BOSS
	end
	local done, progressed = {}, {}
	for _, quest in ipairs(run.quests or {}) do
		local list = quest.done and done or progressed
		list[#list + 1] = questName(quest)
	end
	section(L.RUN_TIP_BOSSES, bosses)
	section(L.RUN_TIP_QUESTS_DONE, done)
	section(L.RUN_TIP_QUESTS_PROGRESS, progressed)
	if #bosses + #done + #progressed == 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L.RUN_TIP_NOTHING, 0.7, 0.7, 0.7, true)
	end
	GameTooltip:Show()
end

-- Shows a one-line tooltip while the mouse is over `owner`.
function UI.SetTooltip(owner, textOrFn)
	owner:SetScript("OnEnter", function(self)
		local text = type(textOrFn) == "function" and textOrFn(self) or textOrFn
		if text and GameTooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(text, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	owner:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
end

-- Theme -------------------------------------------------------------------------------------
-- One flat, dark look for every SquadRank surface: colours live here, nowhere else.
UI.C = {
	bg = { 0.047, 0.051, 0.063, 0.97 },
	side = { 0.031, 0.035, 0.043, 1 },
	card = { 1, 1, 1, 0.035 },
	cardHi = { 1, 1, 1, 0.07 },
	line = { 1, 1, 1, 0.07 },
	accent = { 0.25, 0.72, 1 },
	gold = { 1, 0.80, 0.30 },
	text = { 0.92, 0.93, 0.95 },
	muted = { 0.56, 0.59, 0.65 },
	good = { 0.30, 0.80, 0.42 },
	bad = { 0.90, 0.32, 0.28 },
}

UI.SCORE_COLORS = {
	{ 0.86, 0.24, 0.20 },
	{ 0.93, 0.52, 0.18 },
	{ 0.92, 0.78, 0.22 },
	{ 0.55, 0.80, 0.30 },
	{ 0.25, 0.76, 0.36 },
}

-- Colour for an average score (1.0 to 5.0), blended between the five score colours.
function UI.ScoreColor(score)
	score = Util.Clamp(tonumber(score) or 3, 1, 5)
	local low = math.floor(score)
	local high = math.min(5, low + 1)
	local t = score - low
	local a, b = UI.SCORE_COLORS[low], UI.SCORE_COLORS[high]
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

function UI.Hex(color)
	return ("ff%02x%02x%02x"):format(
		math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5)
	)
end

function UI.Colorize(text, color)
	return "|c" .. UI.Hex(color) .. text .. "|r"
end

function UI.SetColor(texture, color, alpha)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
end

-- A solid colour texture covering the whole frame.
function UI.Fill(frame, color, alpha, layer, sublevel)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
	texture:SetAllPoints()
	UI.SetColor(texture, color, alpha)
	return texture
end

-- A one-pixel outline.
function UI.Border(frame, color, alpha)
	color = color or UI.C.line
	local edges = {}
	local function edge(p1, p2, horizontal)
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetPoint(p1)
		t:SetPoint(p2)
		if horizontal then
			t:SetHeight(1)
		else
			t:SetWidth(1)
		end
		UI.SetColor(t, color, alpha)
		edges[#edges + 1] = t
	end
	edge("TOPLEFT", "TOPRIGHT", true)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	edge("TOPLEFT", "BOTTOMLEFT", false)
	edge("TOPRIGHT", "BOTTOMRIGHT", false)
	return edges
end

-- A floating surface (toasts, alerts): dark flat background, hairline border, accent top edge.
function UI.Panel(frameType, parent)
	local frame = CreateFrame(frameType, nil, parent)
	frame.srBg = UI.Fill(frame, UI.C.bg)
	UI.Border(frame, UI.C.line)
	local top = frame:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)
	UI.SetColor(top, UI.C.accent, 0.9)
	frame.srAccent = top
	return frame
end

function UI.Text(parent, font, justify)
	local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	text:SetJustifyH(justify or "LEFT")
	return text
end

function UI.Button(parent, label, width, height, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height or 22)
	button:SetText(label)
	if onClick then
		button:SetScript("OnClick", ns.Safe("button", onClick))
	end
	return button
end

-- Shows a button as chosen or not (used for score, role and tag buttons).
function UI.SetChosen(button, chosen)
	if chosen then
		button:LockHighlight()
		button:SetNormalFontObject("GameFontHighlight")
	else
		button:UnlockHighlight()
		button:SetNormalFontObject("GameFontNormal")
	end
end

local function fallbackWindow(title)
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	pcall(frame.SetBackdrop, frame, {
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	local text = UI.Text(frame, "GameFontNormal", "CENTER")
	text:SetPoint("TOP", 0, -8)
	text:SetText(title)
	frame.srTitle = text
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 0, 0)
	return frame
end

-- A movable window in the standard Blizzard panel style, with a content area in frame.content.
function UI.CreateWindow(width, height, title)
	local frame
	local ok, err = pcall(function()
		frame = CreateFrame("Frame", nil, UIParent, "ButtonFrameTemplate")
		ButtonFrameTemplate_HidePortrait(frame)
		ButtonFrameTemplate_HideButtonBar(frame)
		if frame.Inset then
			frame.Inset:Hide()
		end
		frame:SetTitle(title)
	end)
	if not ok then
		Debug.Log("UI", "ButtonFrameTemplate unavailable, using fallback window: %s", tostring(err))
		if frame then
			frame:Hide()
		end
		frame = fallbackWindow(title)
	end

	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 12, -30)
	content:SetPoint("BOTTOMRIGHT", -10, 10)
	frame.content = content

	function frame.SetWindowTitle(_, text)
		if frame.srTitle then
			frame.srTitle:SetText(text)
		elseif frame.SetTitle then
			frame:SetTitle(text)
		end
	end
	return frame
end

-- Row recycling by hand, used when ScrollBox is unavailable or simple lists are forced.
local function simpleList(parent, rowHeight, update)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -24, 0)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)
	local rows = {}

	local list = { kind = "simple" }
	function list.SetData(_, items)
		local width = math.max(50, scroll:GetWidth() or 50)
		child:SetSize(width, math.max(1, #items * rowHeight))
		for i, item in ipairs(items) do
			local row = rows[i]
			if not row then
				row = CreateFrame("Button", nil, child)
				rows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
			row:SetSize(width, rowHeight)
			update(row, item)
			row:Show()
		end
		for i = #items + 1, #rows do
			rows[i]:Hide()
		end
	end
	return list
end

local function scrollBoxList(parent, rowHeight, update)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	box:SetPoint("TOPLEFT", 0, 0)
	box:SetPoint("BOTTOMRIGHT", -16, 0)
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, -2)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 2)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(rowHeight)
	view:SetElementInitializer("Button", update)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)

	local list = { kind = "scrollbox" }
	function list.SetData(_, items)
		box:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
	end
	return list
end

-- A scrolling list filling `parent`. build(row) runs once per row frame, fill(row, item)
-- every time a row shows an item. Items must be tables. Returns an object with :SetData(items).
function UI.CreateList(parent, rowHeight, build, fill)
	local function update(row, item)
		if not row.srBuilt then
			row.srBuilt = true
			row:SetHeight(rowHeight)
			local highlight = row:CreateTexture(nil, "HIGHLIGHT")
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 1, 1, 0.08)
			build(row)
		end
		fill(row, item)
	end

	local forceSimple = ns.db and ns.db.settings.simpleLists
	if not forceSimple then
		local ok, result = pcall(scrollBoxList, parent, rowHeight, ns.Safe("list row", update))
		if ok then
			Debug.notes.listMode = "scrollbox"
			return result
		end
		Debug.Log("UI", "ScrollBox unavailable, using simple list: %s", tostring(result))
	end
	Debug.notes.listMode = "simple"
	return simpleList(parent, rowHeight, ns.Safe("list row", update))
end

-- Yes/No confirmation using Blizzard's popup. onAccept runs through the error wrapper.
function UI.Confirm(text, onAccept)
	if not StaticPopupDialogs.SQUADRANK_CONFIRM then
		StaticPopupDialogs.SQUADRANK_CONFIRM = {
			text = "%s",
			button1 = YES,
			button2 = NO,
			OnAccept = function(_, data)
				if type(data) == "function" then
					ns.Try("confirm", data)
				end
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,
		}
	end
	StaticPopup_Show("SQUADRANK_CONFIRM", text, nil, onAccept)
end

-- Opens a Blizzard context menu at the cursor. build(root) adds the entries.
function UI.ContextMenu(owner, build)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		Debug.Log("UI", "MenuUtil.CreateContextMenu is not available")
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		ns.Try("context menu", build, root)
	end)
end
