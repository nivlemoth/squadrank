-- The versioned "what's new" window. It appears once per version (see db.seenVersion),
-- can be reopened with /sr whatsnew, and uses the same flat cards as the About page.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Compat = ns.Compat
local Events = ns.Events

local WhatsNew = {}
ns.WhatsNew = WhatsNew

local C = UI.C
local WINDOW_W, WINDOW_H = 600, 470
local CARD_H, CARD_GAP = 56, 6
local frame

local function feature(page, index, title, text, color, y)
	local card = CreateFrame("Frame", nil, page)
	card:SetPoint("TOPLEFT", 0, -y)
	card:SetPoint("TOPRIGHT", 0, -y)
	card:SetHeight(CARD_H)
	UI.Fill(card, C.card)

	local bar = card:CreateTexture(nil, "ARTWORK")
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("BOTTOMLEFT")
	bar:SetWidth(3)
	UI.SetColor(bar, color, 0.9)

	local number = UI.Text(card, "GameFontHighlight")
	number:SetPoint("TOPLEFT", 14, -9)
	number:SetText(tostring(index))
	number:SetTextColor(color[1], color[2], color[3])

	local head = UI.Text(card, "GameFontHighlight")
	head:SetPoint("TOPLEFT", 38, -8)
	head:SetText(title)

	local body = UI.Text(card, "GameFontDisableSmall")
	body:SetPoint("TOPLEFT", 38, -27)
	body:SetWidth(520)
	body:SetWordWrap(true)
	body:SetSpacing(1)
	body:SetText(text)

	return y + CARD_H + CARD_GAP
end

-- A soft square behind the logo, so the header has the same weight as the About page.
local function pageIcon(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(60, 60)
	holder:SetPoint("TOPLEFT", 0, 0)

	local glow = holder:CreateTexture(nil, "BACKGROUND")
	glow:SetSize(88, 88)
	glow:SetPoint("CENTER")
	UI.SetColor(glow, C.accent, 0.12)
	pcall(glow.SetBlendMode, glow, "ADD")

	local texture = holder:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	UI.Border(holder, { 1, 1, 1 }, 0.15)
	return texture
end

local function build()
	frame = UI.CreateWindow(WINDOW_W, WINDOW_H, L.WHATS_NEW_TITLE:format(ns.VERSION))

	local icon = pageIcon(frame.content)
	icon:SetTexture(UI.ICON)
	frame.logo = icon

	local title = UI.Text(frame.content, "GameFontHighlightHuge2")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 16, -2)
	title:SetText(L.ADDON)

	local version = UI.Pill(frame.content)
	version:SetPoint("LEFT", title, "RIGHT", 12, 0)
	version:Set("v" .. ns.VERSION, C.accent, 0.22)

	local subtitle = UI.Text(frame.content, "GameFontDisable")
	subtitle:SetPoint("TOPLEFT", icon, "TOPRIGHT", 16, -32)
	subtitle:SetWidth(470)
	subtitle:SetWordWrap(true)
	subtitle:SetSpacing(2)
	subtitle:SetText(L.WHATS_NEW_SUBTITLE)

	local line = frame.content:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", 0, -72)
	line:SetPoint("TOPRIGHT", 0, -72)
	line:SetHeight(1)
	UI.SetColor(line, C.line, 0.9)

	local y = 82
	y = feature(frame.content, 1, L.WHATS_NEW_F1_TITLE, L.WHATS_NEW_F1_TEXT, C.accent, y)
	y = feature(frame.content, 2, L.WHATS_NEW_F2_TITLE, L.WHATS_NEW_F2_TEXT, C.gold, y)
	y = feature(frame.content, 3, L.WHATS_NEW_F3_TITLE, L.WHATS_NEW_F3_TEXT, C.bad, y)
	y = feature(frame.content, 4, L.WHATS_NEW_F4_TITLE, L.WHATS_NEW_F4_TEXT, C.good, y)
	feature(frame.content, 5, L.WHATS_NEW_F5_TITLE, L.WHATS_NEW_F5_TEXT, C.accent, y)

	local tip = UI.Text(frame.content, "GameFontDisableSmall")
	tip:SetPoint("BOTTOMLEFT", 0, 8)
	tip:SetWidth(330)
	tip:SetWordWrap(true)
	tip:SetSpacing(2)
	tip:SetText(L.WHATS_NEW_TIP)

	local gotIt = UI.FlatButton(frame.content, L.BTN_GOT_IT, 92, 26, function()
		WhatsNew.Hide()
	end, "primary")
	gotIt:SetPoint("BOTTOMRIGHT", 0, 4)

	local settings = UI.FlatButton(frame.content, L.BTN_OPEN_SETTINGS, 128, 26, function()
		WhatsNew.Hide()
		ns.Hub.Show("settings")
	end)
	settings:SetPoint("RIGHT", gotIt, "LEFT", -8, 0)

	frame:Hide()
end

function WhatsNew.Show(force)
	if not ns.db then
		return
	end
	if Compat.InCombat() then
		if force then
			ns.Print(L.MSG_COMBAT)
		end
		return
	end
	if not frame then
		build()
	end
	if not force then
		ns.db.seenVersion = ns.VERSION
	end
	frame:Show()
	Anim.FadeIn(frame, 0.18, "whatsnew")
	Anim.Pop(frame.logo, 1.06)
end

function WhatsNew.Hide()
	if not frame then
		return
	end
	Anim.Cancel("whatsnew")
	frame:Hide()
	frame:SetAlpha(1)
end

function WhatsNew.IsShown()
	return frame ~= nil and frame:IsShown() and true or false
end

-- Called once from PLAYER_LOGIN. Never nags: one window per version, and only if enabled.
function WhatsNew.MaybeShow()
	local db = ns.db
	if not db or ns.readOnly then
		return
	end
	if not db.settings.showWhatsNew then
		return
	end
	if db.seenVersion == ns.VERSION then
		return
	end
	WhatsNew.Show(false)
end

-- Like every SquadRank window, it steps aside in combat and comes back afterwards.
Events.On("PLAYER_REGEN_DISABLED", "WhatsNew", function()
	if frame and frame:IsShown() then
		frame.srCombatHidden = true
		frame:Hide()
	end
end)

Events.On("PLAYER_REGEN_ENABLED", "WhatsNew", function()
	if frame and frame.srCombatHidden then
		frame.srCombatHidden = nil
		frame:Show()
	end
end)
