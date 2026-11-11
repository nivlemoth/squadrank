-- The rating form: a member list on the left, and for the selected player a 1-5 score,
-- role, one-click tag buttons and an optional note. Used for a whole run ("Rate your squad")
-- and for single players (unit menu, /sr rate <name>, main window).
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Util = ns.Util
local Compat = ns.Compat
local Debug = ns.Debug

local RateFrame = {}
ns.RateFrame = RateFrame

local frame, list
local w = {}
local state = { entries = {}, index = 0, run = nil }
local form = { tags = {} }

local function isRated(entry)
	if entry.runId then
		return ns.Ratings.ForRun(ns.db.players[entry.pid], entry.runId) ~= nil
	end
	return entry.rated == true
end

local function loadForm()
	local entry = state.entries[state.index]
	form.id, form.score, form.role, form.note = nil, nil, nil, ""
	form.tags = {}
	if not entry then
		return
	end
	local rec = ns.db.players[entry.pid]
	local existing = entry.runId and ns.Ratings.ForRun(rec, entry.runId) or nil
	if existing then
		form.id = existing.id
		form.score = existing.score
		form.role = existing.role
		form.note = existing.note or ""
		for _, id in ipairs(existing.tags or {}) do
			form.tags[id] = true
		end
	end
	if not form.role then
		local summary = ns.Ratings.Summary(rec, Compat.Now(), ns.db.settings.minRatings)
		form.role = entry.role or summary.lastRole or "dps"
	end
end

local function refresh()
	local db = ns.db
	local entry = state.entries[state.index]
	local rec = entry and db.players[entry.pid]

	w.name:SetText(rec and UI.ColoredName(rec) or L.RATE_EMPTY)
	if state.run then
		local name = Util.Escape(state.run.instanceName or L.UNKNOWN_INSTANCE)
		w.context:SetText(L.RATE_RUN_FMT:format(name, UI.Date(state.run.endedAt or state.run.startedAt)))
	else
		w.context:SetText(L.RATE_NO_RUN)
	end
	for score, button in ipairs(w.scores) do
		UI.SetChosen(button, form.score == score)
	end
	for role, button in pairs(w.roles) do
		UI.SetChosen(button, form.role == role)
	end
	for id, button in pairs(w.tags) do
		UI.SetChosen(button, form.tags[id] == true)
	end
	w.note:SetText(form.note or "")
	w.dismiss:SetShown(state.run ~= nil and state.run.prompt == "pending")

	local items = {}
	for i, item in ipairs(state.entries) do
		items[i] = { index = i, pid = item.pid, rated = isRated(item), selected = i == state.index }
	end
	list:SetData(items)
end

local function selectEntry(index)
	state.index = index
	loadForm()
	refresh()
end

