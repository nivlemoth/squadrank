-- The Rate page of the SquadRank window: one card per player, grouped by run. One click on a
-- score (1-5) saves the rating. The card then opens to show the tags that fit that score and
-- a note box; those are optional and saved as you click. Used for "Rate your squad" (one or
-- several runs) and for single players (unit menu, /sr rate <name>, the Players page).
-- Opening the page by itself shows every group still waiting for a rating.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Util = ns.Util
local Compat = ns.Compat
local Events = ns.Events
local Debug = ns.Debug

local RateFrame = {}
ns.RateFrame = RateFrame

local CARD_W, CARD_H, DETAIL_H, HEADER_H, GAP = 590, 54, 90, 30, 6
local PIP, PIP_GAP = 30, 4
local CHIP_W, CHIP_H, CHIP_GAP, CHIPS_PER_ROW = 120, 22, 6, 4
local STAGGER, ENTER = 0.035, 0.24
local PENDING_LIMIT = 6

local SCORE_COLORS = UI.SCORE_COLORS
local C = UI.C
local ROLE_ATLAS = {
	tank = "groupfinder-icon-role-large-tank",
	healer = "groupfinder-icon-role-large-heal",
	dps = "groupfinder-icon-role-large-dps",
}

local page, scroll, child
local w = {}
local hasContent = false
local opening = false
local cardPool, headerPool = {}, {}
local layoutItems = {}
local sections = {}
local expanded

local function setColor(texture, color, alpha)
	texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

-- Layout ------------------------------------------------------------------------------------

local function layout()
	local y = 0
	for _, item in ipairs(layoutItems) do
		local f = item.frame
		f:ClearAllPoints()
		if item.kind == "header" then
			f:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
			y = y + HEADER_H
		else
			f:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(y + (f.enterOffset or 0)))
			f:SetHeight(f.h)
			y = y + f.h + GAP
		end
	end
	child:SetHeight(math.max(1, y))
end

local function cardTarget(card)
	return card == expanded and CARD_H + DETAIL_H or CARD_H
end

-- Eases every card toward its target height (one card opens while another closes).
local function animateHeights()
	local from = {}
	for _, item in ipairs(layoutItems) do
		if item.kind == "card" then
			from[item.frame] = item.frame.h
		end
	end
	Anim.Tween("rate heights", 0.2, function(p)
		for card, start in pairs(from) do
			card.h = Anim.Lerp(start, cardTarget(card), p)
		end
		layout()
	end, function()
		for card in pairs(from) do
			if card ~= expanded then
				card.details:Hide()
			end
		end
	end)
end

