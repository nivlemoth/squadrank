-- The About page: what SquadRank is, who made it, and how your data is handled.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim

local C = UI.C
local glowPulse

local function feature(page, index, title, text, color)
	local card = CreateFrame("Frame", nil, page)
	card:SetSize(192, 96)
	card:SetPoint("TOPLEFT", (index - 1) * 202, -150)
	UI.Fill(card, C.card)
	local top = card:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)
	UI.SetColor(top, color)
	local head = UI.Text(card, "GameFontHighlight")
	head:SetPoint("TOPLEFT", 12, -14)
	head:SetText(title)
	local body = UI.Text(card, "GameFontDisableSmall")
	body:SetPoint("TOPLEFT", 12, -34)
	body:SetWidth(170)
	body:SetWordWrap(true)
	body:SetSpacing(2)
	body:SetText(text)
	return card
end

local function build(page)
	local glow = page:CreateTexture(nil, "BACKGROUND")
	glow:SetSize(96, 96)
	glow:SetPoint("TOPLEFT", -8, 8)
	UI.SetColor(glow, C.accent, 0.18)
	pcall(glow.SetBlendMode, glow, "ADD")
	glowPulse = Anim.Pulse(glow, 0.05, 0.25, 1.6)

	local logo = page:CreateTexture(nil, "ARTWORK")
	logo:SetSize(80, 80)
	logo:SetPoint("TOPLEFT", 0, 0)
	logo:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
	logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local frameBorder = CreateFrame("Frame", nil, page)
	frameBorder:SetAllPoints(logo)
	UI.Border(frameBorder, { 1, 1, 1 }, 0.15)
	page.logo = logo

	local title = UI.Text(page, "GameFontHighlightHuge2")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 20, -4)
	title:SetText(L.ADDON)
	local version = UI.Pill(page)
	version:SetPoint("LEFT", title, "RIGHT", 12, 0)
	version:Set("v" .. ns.VERSION, C.accent, 0.22)

	local by = UI.Text(page, "GameFontNormalLarge")
	by:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	by:SetText(L.ABOUT_BY:format(UI.Colorize(L.AUTHOR, C.gold)))
	local tagline = UI.Text(page, "GameFontDisable")
	tagline:SetPoint("TOPLEFT", by, "BOTTOMLEFT", 0, -8)
	tagline:SetText(L.ABOUT_TAGLINE)

	feature(page, 1, L.ABOUT_F1_TITLE, L.ABOUT_F1_TEXT, C.accent)
	feature(page, 2, L.ABOUT_F2_TITLE, L.ABOUT_F2_TEXT, C.gold)
	feature(page, 3, L.ABOUT_F3_TITLE, L.ABOUT_F3_TEXT, C.good)

	local cmdHead = UI.Text(page, "GameFontNormalSmall")
	cmdHead:SetPoint("TOPLEFT", 2, -270)
	cmdHead:SetText(L.ABOUT_COMMANDS:upper())
	cmdHead:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	local commands = UI.Text(page, "GameFontHighlightSmall")
	commands:SetPoint("TOPLEFT", 2, -292)
	commands:SetWidth(590)
	commands:SetSpacing(4)
	commands:SetText(table.concat({ L.MSG_HELP_1, L.MSG_HELP_2, L.MSG_HELP_3, L.MSG_HELP_4, L.MSG_HELP_5 }, "\n"))

	local privacy = UI.Text(page, "GameFontDisableSmall")
	privacy:SetPoint("BOTTOMLEFT", 2, 4)
	privacy:SetWidth(590)
	privacy:SetText(L.ABOUT_PRIVACY)
end

ns.Hub.AddPage("about", {
	label = L.NAV_ABOUT,
	title = L.ABOUT_TITLE,
	build = build,
	show = function(page)
		Anim.Pop(page.logo, 1.12)
		if glowPulse then
			glowPulse:Play()
		end
	end,
	hide = function()
		if glowPulse then
			glowPulse:Stop()
		end
	end,
})