local function save()
	local db = ns.db
	local entry = state.entries[state.index]
	if not entry or not db.players[entry.pid] then
		return
	end
	if ns.readOnly then
		ns.Print(L.MSG_READONLY:format(tostring(ns.readOnlyReason)))
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if not form.score then
		ns.Print(L.RATE_NEED_SCORE)
		return
	end

	local tags = {}
	for id, on in pairs(form.tags) do
		if on then
			tags[#tags + 1] = id
		end
	end
	local rating, err = ns.Ratings.Save(db, entry.pid, {
		id = form.id,
		score = form.score,
		role = form.role,
		tags = tags,
		note = w.note:GetText(),
		runId = entry.runId,
	}, Compat.Now())
	if not rating then
		ns.Print(L.RATE_FAILED:format(tostring(err)))
		return
	end

	entry.rated = true
	Debug.Log("RATE", "saved: hash %d, score %d, %d tags", Util.Hash(entry.pid), rating.score, #rating.tags)
	ns.Print(L.RATE_SAVED:format(ns.Players.DisplayName(db.players[entry.pid])))

	local run = state.run
	if run and db.runs[run.id] and ns.Runs.RatedCount(db, run) >= #run.members then
		ns.Runs.SetPrompt(db, run.id, "done")
	end
	ns.Slash.RefreshWindows()

	-- Move on to the next player who has no rating yet; close when everyone is done.
	local count = #state.entries
	for step = 1, count do
		local index = (state.index + step - 1) % count + 1
		if not isRated(state.entries[index]) then
			selectEntry(index)
			return
		end
	end
	frame:Hide()
end

local function buildRow(row)
	row.text = UI.Text(row, "GameFontHighlightSmall")
	row.text:SetPoint("LEFT", 4, 0)
	row.text:SetPoint("RIGHT", -4, 0)
	row.text:SetWordWrap(false)
	row:SetScript(
		"OnClick",
		ns.Safe("rate row", function(self)
			if self.srItem then
				selectEntry(self.srItem.index)
			end
		end)
	)
end

local function fillRow(row, item)
	row.srItem = item
	local text = UI.ColoredName(ns.db.players[item.pid])
	if item.selected then
		text = "|cffffd100>|r " .. text
	end
	if item.rated then
		text = text .. " |cff808080" .. L.RATE_DONE_MARK .. "|r"
	end
	row.text:SetText(text)
end

local function build()
	frame = UI.CreateWindow(620, 440, L.RATE_TITLE)
	local content = frame.content

	local left = CreateFrame("Frame", nil, content)
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(180)
	list = UI.CreateList(left, 22, buildRow, fillRow)

	local right = CreateFrame("Frame", nil, content)
	right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
	right:SetPoint("BOTTOMRIGHT")

	local function label(text, y)
		local fs = UI.Text(right, "GameFontNormalSmall")
		fs:SetPoint("TOPLEFT", 0, y)
		fs:SetText(text)
		return fs
	end

	w.name = UI.Text(right, "GameFontNormalLarge")
	w.name:SetPoint("TOPLEFT", 0, 0)
	w.context = UI.Text(right, "GameFontHighlightSmall")
	w.context:SetPoint("TOPLEFT", 0, -22)

	label(L.RATE_SCORE, -46)
	w.scores = {}
	for score = 1, 5 do
		local button = UI.Button(right, tostring(score), 36, 22, function()
			form.score = score
			form.note = w.note:GetText()
			refresh()
		end)
		button:SetPoint("TOPLEFT", (score - 1) * 40, -60)
		w.scores[score] = button
	end

	label(L.RATE_ROLE, -92)
	w.roles = {}
	for i, role in ipairs(ns.Ratings.ROLES) do
		local button = UI.Button(right, L["ROLE_" .. role], 80, 22, function()
			form.role = role
			form.note = w.note:GetText()
			refresh()
		end)
		button:SetPoint("TOPLEFT", (i - 1) * 84, -106)
		w.roles[role] = button
	end

	label(L.RATE_TAGS, -138)
	w.tags = {}
	local positiveRow, negativeRow = 0, 0
	for _, tag in ipairs(ns.Ratings.TAGS) do
		local button = UI.Button(right, L["TAG_" .. tag.id], 196, 20, function()
			form.tags[tag.id] = not form.tags[tag.id] or nil
			form.note = w.note:GetText()
			refresh()
		end)
		if tag.positive then
			button:SetPoint("TOPLEFT", 0, -154 - positiveRow * 22)
			positiveRow = positiveRow + 1
		else
			button:SetPoint("TOPLEFT", 202, -154 - negativeRow * 22)
			negativeRow = negativeRow + 1
		end
		w.tags[tag.id] = button
	end

	label(L.RATE_NOTE, -314)
	w.note = CreateFrame("EditBox", nil, right, "InputBoxTemplate")
	w.note:SetSize(390, 22)
	w.note:SetPoint("TOPLEFT", 6, -330)
	w.note:SetAutoFocus(false)
	w.note:SetMaxLetters(ns.Ratings.NOTE_MAX)
	w.note:SetScript("OnEnterPressed", w.note.ClearFocus)
	w.note:SetScript("OnEscapePressed", w.note.ClearFocus)

	local saveButton = UI.Button(right, L.BTN_SAVE, 110, 24, save)
	saveButton:SetPoint("BOTTOMLEFT", 0, 2)

	w.dismiss = UI.Button(right, L.BTN_DISMISS_RUN, 120, 24, function()
		if state.run and ns.db.runs[state.run.id] and not ns.readOnly then
			ns.Runs.SetPrompt(ns.db, state.run.id, "skipped")
			ns.Slash.RefreshWindows()
		end
		frame:Hide()
	end)
	w.dismiss:SetPoint("BOTTOMRIGHT", 0, 2)
end

local function open(entries, run)
	if #entries == 0 then
		ns.Print(L.RATE_EMPTY)
		return
	end
	if not frame then
		build()
	end
	state.entries, state.run = entries, run
	local first = 1
	for i, entry in ipairs(entries) do
		if not isRated(entry) then
			first = i
			break
		end
	end
	frame:Show()
	selectEntry(first)
end

-- Rate the members of a stored run. Ratings are tied to the run, so reopening edits them.
function RateFrame.OpenRun(run)
	local entries = {}
	for _, member in ipairs(run.members or {}) do
		if ns.db.players[member.pid] then
			entries[#entries + 1] = { pid = member.pid, runId = run.id, role = member.role }
		end
	end
	open(entries, run)
end

-- Rate players outside a run. Each save adds a new rating.
function RateFrame.OpenPlayers(pids, role)
	local entries = {}
	for _, pid in ipairs(pids) do
		if ns.db.players[pid] then
			entries[#entries + 1] = { pid = pid, role = role }
		end
	end
	open(entries, nil)
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
