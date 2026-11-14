-- Settings, in two places that share the same saved values: the Settings page of the
-- SquadRank window, and Blizzard's own Settings panel (Options > AddOns > SquadRank).
-- Each Blizzard control is registered separately, so one failing control does not hide the others.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Debug = ns.Debug
local Compat = ns.Compat

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local CONTROLS = 18

function SettingsUI.Register()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then
		Debug.notes.settings = "Settings API missing"
		return
	end
	local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON)
	local saved = ns.db.settings
	local defaults = ns.DB.DEFAULT_SETTINGS
	local added = 0

	local function setting(key, label)
		return Settings.RegisterAddOnSetting(
			category,
			"SquadRank_" .. key,
			key,
			saved,
			type(defaults[key]),
			label,
			defaults[key]
		)
	end

	local function add(what, fn)
		local ok = ns.Try("settings " .. what, function()
			fn()
			return true
		end)
		if ok then
			added = added + 1
		end
	end

	local function checkbox(key, label, tip, onChange)
		add(key, function()
			local s = setting(key, label)
			Settings.CreateCheckbox(category, s, tip)
			if onChange and s.SetValueChangedCallback then
				pcall(s.SetValueChangedCallback, s, ns.Safe("settings " .. key, onChange))
			end
		end)
	end

	local function slider(key, label, tip, low, high)
		add(key, function()
			local options = Settings.CreateSliderOptions(low, high, 1)
			if
				options.SetLabelFormatter
				and MinimalSliderWithSteppersMixin
				and MinimalSliderWithSteppersMixin.Label
			then
				options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
			end
			Settings.CreateSlider(category, setting(key, label), options, tip)
		end)
	end

	local function button(what, label, buttonText, tip, onClick)
		add(what, function()
			local handler = ns.Safe("settings " .. what, onClick)
			layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, handler, tip, true))
		end)
	end

	checkbox("toastEnabled", L.SET_TOAST, L.SET_TOAST_TIP)
	slider("toastDuration", L.SET_DURATION, L.SET_DURATION_TIP, 3, 30)
	checkbox("alertWhisper", L.SET_ALERT_WHISPER, L.SET_ALERT_WHISPER_TIP)
	checkbox("alertTarget", L.SET_ALERT_TARGET, L.SET_ALERT_TARGET_TIP)
	checkbox("alertTrade", L.SET_ALERT_TRADE, L.SET_ALERT_TRADE_TIP)
	checkbox("alertDuel", L.SET_ALERT_DUEL, L.SET_ALERT_DUEL_TIP)
	slider("alertCooldown", L.SET_ALERT_COOLDOWN, L.SET_ALERT_COOLDOWN_TIP, 0, 180)
	slider("minRatings", L.SET_MIN, L.SET_MIN_TIP, 1, 10)
	checkbox("promptAfterRun", L.SET_PROMPT, L.SET_PROMPT_TIP)
	checkbox("recentAllies", L.SET_RECENT, L.SET_RECENT_TIP)
	checkbox("avoidWarning", L.SET_AVOID, L.SET_AVOID_TIP)
	checkbox("sound", L.SET_SOUND, L.SET_SOUND_TIP)
	slider("minRunMinutes", L.SET_MIN_RUN, L.SET_MIN_RUN_TIP, 0, 30)
	checkbox("tooltipInfo", L.SET_TOOLTIP, L.SET_TOOLTIP_TIP)
	checkbox("allowShare", L.SET_SHARE, L.SET_SHARE_TIP)
	checkbox("minimapButton", L.SET_MINIMAP, L.SET_MINIMAP_TIP, function()
		if ns.MinimapButton then
			ns.MinimapButton.Update()
		end
	end)
	button("purge player", L.SET_PURGE_PLAYER, L.BTN_OPEN_LIST, L.SET_PURGE_PLAYER_TIP, function()
		ns.MainWindow.Show()
	end)
	button("purge all", L.SET_PURGE_ALL, L.BTN_PURGE, L.SET_PURGE_ALL_TIP, function()
		UI.Confirm(L.CONFIRM_PURGE_ALL, ns.Slash.PurgeAll)
	end)

	Settings.RegisterAddOnCategory(category)
	SettingsUI.category = category
	Debug.notes.settings = ("ok, %d of %d controls"):format(added, CONTROLS)
end

-- The Settings page of the SquadRank window ---------------------------------------------------

local C = UI.C
local ROW_H = 46
local controls = {}

local function changed(key)
	if key == "minimapButton" and ns.MinimapButton then
		ns.MinimapButton.Update()
	elseif key == "minRatings" and ns.MainWindow then
		ns.MainWindow.Refresh()
	elseif key == "allowShare" and ns.PlayerDetail then
		ns.PlayerDetail.Refresh()
	end
