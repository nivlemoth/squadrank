-- One compact toast frame with a queue. Used for "a player you rated joined" and for the
-- "Rate your squad" prompt. Never shown in combat: a visible toast is put back in the queue
-- when combat starts and returns when it ends.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Util = ns.Util
local Compat = ns.Compat
local Events = ns.Events
local Debug = ns.Debug

local Toast = { queue = {}, current = nil, token = 0 }
ns.Toast = Toast

local WIDTH, PADDING = 300, 12
local MAX_ROWS = 5
local PROMPT_SECONDS = 45

local frame

local function build()
	local ok = pcall(function()
		frame = CreateFrame("Button", nil, UIParent, "TooltipBackdropTemplate")
	end)
	if not ok or not frame then
		frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
		pcall(frame.SetBackdrop, frame, {
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		pcall(frame.SetBackdropColor, frame, 0, 0, 0, 0.9)
	end
	frame:SetWidth(WIDTH)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:Hide()

	frame.title = UI.Text(frame, "GameFontNormal")
	frame.title:SetPoint("TOPLEFT", PADDING, -PADDING)
	frame.title:SetWidth(WIDTH - 2 * PADDING - 16)

	frame.body = UI.Text(frame, "GameFontHighlightSmall")
	frame.body:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
	frame.body:SetWidth(WIDTH - 2 * PADDING)
	frame.body:SetWordWrap(true)
	frame.body:SetSpacing(2)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript(
		"OnClick",
		ns.Safe("toast close", function()
			Toast.Dismiss()
		end)
	)

	frame.buttons = {}
	for i = 1, 2 do
		local button = UI.Button(frame, "", 90, 22, function()
			local toast = Toast.current
			local action = toast and toast.buttons and toast.buttons[i]
			Toast.Dismiss()
			if action and action.onClick then
				action.onClick()
			end
		end)
		frame.buttons[i] = button
	end
	frame.buttons[1]:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, PADDING)
	frame.buttons[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, PADDING)

	frame:SetScript(
		"OnClick",
		ns.Safe("toast click", function()
			local toast = Toast.current
			Toast.Dismiss()
			if toast and toast.onClick then
				toast.onClick()
			end
		end)
	)
end

local function display(toast)
	if not frame then
		build()
	end
	frame.title:SetText(toast.title)
	frame.body:SetText(table.concat(toast.lines, "\n"))

	local hasButtons = toast.buttons ~= nil
	for i = 1, 2 do
		local action = hasButtons and toast.buttons[i]
		frame.buttons[i]:SetShown(action and true or false)
		if action then
			frame.buttons[i]:SetText(action.text)
		end
	end

	local height = PADDING + frame.title:GetStringHeight() + 6 + frame.body:GetStringHeight() + PADDING
	if hasButtons then
		height = height + 28
	end
	frame:SetHeight(height)
	frame:Show()

	Toast.current = toast
	Toast.token = Toast.token + 1
	local token = Toast.token
	C_Timer.After(toast.duration, function()
		if Toast.token == token and Toast.current == toast then
			ns.Try("toast timeout", Toast.Dismiss)
		end
	end)
end

local function pump()
	if Toast.current or #Toast.queue == 0 then
		return
	end
	display(table.remove(Toast.queue, 1))
end

-- toast = { title, lines = {...}, duration, onClick, buttons = { { text, onClick }, ... } }
function Toast.Push(toast)
	Toast.queue[#Toast.queue + 1] = toast
	Events.RunOutOfCombat("toast", pump)
end

function Toast.Dismiss()
	if frame then
		frame:Hide()
	end
	Toast.current = nil
	Events.RunOutOfCombat("toast", pump)
end

Events.On("PLAYER_REGEN_DISABLED", "Toast", function()
	if Toast.current then
		table.insert(Toast.queue, 1, Toast.current)
		Toast.current = nil
		Toast.token = Toast.token + 1
		frame:Hide()
		Events.RunOutOfCombat("toast", pump)
	end
end)

local function openHistory(pid)
	return function()
		if ns.PlayerDetail then
			ns.PlayerDetail.Open(pid)
		end
	end
end

-- Announces players (already known to have ratings) who just joined the group session.
function Toast.ShowJoin(pids)
	local db = ns.db
	local now, minRatings = Compat.Now(), db.settings.minRatings
	local duration = db.settings.toastDuration
	Debug.Log("TOAST", "join toast for %d players", #pids)

	if #pids == 1 then
		local rec = db.players[pids[1]]
		local summary = ns.Ratings.Summary(rec, now, minRatings)
		local lines = UI.SummaryLines(summary)
		table.insert(lines, 1, UI.ColoredName(rec) .. "   " .. UI.LabelText(summary.label))
		Toast.Push({ title = L.TOAST_JOIN_ONE, lines = lines, duration = duration, onClick = openHistory(pids[1]) })
		return
	end

	local lines = {}
	for i, pid in ipairs(pids) do
		if i > MAX_ROWS then
			lines[#lines + 1] = L.FMT_MORE:format(#pids - MAX_ROWS)
			break
		end
		local rec = db.players[pid]
		local summary = ns.Ratings.Summary(rec, now, minRatings)
		local line = UI.ColoredName(rec) .. "   " .. UI.LabelText(summary.label)
		if summary.topTags[1] then
			line = line .. "   " .. L["TAG_" .. summary.topTags[1].id]
		end
		lines[#lines + 1] = line
	end
	Toast.Push({
		title = L.TOAST_JOIN_MANY,
		lines = lines,
		duration = duration + 4,
		onClick = function()
			if ns.MainWindow then
				ns.MainWindow.Show()
			end
		end,
	})
end

-- Offers to rate the members of a finished run. "Later" (or ignoring it) leaves the run pending.
function Toast.ShowRunPrompt(run)
	local name = Util.Escape(run.instanceName or L.UNKNOWN_INSTANCE)
	Toast.Push({
		title = L.PROMPT_TITLE,
		lines = { L.PROMPT_BODY:format(name, #run.members) },
		duration = PROMPT_SECONDS,
		buttons = {
			{
				text = L.BTN_RATE,
				onClick = function()
					if ns.RateFrame and ns.db.runs[run.id] then
						ns.RateFrame.OpenRun(ns.db.runs[run.id])
					end
				end,
			},
			{ text = L.BTN_LATER },
		},
	})
end
