-- History window for one player: reputation summary and every rating, newest first.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Util = ns.Util
local Compat = ns.Compat

local PlayerDetail = {}
ns.PlayerDetail = PlayerDetail

local frame, body, child
local currentPid

local function buildText(rec)
	local db = ns.db
	local summary = ns.Ratings.Summary(rec, Compat.Now(), db.settings.minRatings)
	local lines = { UI.ColoredName(rec) .. "   " .. UI.LabelText(summary.label) }

	if rec.classFile then
		lines[#lines + 1] =
			L.DETAIL_CLASS_LEVEL:format(tostring(rec.level or "?"), Util.Escape(UI.ClassName(rec.classFile)))
	end
	lines[#lines + 1] = L.DETAIL_SEEN:format(UI.Date(rec.firstSeen), UI.Date(rec.lastSeen))
	local rulesets = {}
	for tag in pairs(rec.rulesets or {}) do
		rulesets[#rulesets + 1] = Util.Escape(tostring(tag))
	end
	if #rulesets > 0 then
		table.sort(rulesets)
		lines[#lines + 1] = L.DETAIL_RULESETS:format(table.concat(rulesets, ", "))
	end
	for _, line in ipairs(UI.SummaryLines(summary)) do
		lines[#lines + 1] = line
	end
	lines[#lines + 1] = " "

	if #rec.ratings == 0 then
		lines[#lines + 1] = L.DETAIL_NO_RATINGS
	end
	for i = #rec.ratings, 1, -1 do
		local rating = rec.ratings[i]
		local role = ns.Ratings.ROLE_SET[rating.role] and L["ROLE_" .. rating.role] or "-"
		local head = L.DETAIL_RATING_FMT:format(UI.Date(rating.createdAt), tonumber(rating.score) or 0, role)
		lines[#lines + 1] = "|cffffd100" .. head .. "|r"
		local run = rating.runId and db.runs[rating.runId]
		if run and run.instanceName then
			lines[#lines + 1] = "   " .. Util.Escape(run.instanceName)
		end
		local tags = {}
		for _, id in ipairs(rating.tags or {}) do
			if ns.Ratings.TAG_INFO[id] then
				tags[#tags + 1] = id
			end
		end
		if #tags > 0 then
			lines[#lines + 1] = "   " .. UI.TagNames(tags)
		end
		local note = Util.Sanitize(rating.note)
		if note ~= "" then
			lines[#lines + 1] = "   " .. L.FMT_NOTE:format(note)
		end
		if rating.imported then
			lines[#lines + 1] = "   " .. L.DETAIL_IMPORTED
		end
	end
	return table.concat(lines, "\n")
end

local function build()
	frame = UI.CreateWindow(460, 440, L.DETAIL_TITLE)
	local content = frame.content

	local rate = UI.Button(content, L.BTN_RATE, 90, 22, function()
		if currentPid and not Compat.InCombat() then
			ns.RateFrame.OpenPlayers({ currentPid })
		end
	end)
	rate:SetPoint("TOPLEFT", 0, 0)
	local purge = UI.Button(content, L.BTN_PURGE, 90, 22, function()
		if currentPid then
			ns.Slash.ConfirmPurgePlayer(currentPid)
		end
	end)
	purge:SetPoint("LEFT", rate, "RIGHT", 6, 0)

	local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -30)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)
	child = CreateFrame("Frame", nil, scroll)
	child:SetSize(400, 10)
	scroll:SetScrollChild(child)

	body = UI.Text(child, "GameFontHighlightSmall")
	body:SetPoint("TOPLEFT", 4, -2)
	body:SetWidth(392)
	body:SetWordWrap(true)
	body:SetSpacing(3)
end

function PlayerDetail.Refresh()
	if not frame or not frame:IsShown() then
		return
	end
	local rec = currentPid and ns.db.players[currentPid]
	if not rec then
		frame:Hide()
		return
	end
	if Compat.InCombat() then
		return
	end
	body:SetText(buildText(rec))
	child:SetHeight(math.max(10, body:GetStringHeight() + 8))
end

function PlayerDetail.Open(pid)
	if not ns.db or not ns.db.players[pid] then
		return
	end
	if Compat.InCombat() then
		ns.Print(L.MSG_COMBAT)
		return
	end
	if not frame then
		build()
	end
	currentPid = pid
	frame:Show()
	PlayerDetail.Refresh()
end
