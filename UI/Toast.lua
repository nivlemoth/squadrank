-- One compact toast frame with a queue, for "a player you rated joined". It slides in and out.
-- Never shown in combat: a visible toast is put back in the queue when combat starts and
-- returns when it ends.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Compat = ns.Compat
local Events = ns.Events
local Debug = ns.Debug

local Toast = { queue = {}, current = nil, token = 0 }
ns.Toast = Toast

local WIDTH, PADDING = 300, 12
local MAX_ROWS = 5
local TOP, SLIDE = -150, 24

local frame

local function place(offset)
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOP", 0, TOP + offset)
end

local function build()
	frame = UI.Panel("Button", UIParent)
	frame:SetWidth(WIDTH)
	place(0)
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

	local close = UI.CloseButton(frame, function()
		Toast.Dismiss()
	end, 20)
	close:SetPoint("TOPRIGHT", -4, -4)

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
	UI.SetColor(frame.srAccent, toast.accent or UI.C.accent, 0.9)
	if toast.sound then
		UI.PlaySound(toast.sound)
	end
	frame.body:SetText(table.concat(toast.lines, "\n"))
	frame:SetHeight(PADDING + frame.title:GetStringHeight() + 6 + frame.body:GetStringHeight() + PADDING)

	place(SLIDE)
	frame:SetAlpha(0)
	frame:Show()
	Anim.Tween("toast", 0.28, function(p)
		place(SLIDE * (1 - p))
		frame:SetAlpha(p)
	end)

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

-- toast = { title, lines = {...}, duration, onClick, accent = colour?, sound = kind? }
function Toast.Push(toast)
	Toast.queue[#Toast.queue + 1] = toast
	Events.RunOutOfCombat("toast", pump)
end

function Toast.Dismiss()
	if frame and frame:IsShown() then
		Anim.Tween("toast", 0.2, function(p)
			place(SLIDE * 0.5 * p)
			frame:SetAlpha(1 - p)
		end, function()
			frame:Hide()
		end)
	end
	Toast.current = nil
	Events.RunOutOfCombat("toast", pump)
end

Events.On("PLAYER_REGEN_DISABLED", "Toast", function()
	if Toast.current then
		table.insert(Toast.queue, 1, Toast.current)
		Toast.current = nil
		Toast.token = Toast.token + 1
		Anim.Cancel("toast")
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
		Toast.Push({
			title = L.TOAST_JOIN_PLAYER,
			lines = lines,
			duration = duration,
			onClick = openHistory(pids[1]),
			sound = "join",
		})
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
		title = L.TOAST_JOIN_PLAYERS,
		lines = lines,
		duration = duration + 4,
		sound = "join",
		onClick = function()
			if ns.MainWindow then
				ns.MainWindow.Show()
			end
		end,
	})
end

-- A red warning: players on the avoid list are in the group. Shown even when join toasts are off.
function Toast.ShowAvoid(pids)
	local db = ns.db
	local lines = {}
	for i, pid in ipairs(pids) do
		if i > MAX_ROWS then
			lines[#lines + 1] = L.FMT_MORE:format(#pids - MAX_ROWS)
			break
		end
		lines[#lines + 1] = UI.ColoredName(db.players[pid])
	end
	Debug.Log("TOAST", "avoid warning for %d players", #pids)
	Toast.Push({
		title = UI.Colorize(#pids == 1 and L.TOAST_AVOID_PLAYER or L.TOAST_AVOID_PLAYERS, UI.C.bad),
		lines = lines,
		duration = db.settings.toastDuration + 4,
		onClick = openHistory(pids[1]),
		accent = UI.C.bad,
		sound = "avoid",
	})
end
