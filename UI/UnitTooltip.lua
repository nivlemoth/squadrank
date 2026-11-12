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

-- Returns the line and its colour for a unit, or nil.
function UnitTooltip.Line(unit)
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
	local rec = pid and db.players[pid]
	if not rec then
		return nil
	end
	if rec.avoid then
		return L.TOOLTIP_AVOID, UI.C.bad
	end
	local summary = ns.Ratings.Summary(rec, Compat.Now(), db.settings.minRatings)
	if summary.count == 0 or not summary.weighted then
		return nil
	end
	local text =
		ns.Locale.Count("TOOLTIP_RATED", summary.count, L["LABEL_" .. summary.label], summary.weighted, summary.count)
	return text, UI.ScoreColor(summary.weighted)
end

local function onUnitTooltip(tooltip)
	if tooltip ~= GameTooltip then
		return
	end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	if not ok then
		return
	end
	local text, color = UnitTooltip.Line(unit)
	if text then
		tooltip:AddLine(text, color[1], color[2], color[3])
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
