-- Schema migrations. steps[n] upgrades a database from schema n to n + 1, in place.
-- Pure Lua: time is passed in.
local _, ns = ...

local Util = ns.Util

local Migrations = { steps = {} }
ns.Migrations = Migrations

local LEGACY_SCORE = { GOOD = 5, OK = 3, BAD = 1 }

-- Schema 0 is legacy SquadRank 1.x: no schema field, players keyed "Realm-Name-Faction",
-- a GOOD/OK/BAD lastRank, and squadHistory keyed by date.
Migrations.steps[0] = function(db, now)
	local oldPlayers = type(db.players) == "table" and db.players or {}
	local oldSquads = type(db.squadHistory) == "table" and db.squadHistory or {}
	local oldSettings = type(db.settings) == "table" and db.settings or {}

	local players, runs, keyMap = {}, {}, {}
	local nextId = 1

	for key, p in pairs(oldPlayers) do
		if type(p) == "table" and type(p.name) == "string" then
			local name = Util.Sanitize(p.name, 48)
			if name ~= "" and name ~= "Unknown" and name ~= UNKNOWNOBJECT then
				local suffix = Util.Sanitize(p.realm, 48)
				if suffix == "" or suffix == "Unknown" or suffix == UNKNOWNOBJECT then
					suffix = nil
				end
				local pid = Util.NameKey(name, suffix)
				local seen = Util.ParseLegacyDate(p.lastGrouped) or now
				local rec = players[pid]
				if not rec then
					local faction = type(key) == "string" and key:match("%-(%a+)$") or nil
					if faction ~= "Alliance" and faction ~= "Horde" then
						faction = nil
					end
					rec = {
						name = name,
						suffix = suffix,
						classFile = (type(p.class) == "string" and p.class ~= "UNKNOWN") and p.class or nil,
						faction = faction,
						firstSeen = seen,
						lastSeen = seen,
						rulesets = {},
						ratings = {},
					}
					players[pid] = rec
				end
				local score = LEGACY_SCORE[p.lastRank]
				if score and #rec.ratings == 0 then
					rec.ratings[1] = {
						id = "r" .. nextId,
						createdAt = seen,
						updatedAt = seen,
						score = score,
						tags = {},
						note = "",
						imported = true,
					}
					nextId = nextId + 1
				end
				keyMap[key] = pid
			end
		end
	end

	for _, squad in pairs(oldSquads) do
		if type(squad) == "table" then
			local members = {}
			if type(squad.players) == "table" then
				for key in pairs(squad.players) do
					if keyMap[key] then
						members[#members + 1] = { pid = keyMap[key] }
					end
				end
			end
			if #members > 0 then
				local at = Util.ParseLegacyDate(squad.date) or now
				local id = "run" .. nextId
				nextId = nextId + 1
				runs[id] = {
					id = id,
					instanceName = Util.Sanitize(squad.location, 64),
					instanceType = type(squad.type) == "string" and squad.type or nil,
					startedAt = at,
					endedAt = at,
					groupSize = #members + 1,
					members = members,
					prompt = "done",
					imported = true,
				}
			end
		end
	end

	for k in pairs(db) do
		db[k] = nil
	end
	db.nextId = nextId
	db.settings = { toastEnabled = oldSettings.showToast ~= false }
	db.players = players
	db.runs = runs
end

local function hasData(db)
	return (type(db.players) == "table" and next(db.players) ~= nil)
		or (type(db.runs) == "table" and next(db.runs) ~= nil)
		or (type(db.squadHistory) == "table" and next(db.squadHistory) ~= nil)
end

-- Upgrades db in place from schema `from` to schema `to`. A copy of the original is kept
-- in db.backup. On failure the original content is restored and false, err is returned.
function Migrations.Run(db, from, to, now)
	db.backup = nil
	local original = Util.DeepCopy(db)
	local keepBackup = hasData(db)

	local ok, err = pcall(function()
		for version = from, to - 1 do
			local step = Migrations.steps[version]
			if not step then
				error("no migration from schema " .. version)
			end
			step(db, now)
			db.schema = version + 1
		end
	end)

	if not ok then
		for k in pairs(db) do
			db[k] = nil
		end
		for k, v in pairs(original) do
			db[k] = v
		end
		return false, err
	end

	if keepBackup then
		db.backup = { schema = from, at = now, data = original }
	end
	return true
end
