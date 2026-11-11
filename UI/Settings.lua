-- Settings in Blizzard's own Settings panel (Options > AddOns > SquadRank).
-- Each control is registered separately, so one failing control does not hide the others.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Debug = ns.Debug

local SettingsUI = {}
ns.SettingsUI = SettingsUI

local CONTROLS = 7

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

	local function checkbox(key, label, tip)
		add(key, function()
			Settings.CreateCheckbox(category, setting(key, label), tip)
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
	slider("minRatings", L.SET_MIN, L.SET_MIN_TIP, 1, 10)
	checkbox("promptAfterRun", L.SET_PROMPT, L.SET_PROMPT_TIP)
	checkbox("recentAllies", L.SET_RECENT, L.SET_RECENT_TIP)
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
