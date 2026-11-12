-- A player's history as a drawer that slides in over the right side of the Players page:
-- reputation at a glance (average score, role bars, top tags), then every rating, newest first.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Util = ns.Util
local Compat = ns.Compat

local PlayerDetail = {}
ns.PlayerDetail = PlayerDetail

local C = UI.C
local WIDTH = 340
local BAR_W = 150

local drawer, scroll, child, body
local w = {}
local currentPid

local function place(offset)
	drawer:ClearAllPoints()
	drawer:SetPoint("TOPRIGHT", offset, 0)
	drawer:SetPoint("BOTTOMRIGHT", offset, 0)
end

local function slide(open)
	local from = drawer.offset or WIDTH
	local to = open and 0 or WIDTH + 8
	if open then
		drawer:Show()
	end
	Anim.Tween("detail drawer", open and 0.24 or 0.18, function(p)
		drawer.offset = Anim.Lerp(from, to, p)
		place(drawer.offset)
	end, function()
		if not open then
			drawer:Hide()
		end
	end)
end

local function historyText(rec)
	local db = ns.db
	local lines = {}
	if #rec.ratings == 0 then
		lines[#lines + 1] = "|cff808080" .. L.DETAIL_NO_RATINGS .. "|r"
	end
	for i = #rec.ratings, 1, -1 do
		local rating = rec.ratings[i]
		local score = tonumber(rating.score) or 0
		local role = ns.Ratings.ROLE_SET[rating.role] and L["ROLE_" .. rating.role] or "-"
		local scoreText = UI.Colorize(L.DETAIL_SCORE_FMT:format(score), UI.ScoreColor(score))
		lines[#lines + 1] = ("%s   %s   |cff9aa0aa%s|r"):format(scoreText, role, UI.Date(rating.createdAt))
		local run = rating.runId and db.runs[rating.runId]
		if run and run.instanceName then
			lines[#lines + 1] = "|cff9aa0aa" .. UI.RunName(run) .. "|r"
		end
		local tags = {}
		for _, id in ipairs(rating.tags or {}) do
			local info = ns.Ratings.TAG_INFO[id]
			if info then
				tags[#tags + 1] = UI.Colorize(L["TAG_" .. id], info.positive and C.good or C.bad)
			end
		end
		if #tags > 0 then
			lines[#lines + 1] = table.concat(tags, "  ")
		end
		local note = Util.Sanitize(rating.note)
		if note ~= "" then
			lines[#lines + 1] = '|cffd8d8d8"' .. note .. '"|r'
		end
		if rating.imported then
			lines[#lines + 1] = "|cff808080" .. L.DETAIL_IMPORTED .. "|r"
		end
		lines[#lines + 1] = " "
	end
	return table.concat(lines, "\n")
end

local function paint(rec)
	local db = ns.db
	local summary = ns.Ratings.Summary(rec, Compat.Now(), db.settings.minRatings)
	w.name:SetText(UI.ColoredName(rec))
	local sub = {}
	if rec.classFile then
		sub[#sub + 1] =
			L.DETAIL_CLASS_LEVEL:format(tostring(rec.level or "?"), Util.Escape(UI.ClassName(rec.classFile)))
	end
	sub[#sub + 1] = L.DETAIL_SEEN_SHORT:format(UI.Date(rec.lastSeen))
	w.sub:SetText(table.concat(sub, "   "))

	local labelColor = ({ trusted = C.good, mixed = C.gold, caution = C.bad })[summary.label] or C.muted
	w.label:Set(L["LABEL_" .. summary.label], labelColor, 0.22)
	w.avoidPill:SetShown(rec.avoid == true)
	w.avoid:SetText(rec.avoid and L.BTN_UNAVOID or L.BTN_AVOID)
	w.share:SetShown(db.settings.allowShare == true)
	if w.sharePanel:IsShown() then
		if db.settings.allowShare then
			w.shareBox:SetText(UI.ShareText(rec))
		else
			w.sharePanel:Hide()
		end
	end

	if summary.count > 0 and summary.weighted then
		w.score:SetText(UI.Colorize(("%.1f"):format(summary.weighted), UI.ScoreColor(summary.weighted)))
		w.scoreSub:SetText(
			summary.count == 1 and L.DETAIL_AVG_SINGLE
				or ns.Locale.Count("DETAIL_AVG_RATINGS", summary.count, summary.count)
		)
	else
		w.score:SetText("|cff808080-|r")
		w.scoreSub:SetText(L.DETAIL_NO_RATINGS)
	end

	for i, role in ipairs(ns.Ratings.ROLES) do
		local bar = w.roles[i]
		local stat = summary.roles[role]
		if stat then
			bar.value:SetText(("%.1f"):format(stat.avg))
			UI.SetColor(bar.fill, UI.ScoreColor(stat.avg))
			bar.target = (BAR_W - 20) * stat.avg / 5
		else
			bar.value:SetText("|cff606060-|r")
			bar.target = 1
		end
	end
	Anim.Tween("detail bars", 0.4, function(p)
		for _, bar in ipairs(w.roles) do
			bar.fill:SetWidth(math.max(1, bar.target * p))
		end
	end)

	local tags = {}
	for i = 1, math.min(4, #summary.topTags) do
		local id = summary.topTags[i].id
		local info = ns.Ratings.TAG_INFO[id]
		tags[#tags + 1] = UI.Colorize(L["TAG_" .. id], info and info.positive and C.good or C.bad)
	end
	w.tags:SetText(#tags > 0 and table.concat(tags, "   ") or "")

	body:SetText(historyText(rec))
	child:SetHeight(math.max(10, (tonumber((body:GetStringHeight())) or 10) + 8))
end

local function build(page)
	drawer = CreateFrame("Frame", nil, page)
	drawer:SetWidth(WIDTH)
	drawer:SetFrameLevel((page:GetFrameLevel() or 1) + 20)
	drawer:EnableMouse(true)
	UI.Fill(drawer, C.side, 0.99)
	local edge = drawer:CreateTexture(nil, "BORDER")
	edge:SetPoint("TOPLEFT")
	edge:SetPoint("BOTTOMLEFT")
	edge:SetWidth(1)
	UI.SetColor(edge, C.accent, 0.35)
	drawer.offset = WIDTH + 8
	place(drawer.offset)
	drawer:Hide()

	local close = UI.CloseButton(drawer, PlayerDetail.Close, 24)
	close:SetPoint("TOPRIGHT", -6, -6)

	w.name = UI.Text(drawer, "GameFontHighlightLarge")
	w.name:SetPoint("TOPLEFT", 18, -16)
	w.name:SetWidth(WIDTH - 60)
	w.name:SetWordWrap(false)
	w.sub = UI.Text(drawer, "GameFontDisableSmall")
	w.sub:SetPoint("TOPLEFT", 18, -38)
	w.label = UI.Pill(drawer)
	w.label:SetPoint("TOPLEFT", 18, -56)
	w.avoidPill = UI.Pill(drawer)
	w.avoidPill:SetPoint("LEFT", w.label, "RIGHT", 6, 0)
	w.avoidPill:Set(L.LABEL_avoid, C.bad, 0.35)
	w.avoidPill:Hide()

	-- Share (opt-in): a plain one-line summary to copy into chat. Never includes notes.
	w.share = UI.FlatButton(drawer, L.SHARE_BTN, 80, 20, function()
		if not currentPid then
			return
		end
		if w.sharePanel:IsShown() then
			w.sharePanel:Hide()
			return
		end
		w.shareBox:SetText(UI.ShareText(ns.db.players[currentPid]))
		w.sharePanel:Show()
		w.shareBox:SetFocus()
		w.shareBox:HighlightText()
	end, "link")
	w.share:SetPoint("TOPRIGHT", -34, -8)

	w.score = UI.Text(drawer, "GameFontHighlightHuge2")
	w.score:SetPoint("TOPLEFT", 18, -84)
	w.scoreSub = UI.Text(drawer, "GameFontDisableSmall")
	w.scoreSub:SetPoint("TOPLEFT", 18, -120)

	w.roles = {}
	for i, role in ipairs(ns.Ratings.ROLES) do
		local y = -84 - (i - 1) * 18
		local bar = {}
		bar.name = UI.Text(drawer, "GameFontHighlightSmall")
		bar.name:SetPoint("TOPLEFT", 110, y)
		bar.name:SetText(L["ROLE_" .. role])
		local track = drawer:CreateTexture(nil, "ARTWORK")
		track:SetPoint("TOPLEFT", 160, y - 5)
		track:SetSize(BAR_W - 20, 5)
		track:SetColorTexture(1, 1, 1, 0.08)
		bar.fill = drawer:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
		bar.fill:SetHeight(5)
		bar.fill:SetWidth(1)
		bar.value = UI.Text(drawer, "GameFontHighlightSmall", "RIGHT")
		bar.value:SetPoint("TOPRIGHT", -16, y)
		bar.target = 1
		w.roles[i] = bar
	end
	w.tags = UI.Text(drawer, "GameFontHighlightSmall")
	w.tags:SetPoint("TOPLEFT", 18, -144)
	w.tags:SetWidth(WIDTH - 36)

	local rate = UI.FlatButton(drawer, L.BTN_RATE, 96, 28, function()
		if currentPid and not Compat.InCombat() then
			ns.RateFrame.OpenPlayers({ currentPid })
		end
	end, "primary")
	rate:SetPoint("TOPLEFT", 18, -168)
	w.avoid = UI.FlatButton(drawer, L.BTN_AVOID, 96, 28, function()
		local rec = currentPid and ns.db.players[currentPid]
		if rec then
			ns.MainWindow.SetAvoid(currentPid, not rec.avoid)
		end
	end, "ghost")
	w.avoid:SetPoint("LEFT", rate, "RIGHT", 8, 0)
	local purge = UI.FlatButton(drawer, L.BTN_PURGE, 96, 28, function()
		if currentPid then
			ns.Slash.ConfirmPurgePlayer(currentPid)
		end
	end, "danger")
	purge:SetPoint("LEFT", w.avoid, "RIGHT", 8, 0)

	local history = UI.Text(drawer, "GameFontDisableSmall")
	history:SetPoint("TOPLEFT", 18, -212)
	history:SetText(UI.Caps(L.DETAIL_HISTORY))
	local line = drawer:CreateTexture(nil, "BORDER")
	line:SetPoint("TOPLEFT", 18, -226)
	line:SetPoint("TOPRIGHT", -18, -226)
	line:SetHeight(1)
	UI.SetColor(line, C.line)

	local holder = CreateFrame("Frame", nil, drawer)
	holder:SetPoint("TOPLEFT", 18, -234)
	holder:SetPoint("BOTTOMRIGHT", -8, 12)
	scroll, child = UI.SmoothScroll(holder)
	child:SetWidth(WIDTH - 46)
	body = UI.Text(child, "GameFontHighlightSmall")
	body:SetPoint("TOPLEFT", 0, -2)
	body:SetWidth(WIDTH - 50)
	body:SetWordWrap(true)
	body:SetSpacing(3)

	-- The share panel covers the top of the history while open.
	w.sharePanel = CreateFrame("Frame", nil, drawer)
	w.sharePanel:SetPoint("TOPLEFT", 12, -204)
	w.sharePanel:SetPoint("TOPRIGHT", -12, -204)
	w.sharePanel:SetHeight(64)
	w.sharePanel:SetFrameLevel((drawer:GetFrameLevel() or 1) + 10)
	w.sharePanel:EnableMouse(true)
	UI.Fill(w.sharePanel, C.bg, 1)
	UI.Border(w.sharePanel, C.accent, 0.5)
	local holderBox
	holderBox, w.shareBox = UI.TextBox(w.sharePanel, WIDTH - 48, 24, "", 255)
	holderBox:SetPoint("TOPLEFT", 6, -8)
	w.shareBox:HookScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	local shareHint = UI.Text(w.sharePanel, "GameFontDisableSmall")
	shareHint:SetPoint("TOPLEFT", 8, -40)
	shareHint:SetWidth(WIDTH - 52)
	shareHint:SetWordWrap(false)
	shareHint:SetText(L.SHARE_HINT)
	w.sharePanel:Hide()
end

function PlayerDetail.Close()
	if drawer and drawer:IsShown() then
		currentPid = nil
		w.sharePanel:Hide()
		slide(false)
	end
end

function PlayerDetail.Refresh()
	if not drawer or not drawer:IsShown() or not currentPid then
		return
	end
	local rec = ns.db.players[currentPid]
	if not rec then
		PlayerDetail.Close()
		return
	end
	if Compat.InCombat() then
		return
	end
	paint(rec)
end

function PlayerDetail.Open(pid)
	if not ns.db or not ns.db.players[pid] then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	ns.Hub.Show("players")
	if not drawer then
		local page = ns.Hub.Page("players")
		if not page then
			return
		end
		build(page)
	end
	local switching = currentPid ~= nil and currentPid ~= pid and drawer:IsShown()
	if currentPid ~= pid then
		w.sharePanel:Hide()
	end
	currentPid = pid
	paint(ns.db.players[pid])
	scroll.Reset()
	if switching then
		child:SetAlpha(0.2)
		Anim.FadeIn(child, 0.2, "detail body")
	else
		slide(true)
	end
end

function PlayerDetail.Current()
	return currentPid
end

-- The text currently offered for copying, or nil (used by the tests).
function PlayerDetail.ShareText()
	return w.sharePanel and w.sharePanel:IsShown() and w.shareBox:GetText() or nil
end

function PlayerDetail.ShareButton()
	return w.share
end
