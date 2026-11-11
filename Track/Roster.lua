-- Reads the group roster (debounced, out of combat), keeps player records up to date, adds
-- members to the current run and reports players who are new to this group session.
local _, ns = ...

local Debug = ns.Debug
local Compat = ns.Compat
local Events = ns.Events

local Roster = { retries = 0, partyKey = nil }
ns.Roster = Roster

local MAX_RETRIES = 5

local function scan()
	local db = ns.db
	if not db then
		return
	end
	local now = Compat.Now()

	if not Compat.IsInGroup() then
		if db.session then
			ns.Session.End(db)
			Debug.Log("ROSTER", "group ended, session cleared")
		end
		Roster.retries = 0
		return
	end

	ns.Session.Ensure(db, now, Roster.partyKey)
	local ruleset = Compat.Ruleset()
	local inRun = ns.Runs.IsInside(db)
	local units = Compat.GroupUnits()
	local pids, failed = {}, 0

	for _, unit in ipairs(units) do
		local ident = Compat.UnitIdentity(unit)
		if ident then
			local pid = ns.Players.Resolve(db, ident, now, ruleset)
			pids[#pids + 1] = pid
			if inRun then
				ns.Runs.AddMember(db, pid, ident.role)
			end
		else
			failed = failed + 1
		end
	end

	local fresh = ns.Session.TakeNew(db, pids, now)
	Debug.Log(
		"ROSTER",
		"scan: %d units, %d identified, %d new to session, in run=%s",
		#units,
		#pids,
		#fresh,
		tostring(inRun)
	)

	-- Names can arrive late ("Unknown") or be secret for a moment: look again shortly.
	if failed > 0 and Roster.retries < MAX_RETRIES then
		Roster.retries = Roster.retries + 1
		Events.Debounce("roster", 3, Roster.Request)
	elseif failed == 0 then
		Roster.retries = 0
	end

	if #fresh > 0 and db.settings.toastEnabled and ns.Toast then
		local known = {}
		for _, pid in ipairs(fresh) do
			local rec = db.players[pid]
			if rec and #rec.ratings > 0 then
				known[#known + 1] = pid
			end
		end
		if #known > 0 then
			ns.Toast.ShowJoin(known)
		end
	end
end

-- Scan now, or as soon as combat ends.
function Roster.Request()
	Events.RunOutOfCombat("roster", scan)
end

-- Scan one second after the last roster change.
function Roster.Schedule()
	Events.Debounce("roster", 1, Roster.Request)
end

Events.On("GROUP_ROSTER_UPDATE", "Roster", Roster.Schedule)
Events.On("PLAYER_ENTERING_WORLD", "Roster", Roster.Schedule)

Events.On("GROUP_JOINED", "Roster", function(_, _, partyGUID)
	Roster.partyKey = Compat.Clean(partyGUID, "string")
	Roster.Schedule()
end)

Events.On("GROUP_LEFT", "Roster", function()
	Roster.partyKey = nil
	Roster.Schedule()
end)
