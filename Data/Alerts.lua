-- Rules for contextual heads-ups: a saved player whispers, is targeted, or asks to trade or
-- duel. Pure Lua: time is passed in. The recent-alert table is deliberately in memory only, so
-- no extra player data is written to SavedVariables and reloading resets the cooldown.
local _, ns = ...

local Alerts = { last = {} }
ns.Alerts = Alerts

Alerts.CONTEXTS = { "whisper", "target", "trade", "duel" }

-- Context name -> saved setting. A missing mapping means the context is not configurable.
Alerts.SETTING = {
	whisper = "alertWhisper",
	target = "alertTarget",
	trade = "alertTrade",
	duel = "alertDuel",
}

function Alerts.Reset()
	Alerts.last = {}
end

-- True when the user has switched this kind of heads-up on. Defaults are off.
function Alerts.Enabled(db, context)
	local key = Alerts.SETTING[context]
	return key ~= nil and type(db) == "table" and type(db.settings) == "table" and db.settings[key] == true
end

-- Minutes between two heads-ups about the same player. 0 means no cooldown.
function Alerts.Cooldown(db)
	local value = type(db) == "table" and type(db.settings) == "table" and tonumber(db.settings.alertCooldown) or 60
	return math.max(0, math.min(180, math.floor(value)))
end

-- The one saved player a name refers to, or nil when the name is unknown or ambiguous.
-- Never creates a record.
function Alerts.ResolveName(db, name)
	if type(db) ~= "table" or type(db.players) ~= "table" then
		return nil
	end
	if type(name) ~= "string" or not name:find("%S") then
		return nil
	end
	local found = ns.Players.Find(db, name)
	if #found == 1 then
		return found[1]
	end
	return nil
end

-- True when this player may produce a heads-up now; records the moment when it returns true.
-- Players on the avoid list bypass the per-context switch (the avoid warning has its own
-- setting) but still obey the cooldown. An unrated player who is not avoided never alerts.
function Alerts.ShouldAlert(db, pid, context, now)
	if type(db) ~= "table" or type(db.players) ~= "table" or type(pid) ~= "string" then
		return false
	end
	local rec = db.players[pid]
	if type(rec) ~= "table" then
		return false
	end

	local avoided = rec.avoid == true and type(db.settings) == "table" and db.settings.avoidWarning == true
	local rated = type(rec.ratings) == "table" and #rec.ratings > 0
	if not avoided and not rated then
		return false
	end
	if not avoided and not Alerts.Enabled(db, context) then
		return false
	end

	local previous = Alerts.last[pid]
	if previous and now - previous < Alerts.Cooldown(db) * 60 then
		return false
	end

	Alerts.last[pid] = now
	return true
end
