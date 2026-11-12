-- "Rate your squad": a small card that slides down from the top of the screen after a group
-- you played in has broken up. It waits (no timeout) with a soft pulse. Click it to rate
-- everyone in one window; close it and it stays quiet until the next group ends.
-- Never shown in combat or while you are still in a group.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Compat = ns.Compat
local Events = ns.Events
local Debug = ns.Debug

local SquadAlert = {}
ns.SquadAlert = SquadAlert

local WIDTH, HEIGHT = 300, 56
local TOP, SLIDE = -96, 48
local ROLE_ATLAS = {
	"groupfinder-icon-role-large-tank",
	"groupfinder-icon-role-large-heal",
	"groupfinder-icon-role-large-dps",
}

local frame

local function place(offset)
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOP", 0, TOP + offset)
end

local function hide(animated)
	if not frame or not frame:IsShown() then
		return
	end
	if frame.pulse then
		frame.pulse:Stop()
	end
	if not animated then
		Anim.Cancel("alert")
		frame:Hide()
		return
	end
	Anim.Tween("alert", 0.22, function(p)
		place(SLIDE * 0.6 * p)
		frame:SetAlpha(1 - p)
	end, function()
		frame:Hide()
		frame:SetAlpha(1)
	end)
end

local function build()
	frame = UI.Panel("Button", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:RegisterForClicks("LeftButtonUp")
	place(0)
	frame:Hide()
	UI.SetColor(frame.srAccent, UI.C.gold, 0.9)

	local glow = frame:CreateTexture(nil, "BORDER")
	glow:SetPoint("TOPLEFT", 4, -4)
	glow:SetPoint("BOTTOMRIGHT", -4, 4)
	glow:SetColorTexture(1, 0.78, 0.1, 1)
	pcall(glow.SetBlendMode, glow, "ADD")
	glow:SetAlpha(0.08)
	frame.pulse = Anim.Pulse(glow, 0.03, 0.16, 1.1)

	local hover = frame:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT", 4, -4)
	hover:SetPoint("BOTTOMRIGHT", -4, 4)
	hover:SetColorTexture(1, 1, 1, 0.07)

	for i, atlas in ipairs(ROLE_ATLAS) do
		local icon = frame:CreateTexture(nil, "ARTWORK")
		icon:SetSize(22, 22)
		icon:SetPoint("LEFT", 8 + (i - 1) * 15, 0)
		pcall(icon.SetAtlas, icon, atlas)
	end

	frame.title = UI.Text(frame, "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", 64, -12)
	frame.title:SetText(L.ALERT_TITLE)

	frame.body = UI.Text(frame, "GameFontHighlightSmall")
	frame.body:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
	frame.body:SetWidth(WIDTH - 64 - 28)
	frame.body:SetWordWrap(false)

	local close = UI.CloseButton(frame, SquadAlert.Dismiss, 20)
	close:SetPoint("TOPRIGHT", -4, -4)

	frame:SetScript("OnClick", ns.Safe("alert click", SquadAlert.Open))
	UI.SetTooltip(frame, L.ALERT_TIP)
end

local function show(runs)
	if not frame then
		build()
	end
	local players = 0
	for _, run in ipairs(runs) do
		players = players + #run.members
	end
	if #runs == 1 then
		frame.body:SetText(L.ALERT_ONE:format(UI.RunName(runs[1]), players))
	else
		frame.body:SetText(L.ALERT_MANY:format(#runs, players))
	end
	if frame:IsShown() then
		return
	end
	Debug.Log("ALERT", "shown: %d runs, %d players", #runs, players)
	place(SLIDE)
	frame:SetAlpha(0)
	frame:Show()
	Anim.Tween("alert", 0.35, function(p)
		place(SLIDE * (1 - p))
		frame:SetAlpha(p)
	end)
	if frame.pulse then
		frame.pulse:Play()
	end
end

local function check()
	local db = ns.db
	if not db or ns.readOnly or not db.settings.promptAfterRun or Compat.IsInGroup() then
		hide(true)
		return
	end
	local runs = ns.Runs.AlertList(db, Compat.Now())
	if #runs == 0 then
		hide(true)
		return
	end
	show(runs)
end

-- Looks again shortly (after the roster and run tracker have settled), out of combat.
function SquadAlert.Schedule()
	Events.Debounce("alert", 2, function()
		Events.RunOutOfCombat("alert", check)
	end)
end

-- Opens the rating window for every run the alert stands for.
function SquadAlert.Open()
	local db = ns.db
	if not db then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	local runs = ns.Runs.AlertList(db, Compat.Now())
	if not ns.readOnly then
		db.alertDismissedAt = Compat.Now()
	end
	hide(true)
	if #runs > 0 and ns.RateFrame then
		ns.RateFrame.OpenRuns(runs)
	end
end

-- Closes the alert. The runs stay in the Runs tab and under /sr rate.
function SquadAlert.Dismiss()
	if ns.db and not ns.readOnly then
		ns.db.alertDismissedAt = Compat.Now()
	end
	Debug.Log("ALERT", "dismissed")
	hide(true)
end

function SquadAlert.IsShown()
	return frame ~= nil and frame:IsShown() and true or false
end

Events.On("GROUP_LEFT", "SquadAlert", SquadAlert.Schedule)
Events.On("GROUP_JOINED", "SquadAlert", SquadAlert.Schedule)
Events.On("PLAYER_ENTERING_WORLD", "SquadAlert", SquadAlert.Schedule)
Events.On("PLAYER_REGEN_ENABLED", "SquadAlert", SquadAlert.Schedule)
Events.On("PLAYER_REGEN_DISABLED", "SquadAlert", function()
	hide(false)
end)