-- Cards fade in one after another, rising a few pixels into place.
local function animateEntrance()
	local cards = {}
	for _, item in ipairs(layoutItems) do
		if item.kind == "card" then
			cards[#cards + 1] = item.frame
		end
	end
	local total = ENTER + STAGGER * math.min(#cards, 12)
	for _, card in ipairs(cards) do
		card:SetAlpha(0)
		card.enterOffset = 12
	end
	layout()
	Anim.Tween("rate enter", total, function(p)
		local t = p * total
		for i, card in ipairs(cards) do
			local start = STAGGER * math.min(i - 1, 12)
			local e = Anim.EaseOut(Util.Clamp((t - start) / ENTER, 0, 1))
			card:SetAlpha(e)
			card.enterOffset = 12 * (1 - e)
		end
		layout()
	end, function()
		for _, card in ipairs(cards) do
			card:SetAlpha(1)
			card.enterOffset = 0
		end
		layout()
	end)
end

-- Progress ----------------------------------------------------------------------------------

local function countRated()
	local rated, total = 0, 0
	for _, section in ipairs(sections) do
		for _, card in ipairs(section.cards) do
			total = total + 1
			if card.entry.score and card.entry.ratingId then
				rated = rated + 1
			end
		end
	end
	return rated, total
end

local function paintHeader(section)
	local header = section.header
	if not header then
		return
	end
	local rated = 0
	for _, card in ipairs(section.cards) do
		if card.entry.ratingId then
			rated = rated + 1
		end
	end
	header.count:SetText(L.RUN_RATED_FMT:format(rated, #section.cards))
end

local function updateProgress(animated)
	local rated, total = countRated()
	local done = total > 0 and rated >= total
	w.progressText:SetText(done and L.RATE_ALL_DONE or L.RATE_PROGRESS:format(rated, total))
	local barWidth = w.bar:GetWidth()
	if not barWidth or barWidth <= 0 then
		barWidth = CARD_W
	end
	local target = total > 0 and math.max(1, barWidth * rated / total) or 1
	local from = w.fill.current or 1
	setColor(w.fill, done and SCORE_COLORS[5] or C.accent)
	if animated then
		Anim.Tween("rate progress", 0.35, function(p)
			w.fill.current = Anim.Lerp(from, target, p)
			w.fill:SetWidth(w.fill.current)
		end)
	else
		w.fill.current = target
		w.fill:SetWidth(target)
	end
	if done and animated then
		Anim.Pop(w.done, 1.15)
	end
	for _, section in ipairs(sections) do
		paintHeader(section)
	end
end

-- Cards -------------------------------------------------------------------------------------

local function tagSetFor(card)
	if card.tagSet then
		return card.tagSet
	end
	local score = card.entry.score
	return (score and score <= 2) and "negative" or "positive"
end

local function paintChips(card)
	local entry = card.entry
	local set = tagSetFor(card)
	local slot = 0
	for _, chip in ipairs(card.chips) do
		local visible = (set == "positive") == chip.tag.positive
		chip:SetShown(visible)
		if visible then
			chip:ClearAllPoints()
			chip:SetPoint(
				"TOPLEFT",
				(slot % CHIPS_PER_ROW) * (CHIP_W + CHIP_GAP),
				-math.floor(slot / CHIPS_PER_ROW) * (CHIP_H + 4)
			)
			slot = slot + 1
			local on = entry.tags[chip.tag.id] == true
			if on then
				chip.bg:SetColorTexture(chip.tag.positive and 0.2 or 0.75, chip.tag.positive and 0.65 or 0.2, 0.2, 0.55)
				chip.label:SetTextColor(1, 1, 1)
			else
				chip.bg:SetColorTexture(1, 1, 1, 0.06)
				chip.label:SetTextColor(0.8, 0.8, 0.8)
			end
		end
	end
	card.swap:SetText(set == "positive" and L.RATE_SHOW_NEGATIVE or L.RATE_SHOW_POSITIVE)
end

local function paintCard(card)
	local entry = card.entry
	local db = ns.db
	local rec = db.players[entry.pid]
	if not rec then
		return
	end
	card.name:SetText(UI.ColoredName(rec))

	local summary = ns.Ratings.Summary(rec, Compat.Now(), db.settings.minRatings)
	local parts = { L["ROLE_" .. entry.role] }
	if rec.classFile then
		parts[#parts + 1] =
			L.DETAIL_CLASS_LEVEL:format(tostring(rec.level or "?"), Util.Escape(UI.ClassName(rec.classFile)))
	end
	parts[#parts + 1] = UI.LabelText(summary.label)
	local roles = UI.RoleText(summary)
	if roles ~= "" then
		parts[#parts + 1] = roles
	end
	card.sub:SetText(table.concat(parts, "   "))
	pcall(card.roleIcon.SetAtlas, card.roleIcon, ROLE_ATLAS[entry.role])

	for score, pip in ipairs(card.pips) do
		local color = SCORE_COLORS[score]
		if entry.score == score then
			setColor(pip.bg, color, 0.95)
			pip.label:SetTextColor(1, 1, 1)
		else
			pip.bg:SetColorTexture(0.1, 0.1, 0.1, 0.85)
			pip.label:SetTextColor(color[1], color[2], color[3])
		end
	end
	if entry.score then
		setColor(card.accent, SCORE_COLORS[entry.score])
	else
		card.accent:SetColorTexture(0.4, 0.4, 0.4, 0.6)
	end
	card.check:SetShown(entry.ratingId ~= nil)
	UI.SetColor(card.bg, card == expanded and C.cardHi or C.card)
	if card == expanded then
		paintChips(card)
		if not card.note:HasFocus() then
			card.note:SetText(entry.note or "")
		end
		card.noteHolder.PaintHint()
	end
end

local function persist(card)
	local db = ns.db
	local entry = card.entry
	if not entry.score or not db.players[entry.pid] then
		return false
	end
	if ns.readOnly then
		ns.Print(L.MSG_READONLY:format(tostring(ns.readOnlyReason)))
		return false
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return false
	end
	local tags = {}
	for _, tag in ipairs(ns.Ratings.TAGS) do
		if entry.tags[tag.id] then
			tags[#tags + 1] = tag.id
		end
	end
	local rating, err = ns.Ratings.Save(db, entry.pid, {
		id = entry.ratingId,
		score = entry.score,
		role = entry.role,
		tags = tags,
		note = entry.note,
		runId = entry.runId,
	}, Compat.Now())
	if not rating then
		ns.Print(L.RATE_FAILED:format(tostring(err)))
		return false
	end
	if not entry.ratingId then
		Debug.Log("RATE", "saved: hash %d, score %d", Util.Hash(entry.pid), rating.score)
	end
	entry.ratingId = rating.id

	local run = entry.runId and db.runs[entry.runId]
	if run and run.prompt ~= "done" and ns.Runs.RatedCount(db, run) >= #run.members then
		ns.Runs.SetPrompt(db, run.id, "done")
	end
	Events.Debounce("rate refresh", 0.4, function()
		ns.Slash.RefreshWindows()
	end)
	ns.Hub.UpdateBadges()
	return true
end

local function expand(card)
	if expanded == card then
		return
	end
	local old = expanded
	expanded = card
	if card then
		card.tagSet = nil
		card.details:Show()
		paintCard(card)
	end
	if old then
		old.note:ClearFocus()
		paintCard(old)
	end
	animateHeights()
end

local function setScore(card, score)
	local entry = card.entry
	local previous, wasSaved = entry.score, entry.ratingId ~= nil
	entry.score = score
	if not persist(card) then
		entry.score = previous
		return
	end
	card.tagSet = nil
	paintCard(card)
	Anim.Pop(card.pips[score])
	if not wasSaved then
		Anim.Pop(card.check, 1.8)
	end
	if expanded ~= card then
		expand(card)
	else
		paintChips(card)
	end
	updateProgress(true)
end

local function makeButton(parent, width, height, font)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.12)
	button.label = button:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	button.label:SetPoint("CENTER")
	button.label:SetWidth(math.max(8, width - 8))
	button.label:SetWordWrap(false)
	UI.TruncationTooltip(button, button.label)
	button:SetFontString(button.label)
	return button
end

local function buildCard()
	local card = CreateFrame("Button", nil, child)
	card:SetSize(CARD_W, CARD_H)
	card.h = CARD_H
	pcall(card.SetClipsChildren, card, true)
	card:RegisterForClicks("LeftButtonUp")

	card.bg = card:CreateTexture(nil, "BACKGROUND")
	card.bg:SetAllPoints()
	local hover = card:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT")
	hover:SetPoint("TOPRIGHT")
	hover:SetHeight(CARD_H)
	hover:SetColorTexture(1, 1, 1, 0.04)
	card.accent = card:CreateTexture(nil, "ARTWORK")
	card.accent:SetPoint("TOPLEFT")
	card.accent:SetPoint("BOTTOMLEFT")
	card.accent:SetWidth(3)

	card.role = CreateFrame("Button", nil, card)
	card.role:SetSize(30, 30)
	card.role:SetPoint("TOPLEFT", 10, -11)
	card.roleIcon = card.role:CreateTexture(nil, "ARTWORK")
	card.roleIcon:SetAllPoints()
	local roleHover = card.role:CreateTexture(nil, "HIGHLIGHT")
	roleHover:SetAllPoints()
	roleHover:SetColorTexture(1, 1, 1, 0.15)
	card.role:SetScript(
		"OnClick",
		ns.Safe("rate role", function()
			local entry = card.entry
			local roles = ns.Ratings.ROLES
			for i, role in ipairs(roles) do
				if role == entry.role then
					entry.role = roles[i % #roles + 1]
					break
				end
			end
			persist(card)
			paintCard(card)
			Anim.Pop(card.role, 1.25)
		end)
	)
	UI.SetTooltip(card.role, function()
		return L.RATE_ROLE_TIP:format(L["ROLE_" .. card.entry.role])
	end)

	card.name = UI.Text(card, "GameFontHighlightMedium")
	card.name:SetPoint("TOPLEFT", 50, -11)
	card.name:SetWidth(200)
	card.name:SetWordWrap(false)
	card.sub = UI.Text(card, "GameFontDisableSmall")
	card.sub:SetPoint("TOPLEFT", 50, -32)
	card.sub:SetWidth(300)
	card.sub:SetWordWrap(false)
	UI.TruncationTooltip(card, card.sub)

	card.pips = {}
	for score = 5, 1, -1 do
		local pip = makeButton(card, PIP, PIP, "GameFontNormalLarge")
		pip:SetPoint("TOPRIGHT", -12 - (5 - score) * (PIP + PIP_GAP), -12)
		pip:SetText(tostring(score))
		pip:SetScript(
			"OnClick",
			ns.Safe("rate score", function()
				setScore(card, score)
			end)
		)
		UI.SetTooltip(pip, L["SCORE_" .. score])
		card.pips[score] = pip
	end

	card.check = card:CreateTexture(nil, "OVERLAY")
	card.check:SetSize(18, 18)
	card.check:SetPoint("RIGHT", card.pips[1], "LEFT", -10, 0)
	pcall(card.check.SetAtlas, card.check, "checkmark-minimal")

	card.details = CreateFrame("Frame", nil, card)
	card.details:SetPoint("TOPLEFT", 50, -CARD_H)
	card.details:SetSize(CARD_W - 60, DETAIL_H)
	card.details:Hide()

	card.chips = {}
	for _, tag in ipairs(ns.Ratings.TAGS) do
		local chip = makeButton(card.details, CHIP_W, CHIP_H)
		chip.tag = tag
		chip:SetText(L["TAG_" .. tag.id])
		chip:SetScript(
			"OnClick",
			ns.Safe("rate tag", function()
				local tags = card.entry.tags
				tags[tag.id] = not tags[tag.id] or nil
				persist(card)
				paintChips(card)
				Anim.Pop(chip, 1.12)
			end)
		)
		card.chips[#card.chips + 1] = chip
	end
	card.swap = makeButton(card.details, CHIP_W, CHIP_H)
	card.swap.bg:SetColorTexture(0, 0, 0, 0)
	card.swap.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	card.swap:SetScript(
		"OnClick",
		ns.Safe("rate swap", function()
			card.tagSet = tagSetFor(card) == "positive" and "negative" or "positive"
			paintChips(card)
		end)
	)

	-- Two rows of four tags; the note box and the "other tags" link share the third row.
	local noteWidth = (CHIPS_PER_ROW - 1) * (CHIP_W + CHIP_GAP) - CHIP_GAP
	card.noteHolder, card.note = UI.TextBox(card.details, noteWidth, 26, L.RATE_NOTE_HINT, ns.Ratings.NOTE_MAX)
	card.noteHolder:SetPoint("TOPLEFT", 0, -2 * (CHIP_H + 4) - 6)
	card.swap:SetPoint("LEFT", card.noteHolder, "RIGHT", CHIP_GAP, 0)
	local function commitNote()
		local text = card.note:GetText() or ""
		if text ~= (card.entry.note or "") then
			card.entry.note = text
			persist(card)
		end
	end
	card.note:SetScript("OnEscapePressed", function(self)
		self:SetText(card.entry.note or "")
		self:ClearFocus()
	end)
	card.note:HookScript("OnEditFocusLost", ns.Safe("rate note", commitNote))

	card:SetScript(
		"OnClick",
		ns.Safe("rate card", function()
			expand(expanded ~= card and card or nil)
		end)
	)
	return card
end

local function buildHeader()
	local header = CreateFrame("Frame", nil, child)
	header:SetSize(CARD_W, HEADER_H)
	header.title = UI.Text(header, "GameFontNormalMed2")
	header.title:SetPoint("BOTTOMLEFT", 2, 7)
	header.count = UI.Text(header, "GameFontDisableSmall", "RIGHT")
	header.count:SetPoint("BOTTOMRIGHT", -4, 8)
	header.info = UI.Text(header, "GameFontDisableSmall")
	header.info:SetPoint("LEFT", header.title, "RIGHT", 12, 0)
	header.info:SetPoint("RIGHT", header.count, "LEFT", -12, 0)
	header.info:SetWordWrap(false)
	header:EnableMouse(true)
	header:SetScript("OnEnter", function(self)
		if self.run then
			UI.RunTooltip(self, self.run)
		end
	end)
	header:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	local line = header:CreateTexture(nil, "ARTWORK")
	line:SetPoint("BOTTOMLEFT", 0, 2)
	line:SetPoint("BOTTOMRIGHT", 0, 2)
	line:SetHeight(1)
	UI.SetColor(line, C.line)
	return header
end

-- Page --------------------------------------------------------------------------------------

local function leave()
	if expanded then
		expanded.note:ClearFocus()
	end
end

local function finish()
	leave()
	hasContent = false
	ns.Hub.Hide()
end

local function skipAll()
	local db = ns.db
	if not ns.readOnly then
		for _, section in ipairs(sections) do
			local run = section.run and db.runs[section.run.id]
			if run and run.prompt == "pending" then
				ns.Runs.SetPrompt(db, run.id, "skipped")
			end
		end
		ns.Slash.RefreshWindows()
	end
	finish()
end

local function build(f)
	page = f
	w.title = UI.Text(page, "GameFontHighlightLarge")
	w.title:SetPoint("TOPLEFT", 2, -2)
	w.progressText = UI.Text(page, "GameFontNormalSmall", "RIGHT")
	w.progressText:SetPoint("TOPRIGHT", -14, -6)

	w.bar = CreateFrame("Frame", nil, page)
	w.bar:SetPoint("TOPLEFT", 0, -28)
	w.bar:SetSize(CARD_W, 4)
	local track = w.bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(1, 1, 1, 0.08)
	w.fill = w.bar:CreateTexture(nil, "ARTWORK")
	w.fill:SetPoint("TOPLEFT")
	w.fill:SetPoint("BOTTOMLEFT")
	w.fill:SetWidth(1)

	local holder = CreateFrame("Frame", nil, page)
	holder:SetPoint("TOPLEFT", 0, -42)
	holder:SetPoint("BOTTOMRIGHT", 0, 40)
	scroll, child = UI.SmoothScroll(holder)
	child:SetSize(CARD_W, 1)

	w.empty = CreateFrame("Frame", nil, page)
	w.empty:SetAllPoints()
	w.empty:Hide()
	local check = w.empty:CreateTexture(nil, "ARTWORK")
	check:SetSize(48, 48)
	check:SetPoint("CENTER", 0, 50)
	pcall(check.SetAtlas, check, "checkmark-minimal")
	w.emptyCheck = check
	local emptyTitle = UI.Text(w.empty, "GameFontHighlightLarge", "CENTER")
	emptyTitle:SetPoint("TOP", check, "BOTTOM", 0, -12)
	emptyTitle:SetText(L.RATE_CAUGHT_UP)
	local emptyText = UI.Text(w.empty, "GameFontDisable", "CENTER")
	emptyText:SetPoint("TOP", emptyTitle, "BOTTOM", 0, -8)
	emptyText:SetWidth(420)
	emptyText:SetText(L.RATE_CAUGHT_UP_TEXT)

	w.hint = UI.Text(page, "GameFontDisableSmall")
	w.hint:SetPoint("BOTTOMLEFT", 2, 4)
	w.hint:SetWidth(380)
	w.hint:SetWordWrap(true)
	w.hint:SetText(L.RATE_HINT)

	w.done = UI.FlatButton(page, L.BTN_DONE, 104, 28, finish, "primary")
	w.done:SetPoint("BOTTOMRIGHT", -14, 0)
	w.skip = UI.FlatButton(page, L.BTN_SKIP, 96, 28, skipAll, "ghost")
	w.skip:SetPoint("RIGHT", w.done, "LEFT", -8, 0)
	UI.SetTooltip(w.skip, L.BTN_SKIP_TIP)
end

local function setEmpty(empty)
	w.empty:SetShown(empty)
	w.title:SetShown(not empty)
	w.progressText:SetShown(not empty)
	w.bar:SetShown(not empty)
	w.hint:SetShown(not empty)
	w.done:SetShown(not empty)
	if empty then
		w.skip:Hide()
		Anim.Pop(w.emptyCheck, 1.3)
	end
end

local function newEntry(pid, runId, role)
	local rec = ns.db.players[pid]
	local entry = { pid = pid, runId = runId, tags = {}, note = "" }
	local existing = runId and ns.Ratings.ForRun(rec, runId) or nil
	if existing then
		entry.ratingId = existing.id
		entry.score = existing.score
		entry.role = existing.role
		entry.note = existing.note or ""
		for _, id in ipairs(existing.tags or {}) do
			entry.tags[id] = true
		end
	end
	if not entry.role then
		local summary = ns.Ratings.Summary(rec, Compat.Now(), ns.db.settings.minRatings)
		entry.role = role or summary.lastRole or "dps"
	end
	return entry
end

-- groups = { { run = run or nil, members = { { pid, role }, ... } }, ... }
local function populate(groups, title)
	local db = ns.db
	if not ns.Hub.Page("rate") then
		return 0
	end
	if expanded then
		expanded.note:ClearFocus()
	end
	expanded = nil
	sections, layoutItems = {}, {}
	local cardIndex, headerIndex = 0, 0
	local showHeaders = #groups > 1 or (groups[1] and groups[1].run ~= nil)

	for _, group in ipairs(groups) do
		local section = { run = group.run, cards = {} }
		if showHeaders then
			headerIndex = headerIndex + 1
			local header = headerPool[headerIndex] or buildHeader()
			headerPool[headerIndex] = header
			if group.run then
				local run = group.run
				header.title:SetText(L.RATE_RUN_FMT:format(UI.RunName(run), UI.Date(run.endedAt or run.startedAt)))
				header.info:SetText(UI.RunSummary(run))
				header.run = run
			else
				header.title:SetText(L.RATE_NO_RUN)
				header.info:SetText("")
				header.run = nil
			end
			header:Show()
			section.header = header
			layoutItems[#layoutItems + 1] = { kind = "header", frame = header }
		end
		for _, member in ipairs(group.members) do
			if db.players[member.pid] then
				cardIndex = cardIndex + 1
				local card = cardPool[cardIndex] or buildCard()
				cardPool[cardIndex] = card
				card.entry = newEntry(member.pid, group.run and group.run.id, member.role)
				card.tagSet = nil
				card.h = CARD_H
				card.details:Hide()
				card:Show()
				section.cards[#section.cards + 1] = card
				layoutItems[#layoutItems + 1] = { kind = "card", frame = card }
			end
		end
		sections[#sections + 1] = section
	end
	for i = cardIndex + 1, #cardPool do
		cardPool[i]:Hide()
	end
	for i = headerIndex + 1, #headerPool do
		headerPool[i]:Hide()
	end

	hasContent = cardIndex > 0
	setEmpty(cardIndex == 0)
	if cardIndex == 0 then
		child:SetHeight(1)
		return 0
	end

	local runs = 0
	for _, section in ipairs(sections) do
		if section.run then
			runs = runs + 1
		end
	end
	if runs > 1 then
		w.title:SetText(L.RATE_HEADLINE_GROUPS:format(runs, cardIndex))
	elseif runs == 1 then
		w.title:SetText(
			cardIndex == 1 and L.RATE_HEADLINE_SINGLE or ns.Locale.Count("RATE_HEADLINE_PLAYERS", cardIndex, cardIndex)
		)
	else
		w.title:SetText(title)
	end
	w.skip:SetShown(runs > 0)
	for _, section in ipairs(sections) do
		for _, card in ipairs(section.cards) do
			paintCard(card)
		end
	end
	updateProgress(false)
	scroll.Reset()
	animateEntrance()
	return cardIndex
end

local function open(groups, title)
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if populate(groups, title) == 0 then
		ns.Print(L.RATE_EMPTY)
		return
	end
	opening = true
	ns.Hub.Show("rate")
	opening = false
end

local function runGroups(runs)
	local groups = {}
	for _, run in ipairs(runs) do
		local members = {}
		for _, member in ipairs(run.members or {}) do
			members[#members + 1] = { pid = member.pid, role = member.role }
		end
		groups[#groups + 1] = { run = run, members = members }
	end
	return groups
end

-- Every group still waiting for a rating, newest first.
local function pendingRuns()
	local runs = {}
	for _, run in ipairs(ns.Runs.List(ns.db)) do
		if run.prompt == "pending" and not ns.Runs.IsCrowd(run) then
			runs[#runs + 1] = run
			if #runs >= PENDING_LIMIT then
				break
			end
		end
	end
	return runs
end

-- Rate the members of several stored runs in one window, newest first.
function RateFrame.OpenRuns(runs)
	open(runGroups(runs), L.RATE_TITLE)
end

-- Rate the members of one stored run. Ratings are tied to the run, so reopening edits them.
function RateFrame.OpenRun(run)
	RateFrame.OpenRuns({ run })
end

-- Rate players outside a run. Each opening starts a new rating; changes in the window edit it.
function RateFrame.OpenPlayers(pids, role)
	local members = {}
	for _, pid in ipairs(pids) do
		members[#members + 1] = { pid = pid, role = role }
	end
	open({ { members = members } }, L.RATE_TITLE_PLAYER)
end

-- Rate the player behind a unit token (from the unit right-click menu).
function RateFrame.OpenUnit(unit)
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	local ident = Compat.UnitIdentity(unit)
	if not ident then
		ns.Print(L.MSG_UNIT_UNKNOWN)
		return
	end
	local pid = ns.Players.Resolve(ns.db, ident, Compat.Now(), Compat.Ruleset())
	RateFrame.OpenPlayers({ pid }, ident.role)
end

-- The visible card for a player (used by the tests and the debug report).
function RateFrame.FindCard(pid)
	for _, card in ipairs(cardPool) do
		if card:IsShown() and card.entry and card.entry.pid == pid then
			return card
		end
	end
	return nil
end

function RateFrame.IsShown()
	return ns.Hub.IsShown("rate")
end

ns.Hub.AddPage("rate", {
	label = L.NAV_RATE,
	title = L.RATE_TITLE,
	build = build,
	show = function()
		local rated, total = countRated()
		if not opening and (not hasContent or rated >= total) then
			populate(runGroups(pendingRuns()), L.RATE_TITLE)
		end
	end,
	hide = leave,
})
