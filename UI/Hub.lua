-- The one SquadRank window. A sidebar on the left (Rate, Players, Runs, Settings, About)
-- switches pages in place with a short slide and fade; nothing opens a second window.
-- Pages register themselves with Hub.AddPage and are built the first time they are shown.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Compat = ns.Compat
local Events = ns.Events

local Hub = {}
ns.Hub = Hub

local WIDTH, HEIGHT = 820, 560
local SIDEBAR, HEADER, PAD = 176, 52, 16
local NAV_H = 36
local ORDER = { "rate", "players", "runs", "stats", "settings", "about" }
local ICONS = {
	rate = "Interface\\Icons\\INV_Misc_Note_01",
	players = "Interface\\Icons\\INV_Misc_GroupLooking",
	runs = "Interface\\Icons\\INV_Misc_Map_01",
	stats = "Interface\\Icons\\INV_Misc_Spyglass_03",
	settings = "Interface\\Icons\\Trade_Engineering",
	about = "Interface\\Icons\\INV_Misc_Book_09",
}

local C = UI.C
local frame, content, indicator
local pages, nav = {}, {}
local current

-- Registers a page. spec = { label = text, build = fn(page), show = fn(page), hide = fn(page) }.
function Hub.AddPage(key, spec)
	pages[key] = { spec = spec }
end

local function paintNav()
	for _, key in ipairs(ORDER) do
		local item = nav[key]
		if item then
			local on = key == current
			item.label:SetTextColor(on and 1 or C.muted[1], on and 1 or C.muted[2], on and 1 or C.muted[3])
			item.bg:SetAlpha(on and 1 or 0)
			pcall(item.icon.SetDesaturated, item.icon, not on)
			item.icon:SetAlpha(on and 1 or 0.6)
		end
	end
end

local function moveIndicator(key, animated)
	local item = nav[key]
	if not item then
		return
	end
	local to = item.index
	local from = indicator.at or to
	indicator.at = to
	local function place(i)
		indicator:ClearAllPoints()
		indicator:SetPoint("TOPLEFT", frame.sidebar, "TOPLEFT", 8, -(HEADER + 8 + (i - 1) * NAV_H) - 4)
	end
	if animated and from ~= to then
		Anim.Tween("hub indicator", 0.2, function(p)
			place(Anim.Lerp(from, to, p))
		end)
	else
		place(to)
	end
end

-- Builds a page on first use and returns its frame.
function Hub.Page(key)
	local page = pages[key]
	if not page then
		return nil
	end
	if not frame then
		Hub.Build()
	end
	if not page.frame then
		local f = CreateFrame("Frame", nil, content)
		f:SetAllPoints()
		f:Hide()
		page.frame = f
		ns.Try("hub build " .. key, page.spec.build, f)
	end
	return page.frame
end

local function switchTo(key, animated)
	local page = pages[key]
	if not page then
		return
	end
	local f = Hub.Page(key)
	if current and current ~= key and pages[current].frame then
		local old = pages[current]
		old.frame:Hide()
		if old.spec.hide then
			ns.Try("hub hide " .. current, old.spec.hide, old.frame)
		end
	end
	local changed = current ~= key
	current = key
	frame.subtitle:SetText(page.spec.title or page.spec.label)
	paintNav()
	moveIndicator(key, animated)
	f:Show()
	if page.spec.show then
		ns.Try("hub show " .. key, page.spec.show, f)
	end
	if changed and animated then
		f:SetAlpha(0)
		Anim.Tween("hub page", 0.2, function(p)
			f:SetAlpha(p)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", 14 * (1 - p), 0)
			f:SetPoint("BOTTOMRIGHT", 14 * (1 - p), 0)
		end, function()
			f:SetAlpha(1)
			f:ClearAllPoints()
			f:SetAllPoints()
		end)
	end
end

local function navButton(key, index)
	local item = CreateFrame("Button", nil, frame.sidebar)
	item:SetSize(SIDEBAR, NAV_H - 4)
	item:SetPoint("TOPLEFT", 0, -(HEADER + 8 + (index - 1) * NAV_H))
	item.index = index
	item.bg = item:CreateTexture(nil, "BACKGROUND")
	item.bg:SetPoint("TOPLEFT", 8, 0)
	item.bg:SetPoint("BOTTOMRIGHT", -8, 0)
	UI.SetColor(item.bg, C.accent, 0.12)
	local hover = item:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT", 8, 0)
	hover:SetPoint("BOTTOMRIGHT", -8, 0)
	hover:SetColorTexture(1, 1, 1, 0.05)

	item.icon = item:CreateTexture(nil, "ARTWORK")
	item.icon:SetSize(18, 18)
	item.icon:SetPoint("LEFT", 20, 0)
	item.icon:SetTexture(ICONS[key])
	item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	item.label:SetPoint("LEFT", 48, 0)
	item:SetFontString(item.label)
	item:SetText(pages[key].spec.label)
	item.label:ClearAllPoints()
	item.label:SetPoint("LEFT", 48, 0)
	item.label:SetWidth(SIDEBAR - 48 - 44)
	item.label:SetWordWrap(false)
	item.label:SetJustifyH("LEFT")
	UI.TruncationTooltip(item, item.label)

	item.badge = UI.Pill(item)
	item.badge:SetPoint("RIGHT", -18, 0)
	item.badge:Hide()

	item:SetScript(
		"OnClick",
		ns.Safe("hub nav", function()
			if current ~= key then
				switchTo(key, true)
			end
		end)
	)
	nav[key] = item
end

