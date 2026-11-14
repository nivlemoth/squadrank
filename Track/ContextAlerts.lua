-- Context alerts: a quiet heads-up when a saved player whispers, is targeted, or asks to
-- trade or duel. The database is read only out of combat. The whisper text is deliberately
-- ignored: it is never read, logged or stored.
local _, ns = ...

local Debug = ns.Debug
local Compat = ns.Compat
local Events = ns.Events

local ContextAlerts = {}
ns.ContextAlerts = ContextAlerts

local function notify(pid, context)
	local db = ns.db
	if not db or not ns.Alerts.ShouldAlert(db, pid, context, Compat.Now()) then
		return
	end
	-- Counts and fixed words only: no player name, ID or message text in the report.
	Debug.Log("ALERT", "context %s", context)
	if ns.Toast then
		ns.Toast.ShowContext(pid, context)
	end
end

local function queueName(name, context)
	if type(name) ~= "string" or not name:find("%S") then
		return
	end
	Events.RunOutOfCombat("context:" .. context .. ":" .. name, function()
		local db = ns.db
		if not db then
			return
		end
		local pid = ns.Alerts.ResolveName(db, name)
		if pid then
			notify(pid, context)
		end
	end)
end

local function queueIdentity(ident, context)
	if type(ident) ~= "table" then
		return
	end
	local key = tostring(ident.guid or ident.name)
	Events.RunOutOfCombat("context:" .. context .. ":" .. key, function()
		local db = ns.db
		if not db then
			return
		end
		local pid = ns.Players.Lookup(db, ident)
		if pid then
			notify(pid, context)
		end
	end)
end

-- Exposed for the smoke test and for future contexts that already have a unit token.
function ContextAlerts.Target(unit)
	local ident = Compat.UnitIdentity(unit or "target")
	if ident then
		queueIdentity(ident, "target")
	end
end

-- CHAT_MSG_WHISPER's first argument is the message; it is not touched.
Events.On("CHAT_MSG_WHISPER", "ContextAlerts", function(_, _, sender)
	queueName(Compat.Clean(sender, "string"), "whisper")
end)

Events.On("PLAYER_TARGET_CHANGED", "ContextAlerts", function()
	ContextAlerts.Target("target")
end)

-- The same two events the observed competitor uses for incoming requests.
Events.On("TRADE_REQUEST", "ContextAlerts", function(_, name)
	queueName(Compat.Clean(name, "string"), "trade")
end)

Events.On("DUEL_REQUESTED", "ContextAlerts", function(_, name)
	queueName(Compat.Clean(name, "string"), "duel")
end)