end

local function getter(key)
	return function()
		return ns.db.settings[key]
	end
end

local function setter(key)
	return function(value)
		if Compat.InCombat() then
			ns.Print(L.MSG_COMBAT)
			return
		end
		ns.db.settings[key] = value
		changed(key)
	end
end

local function buildPage(page)
	local y = 0
	-- More rows than fit: the page scrolls (mouse wheel glides, as elsewhere).
	local holder = CreateFrame("Frame", nil, page)
	holder:SetAllPoints()
	local scroll, parent = UI.SmoothScroll(holder)
	parent:SetWidth(600)

	local function section(title)
		local text = UI.Text(parent, "GameFontNormalSmall")
		text:SetPoint("TOPLEFT", 2, -y - 6)
		text:SetText(UI.Caps(title))
		text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
		y = y + 26
	end

	local function row(label, tip, makeControl)
		local f = CreateFrame("Frame", nil, parent)
		f:SetPoint("TOPLEFT", 0, -y)
		f:SetPoint("TOPRIGHT", -14, -y)
		f:SetHeight(ROW_H - 6)
		UI.Fill(f, C.card)
		local name = UI.Text(f, "GameFontHighlight")
		name:SetPoint("TOPLEFT", 14, -7)
		name:SetText(label)
		local hint = UI.Text(f, "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", 14, -24)
		hint:SetWidth(430)
		hint:SetWordWrap(false)
		hint:SetText(tip)
		f:EnableMouse(true)
		UI.TruncationTooltip(f, hint)
		local control = makeControl(f)
		control:SetPoint("RIGHT", -14, 0)
		controls[#controls + 1] = control
		y = y + ROW_H
	end

	local function toggle(key, label, tip)
		row(label, tip, function(f)
			return UI.Toggle(f, getter(key), setter(key))
		end)
	end

	local function stepper(key, label, tip, low, high)
		row(label, tip, function(f)
			return UI.Stepper(f, getter(key), setter(key), low, high)
		end)
	end

	section(L.SET_SECTION_ALERTS)
	toggle("promptAfterRun", L.SET_PROMPT, L.SET_PROMPT_TIP_SHORT)
	stepper("minRunMinutes", L.SET_MIN_RUN, L.SET_MIN_RUN_TIP, 0, 30)
	toggle("toastEnabled", L.SET_TOAST, L.SET_TOAST_TIP)
	stepper("toastDuration", L.SET_DURATION, L.SET_DURATION_TIP, 3, 30)
	toggle("avoidWarning", L.SET_AVOID, L.SET_AVOID_TIP)
	toggle("sound", L.SET_SOUND, L.SET_SOUND_TIP)
	section(L.SET_SECTION_CONTEXT)
	toggle("alertWhisper", L.SET_ALERT_WHISPER, L.SET_ALERT_WHISPER_TIP)
	toggle("alertTarget", L.SET_ALERT_TARGET, L.SET_ALERT_TARGET_TIP)
	toggle("alertTrade", L.SET_ALERT_TRADE, L.SET_ALERT_TRADE_TIP)
	toggle("alertDuel", L.SET_ALERT_DUEL, L.SET_ALERT_DUEL_TIP)
	stepper("alertCooldown", L.SET_ALERT_COOLDOWN, L.SET_ALERT_COOLDOWN_TIP, 0, 180)
	section(L.SET_SECTION_REPUTATION)
	stepper("minRatings", L.SET_MIN, L.SET_MIN_TIP, 1, 10)
	section(L.SET_SECTION_INTERFACE)
	toggle("minimapButton", L.SET_MINIMAP, L.SET_MINIMAP_TIP)
	toggle("tooltipInfo", L.SET_TOOLTIP, L.SET_TOOLTIP_TIP)
	toggle("recentAllies", L.SET_RECENT, L.SET_RECENT_TIP)
	section(L.SET_SECTION_DATA)
	toggle("allowShare", L.SET_SHARE, L.SET_SHARE_TIP)
	row(L.SET_PURGE_ALL, L.SET_PURGE_ALL_TIP, function(f)
		return UI.FlatButton(f, L.BTN_DELETE_ALL, 110, 26, function()
			UI.Confirm(L.CONFIRM_PURGE_ALL, ns.Slash.PurgeAll)
		end, "danger")
	end)
	parent:SetHeight(y)
	scroll.Repaint()
end

-- Values can change in Blizzard's panel too, so the controls re-read them on every visit.
local function showPage()
	for _, control in ipairs(controls) do
		if control.Sync then
			control:Sync(false)
		end
	end
end

ns.Hub.AddPage("settings", {
	label = L.NAV_SETTINGS,
	build = buildPage,
	show = showPage,
})

function SettingsUI.Open()
	ns.Hub.Show("settings")
end
