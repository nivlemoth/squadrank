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
	return table.concat(names, ", ")
end

-- Text lines describing a player's reputation, shared by the toast and the history window.
function UI.SummaryLines(summary)
	local lines = {}
	if summary.count == 1 then
		lines[#lines + 1] = L.FMT_RATED_ONE:format(summary.weighted or 0)
	elseif summary.count > 1 then
		lines[#lines + 1] = L.FMT_RATED_MANY:format(summary.count, summary.weighted or 0)
	end
	for _, role in ipairs(ns.Ratings.ROLES) do
		local stat = summary.roles[role]
		if stat then
			if stat.count == 1 then
				lines[#lines + 1] = L.FMT_ROLE_ONE:format(L["ROLE_" .. role], stat.avg)
			else
				lines[#lines + 1] = L.FMT_ROLE_MANY:format(L["ROLE_" .. role], stat.avg, stat.count)
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
