-- The current group session: who has already been announced, so each player is toasted
-- at most once per group. Saved in the database so /reload does not repeat toasts.
-- Pure Lua: time is passed in.
local _, ns = ...

local Session = {}
ns.Session = Session

Session.MAX_AGE = 12 * 3600

function Session.Begin(db, now, key)
	db.session = { key = key, startedAt = now, seen = {} }
	return db.session
end

-- Returns the live session, starting a new one when there is none, it is too old, or the
-- group key (the party GUID, when known) changed.
function Session.Ensure(db, now, key)
	local session = db.session
	if
		type(session) ~= "table"
		or type(session.seen) ~= "table"
		or now - (session.startedAt or 0) > Session.MAX_AGE
		or (key and session.key and session.key ~= key)
	then
		return Session.Begin(db, now, key)
	end
	if key and not session.key then
		session.key = key
	end
	return session
end

function Session.End(db)
	db.session = nil
end

-- Marks the given pids as seen and returns the ones that were new to this session.
function Session.TakeNew(db, pids, now)
	local session = Session.Ensure(db, now)
	local fresh = {}
	for _, pid in ipairs(pids) do
		if not session.seen[pid] then
			session.seen[pid] = true
			fresh[#fresh + 1] = pid
		end
	end
	return fresh
end
