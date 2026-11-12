-- The Stats page: totals over every recorded group, who you group with most, who you rated
-- highest, the avoid list, and groups by type. Names are clickable and open the history drawer.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Compat = ns.Compat

local C = UI.C
local TILE_W, CARD_W, CARD_H, LINE_H = 147, 196, 172, 22
local BAR_MAX = 360
local LIST_ROWS = 6

local w = {}

local function tile(page, index, label, color)
	local f = CreateFrame("Frame", nil, page)
	f:SetSize(TILE_W, 52)
	f:SetPoint("TOPLEFT", (index - 1) * (TILE_W + 8), 0)
	UI.Fill(f, C.card)
	local accent = f:CreateTexture(nil, "ARTWORK")
	accent:SetPoint("TOPLEFT")
	accent:SetPoint("BOTTOMLEFT")
	accent:SetWidth(2)
	UI.SetColor(accent, color)
	f.value = UI.Text(f, "GameFontHighlightHuge")
	f.value:SetPoint("TOPLEFT", 12, -8)
	f.label = UI.Text(f, "GameFontDisableSmall")
	f.label:SetPoint("BOTTOMLEFT", 12, 8)
	f.label:SetWidth(TILE_W - 18)
	f.label:SetWordWrap(false)
	f.label:SetText(label)
	f:EnableMouse(true)
	UI.TruncationTooltip(f, f.label)
	return f
end

local function card(page, index, title, color)
	local f = CreateFrame("Frame", nil, page)
	f:SetSize(CARD_W, CARD_H)
	f:SetPoint("TOPLEFT", (index - 1) * (CARD_W + 12), -66)
	UI.Fill(f, C.card)
	local top = f:CreateTexture(nil, "ARTWORK")
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(2)
	UI.SetColor(top, color)
	local head = UI.Text(f, "GameFontNormalSmall")
	head:SetPoint("TOPLEFT", 10, -10)
	head:SetWidth(CARD_W - 20)
	head:SetWordWrap(false)
	head:SetText(UI.Caps(title))
	head:SetTextColor(color[1], color[2], color[3])
	f.lines = {}
	for i = 1, LIST_ROWS do
		local line = CreateFrame("Button", nil, f)
		line:SetSize(CARD_W - 12, LINE_H)
		line:SetPoint("TOPLEFT", 6, -28 - (i - 1) * LINE_H)
		local hover = line:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(1, 1, 1, 0.06)
		line.name = UI.Text(line, "GameFontHighlightSmall")
		line.name:SetPoint("LEFT", 4, 0)
		line.name:SetWidth(CARD_W - 76)
		line.name:SetWordWrap(false)
		line.value = UI.Text(line, "GameFontHighlightSmall", "RIGHT")
		line.value:SetPoint("RIGHT", -4, 0)
		line:SetScript(
			"OnClick",
			ns.Safe("stats line", function(self)
				if self.pid then
					ns.PlayerDetail.Open(self.pid)
				end
			end)
		)
		f.lines[i] = line
	end
	f.empty = UI.Text(f, "GameFontDisableSmall")
	f.empty:SetPoint("TOPLEFT", 10, -32)
	f.empty:SetWidth(CARD_W - 20)
	f.empty:SetText(L.STATS_EMPTY)
	return f
end

