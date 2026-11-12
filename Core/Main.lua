-- Startup and shutdown. Loaded last, after every module has defined itself.
local _, ns = ...

local L = ns.L
local Debug = ns.Debug
local Compat = ns.Compat
local Events = ns.Events

local function optional(moduleName, method)
	local module = ns[moduleName]
	if module and module[method] then
		ns.Try(moduleName .. "." .. method, module[method])
	end
end

Events.On("ADDON_LOADED", "Main", function(_, name)
	if name ~= ns.ADDON then
		return
	end
	local now = Compat.Now()
	local db, info = ns.DB.Open(SquadRankDB, now)
	ns.readOnly = info.readOnly
	ns.readOnlyReason = info.reason
	if not info.readOnly then
		SquadRankDB = db
	end
	ns.db = db
	ns.Players.BuildIndex(db)

	Debug.Log(
		"INIT",
		"version %s, schema %s, created=%s, migratedFrom=%s, readOnly=%s",
		ns.VERSION,
		tostring(db.schema),
		tostring(info.created),
		tostring(info.migratedFrom),
		tostring(info.readOnly)
	)
	if info.pruned then
		Debug.Log(
			"INIT",
			"pruned %d runs, %d ratings, %d players",
			info.pruned.runs,
			info.pruned.ratings,
			info.pruned.players
		)
	end

	optional("SettingsUI", "Register")
	optional("UnitMenu", "Register")
end)

Events.On("PLAYER_LOGIN", "Main", function()
	if ns.readOnly then
		ns.Print(L.MSG_READONLY:format(tostring(ns.readOnlyReason)))
	end
	optional("MinimapButton", "Update")
end)

Events.On("PLAYER_LOGOUT", "Main", function()
	Debug.Mirror()
end)

Events.On("SAVED_VARIABLES_TOO_LARGE", "Main", function(_, name)
	if name == ns.ADDON then
		Debug.Log("WARN", "SAVED_VARIABLES_TOO_LARGE fired for this addon")
		ns.Print(L.MSG_TOO_LARGE)
	end
end)

Events.On("ADDON_RESTRICTION_STATE_CHANGED", "Main", function(_, kind, state)
	Debug.Log("RESTRICT", "type %s state %s", tostring(kind), tostring(state))
end)

-- Counted for the self-test only; nothing depends on these firing.
Events.On("ENCOUNTER_START", "Main", function() end)
Events.On("BOSS_KILL", "Main", function() end)
