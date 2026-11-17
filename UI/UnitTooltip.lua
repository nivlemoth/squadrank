-- One SquadRank line in player tooltips: a red warning for the avoid list, otherwise the
-- reputation and average score of a player you have rated. Out of combat only (the database is
-- not read in combat), never for players without ratings, never creates a record.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Compat = ns.Compat
local Debug = ns.Debug

local UnitTooltip = {}
ns.UnitTooltip = UnitTooltip

-- The saved record for a unit, if it can be read out of combat. Never creates a record.
local function record(unit)
	local db = ns.db
	if not db or not db.settings.tooltipInfo or Compat.InCombat() or type(unit) ~= "string" then
		return nil
	end
	local ok, isOther = pcall(function()
		return UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
	end)
	if not (ok and isOther) then
		return nil
	end
	local pid = ns.Players.Lookup(db, (Compat.UnitIdentity(unit)))
	return pid and db.players[pid] or nil
end

-- Returns the line and its colour for a unit, or nil.
function UnitTooltip.Line(unit)
	local rec = record(unit)
	if not rec then
		return nil
	end
	if rec.avoid then
		return L.TOOLTIP_AVOID, UI.C.bad
	end
	local summary = ns.Ratings.Summary(rec, Compat.Now(), ns.db.settings.minRatings)
	if summary.count == 0 or not summary.weighted then
		return nil
	end
	local text =
		ns.Locale.Count("TOOLTIP_RATED", summary.count, L["LABEL_" .. summary.label], summary.weighted, summary.count)
	return text, UI.ScoreColor(summary.weighted)
end

-- Every tooltip line for a unit: the overall reputation, then one line per role with history.
function UnitTooltip.Lines(unit)
	local rec = record(unit)
	if not rec then
		return nil
	end
	if rec.avoid then
		return { { text = L.TOOLTIP_AVOID, color = UI.C.bad } }
	end
	local summary = ns.Ratings.Summary(rec, Compat.Now(), ns.db.settings.minRatings)
	if summary.count == 0 or not summary.weighted then
		return nil
	end
	local lines = {
		{
			text = ns.Locale.Count(
				"TOOLTIP_RATED",
				summary.count,
				L["LABEL_" .. summary.label],
				summary.weighted,
				summary.count
			),
			color = UI.ScoreColor(summary.weighted),
		},
	}
	for _, text in ipairs(UI.RoleLines(summary)) do
		lines[#lines + 1] = { text = text, color = UI.C.muted }
	end
	return lines
end

local function onUnitTooltip(tooltip)
	if tooltip ~= GameTooltip then
		return
	end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	if not ok then
		return
	end
	local lines = UnitTooltip.Lines(unit)
	if lines then
		for _, line in ipairs(lines) do
			tooltip:AddLine(line.text, line.color[1], line.color[2], line.color[3])
		end
	end
end

function UnitTooltip.Register()
	local processor = _G.TooltipDataProcessor
	local types = _G.Enum and _G.Enum.TooltipDataType
	if not (processor and processor.AddTooltipPostCall and types and types.Unit) then
		Debug.notes.tooltip = "TooltipDataProcessor missing"
		return
	end
	local ok = pcall(processor.AddTooltipPostCall, types.Unit, ns.Safe("unit tooltip", onUnitTooltip))
	Debug.notes.tooltip = ok and "ok" or "AddTooltipPostCall failed"
end