-- entries = { { pid, value }, ... }; extra = how many more are not shown.
local function fill(list, entries, extra)
	local db = ns.db
	for i, line in ipairs(list.lines) do
		local entry = entries[i]
		local rec = entry and db.players[entry.pid]
		if rec and not (extra and extra > 0 and i == LIST_ROWS) then
			line.pid = entry.pid
			line.name:SetText(UI.ColoredName(rec))
			line.value:SetText(entry.value or "")
			line:Show()
		elseif extra and extra > 0 and i == LIST_ROWS then
			line.pid = nil
			line.name:SetText("|cff9aa0aa" .. L.FMT_MORE:format(extra + 1) .. "|r")
			line.value:SetText("")
			line:Show()
		else
			line.pid = nil
			line:Hide()
		end
	end
	list.empty:SetShown(#entries == 0)
end

local function build(page)
	w.tiles = {
		tile(page, 1, L.STATS_GROUPS, C.accent),
		tile(page, 2, L.STATS_HOURS, C.gold),
		tile(page, 3, L.STATS_BOSSES, UI.CATEGORY_COLORS.raid),
		tile(page, 4, L.STATS_QUESTS, C.good),
	}
	w.grouped = card(page, 1, L.STATS_TOP_GROUPED, C.accent)
	w.rated = card(page, 2, L.STATS_TOP_RATED, C.good)
	w.avoided = card(page, 3, L.STATS_AVOIDED, C.bad)

	local head = UI.Text(page, "GameFontNormalSmall")
	head:SetPoint("TOPLEFT", 2, -252)
	head:SetText(UI.Caps(L.STATS_BY_TYPE))
	head:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
	w.bars = {}
	for i, category in ipairs(ns.Runs.CATEGORIES) do
		local y = -272 - (i - 1) * 24
		local bar = {}
		bar.label = UI.Text(page, "GameFontHighlightSmall")
		bar.label:SetPoint("TOPLEFT", 4, y - 4)
		bar.label:SetWidth(150)
		bar.label:SetWordWrap(false)
		bar.label:SetText(L["CAT_" .. category])
		local track = page:CreateTexture(nil, "ARTWORK")
		track:SetPoint("TOPLEFT", 160, y - 6)
		track:SetSize(BAR_MAX, 8)
		track:SetColorTexture(1, 1, 1, 0.06)
		bar.fill = page:CreateTexture(nil, "ARTWORK", nil, 1)
		bar.fill:SetPoint("TOPLEFT", track, "TOPLEFT")
		bar.fill:SetHeight(8)
		bar.fill:SetWidth(1)
		UI.SetColor(bar.fill, UI.CATEGORY_COLORS[category])
		bar.count = UI.Text(page, "GameFontHighlightSmall", "RIGHT")
		bar.count:SetPoint("TOPLEFT", 160 + BAR_MAX + 8, y - 4)
		bar.count:SetWidth(50)
		bar.category = category
		w.bars[i] = bar
	end
end

local function show()
	local db = ns.db
	if not db or Compat.InCombat() then
		return
	end
	local stats = ns.Stats.Compute(db, Compat.Now(), db.settings.minRatings)
	w.tiles[1].value:SetText(tostring(stats.groups))
	w.tiles[2].value:SetText(("%.1f"):format(stats.seconds / 3600))
	w.tiles[3].value:SetText(tostring(stats.bosses))
	w.tiles[4].value:SetText(tostring(stats.quests))

	local grouped = {}
	for i, entry in ipairs(stats.topGrouped) do
		grouped[i] = { pid = entry.pid, value = ns.Locale.Count("STATS_GROUPED", entry.count, entry.count) }
	end
	fill(w.grouped, grouped)
	local rated = {}
	for i, entry in ipairs(stats.topRated) do
		rated[i] = { pid = entry.pid, value = UI.Colorize(("%.1f"):format(entry.avg), UI.ScoreColor(entry.avg)) }
	end
	fill(w.rated, rated)
	local avoided = {}
	for i, pid in ipairs(stats.avoided) do
		avoided[i] = { pid = pid }
	end
	fill(w.avoided, avoided, #avoided - LIST_ROWS)

	local most = 1
	for _, bar in ipairs(w.bars) do
		most = math.max(most, stats.byType[bar.category] or 0)
	end
	for _, bar in ipairs(w.bars) do
		local n = stats.byType[bar.category] or 0
		bar.count:SetText(tostring(n))
		bar.target = n > 0 and math.max(2, BAR_MAX * n / most) or 1
	end
	Anim.Tween("stats bars", 0.45, function(p)
		for _, bar in ipairs(w.bars) do
			bar.fill:SetWidth(math.max(1, bar.target * p))
		end
	end)
end

ns.Hub.AddPage("stats", {
	label = L.NAV_STATS,
	title = L.STATS_TITLE,
	build = build,
	show = show,
})