function Hub.Build()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER", 0, 40)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	UI.Fill(frame, C.bg)
	UI.Border(frame, { 0, 0, 0 }, 0.9)

	-- Sidebar with the logo, the pages and the author line.
	local sidebar = CreateFrame("Frame", nil, frame)
	sidebar:SetPoint("TOPLEFT")
	sidebar:SetPoint("BOTTOMLEFT")
	sidebar:SetWidth(SIDEBAR)
	UI.Fill(sidebar, C.side)
	local divider = sidebar:CreateTexture(nil, "BORDER")
	divider:SetPoint("TOPRIGHT")
	divider:SetPoint("BOTTOMRIGHT")
	divider:SetWidth(1)
	UI.SetColor(divider, C.line)
	frame.sidebar = sidebar

	local glow = sidebar:CreateTexture(nil, "BACKGROUND", nil, 1)
	glow:SetPoint("TOPLEFT")
	glow:SetPoint("TOPRIGHT")
	glow:SetHeight(HEADER)
	glow:SetColorTexture(1, 1, 1, 1)
	local gradient = CreateColor
		and pcall(
			glow.SetGradient,
			glow,
			"VERTICAL",
			CreateColor(0, 0, 0, 0),
			CreateColor(C.accent[1], C.accent[2], C.accent[3], 0.10)
		)
	if not gradient then
		UI.SetColor(glow, C.accent, 0.04)
	end

	local logo = sidebar:CreateTexture(nil, "ARTWORK")
	logo:SetSize(26, 26)
	logo:SetPoint("TOPLEFT", 16, -13)
	logo:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
	logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local name = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	name:SetPoint("LEFT", logo, "RIGHT", 10, 0)
	name:SetText(L.ADDON)

	indicator = sidebar:CreateTexture(nil, "OVERLAY")
	indicator:SetSize(3, NAV_H - 12)
	UI.SetColor(indicator, C.accent)

	for i, key in ipairs(ORDER) do
		if pages[key] then
			navButton(key, i)
		end
	end

	local author = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	author:SetPoint("BOTTOMLEFT", 18, 30)
	author:SetText(L.ABOUT_BY:format(UI.Colorize(L.AUTHOR, C.gold)))
	local version = sidebar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	version:SetPoint("BOTTOMLEFT", 18, 14)
	version:SetText(L.ABOUT_VERSION:format(ns.VERSION))

	-- Header strip over the pages: drag handle, page title, close cross.
	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", SIDEBAR, 0)
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
	end)
	local line = header:CreateTexture(nil, "BORDER")
	line:SetPoint("BOTTOMLEFT", PAD, 0)
	line:SetPoint("BOTTOMRIGHT", -PAD, 0)
	line:SetHeight(1)
	UI.SetColor(line, C.line)
	frame.subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	frame.subtitle:SetPoint("LEFT", PAD + 2, 0)
	local close = UI.CloseButton(header, function()
		Hub.Hide()
	end, 28)
	close:SetPoint("RIGHT", -12, 0)
	frame.header = header

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", SIDEBAR + PAD, -(HEADER + 12))
	content:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	pcall(content.SetClipsChildren, content, true)

	frame:HookScript("OnHide", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
		local page = current and pages[current]
		if page and page.frame and page.spec.hide then
			ns.Try("hub hide " .. current, page.spec.hide, page.frame)
		end
		if ns.SquadAlert and not frame.srCombatHidden then
			ns.SquadAlert.Schedule()
		end
	end)
	Hub.UpdateBadges()
end

-- Opens the window on a page ("players" when none is given).
function Hub.Show(key)
	if not ns.db then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if not frame then
		Hub.Build()
	end
	key = key or current or "players"
	local opening = not frame:IsShown() or (frame:GetAlpha() or 1) < 1
	frame.srCombatHidden = nil
	if opening then
		Anim.FadeIn(frame, 0.18, "hub window")
	end
	switchTo(key, not opening)
	Hub.UpdateBadges()
end

function Hub.Hide()
	if frame and frame:IsShown() then
		Anim.FadeOut(frame, 0.14, nil, "hub window")
	end
end

function Hub.Toggle(key)
	if frame and frame:IsShown() and (not key or key == current) then
		Hub.Hide()
	else
		Hub.Show(key)
	end
end

function Hub.IsShown(key)
	if not frame or not frame:IsShown() then
		return false
	end
	return key == nil or key == current
end

function Hub.Current()
	return current
end

-- Count of players waiting in "Rate your squad", shown on the Rate entry and the minimap.
function Hub.PendingCount()
	local db = ns.db
	if not db or not ns.Runs then
		return 0
	end
	local count = 0
	for _, run in ipairs(ns.Runs.List(db)) do
		if run.prompt == "pending" then
			count = count + math.max(0, #(run.members or {}) - ns.Runs.RatedCount(db, run))
		end
	end
	return count
end

function Hub.UpdateBadges()
	local pending = Hub.PendingCount()
	local item = nav.rate
	if item then
		item.badge:SetShown(pending > 0)
		if pending > 0 then
			item.badge:Set(tostring(pending), C.gold, 0.3)
		end
	end
	if ns.MinimapButton then
		ns.MinimapButton.Update(pending)
	end
end

-- In combat the window steps aside and comes back when the fight is over.
Events.On("PLAYER_REGEN_DISABLED", "Hub", function()
	if frame and frame:IsShown() then
		frame.srCombatHidden = true
		Anim.Cancel("hub window")
		frame:Hide()
	end
end)

Events.On("PLAYER_REGEN_ENABLED", "Hub", function()
	if frame and frame.srCombatHidden then
		frame.srCombatHidden = nil
		Anim.FadeIn(frame, 0.25, "hub window")
	end
end)
