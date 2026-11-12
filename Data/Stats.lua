-- Personal statistics for the Stats page, computed from saved runs and ratings.
-- Pure Lua: reads the database, writes nothing.
local _, ns = ...

local Stats = {}
ns.Stats = Stats

Stats.TOP = 5
-- A player needs this many ratings to appear under "Highest rated" (one great run is luck).
Stats.MIN_RATINGS_FOR_TOP = 2

-- Returns {
--   groups, seconds, bosses, quests, wipes,      totals over stored runs
--   byType = { [category] = count },
--   topGrouped = { { pid, count }, ... },         most groups shared, most first
--   topRated = { { pid, avg, count }, ... },      best weighted average, best first
--   avoided = { pid, ... },                       the avoid list, by name
-- }
function Stats.Compute(db, now, minRatings)
	local result = {
		groups = 0,
		seconds = 0,
		bosses = 0,
		quests = 0,
		wipes = 0,
		byType = {},
		topGrouped = {},
		topRated = {},
		avoided = {},
	}
	local shared = {}
	for _, run in pairs(db.runs) do
		result.groups = result.groups + 1
		if run.startedAt and run.endedAt and run.endedAt > run.startedAt then
			result.seconds = result.seconds + (run.endedAt - run.startedAt)
		end
		result.bosses = result.bosses + (run.bossKills or 0)
		result.wipes = result.wipes + (run.wipes or 0)
		result.quests = result.quests + (ns.Runs.QuestCounts(run))
		local category = ns.Runs.Category(run)
		result.byType[category] = (result.byType[category] or 0) + 1
		-- A 40-player raid is not "grouping with" 39 people: crowds don't count here.
		if not ns.Runs.IsCrowd(run) then
			for _, member in ipairs(run.members or {}) do
				if db.players[member.pid] then
					shared[member.pid] = (shared[member.pid] or 0) + 1
				end
			end
		end
	end

	local function name(pid)
		return ns.Players.DisplayName(db.players[pid]):lower()
	end

	for pid, count in pairs(shared) do
		result.topGrouped[#result.topGrouped + 1] = { pid = pid, count = count }
	end
	table.sort(result.topGrouped, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return name(a.pid) < name(b.pid)
	end)

	for pid, rec in pairs(db.players) do
		if rec.avoid then
			result.avoided[#result.avoided + 1] = pid
		end
		if #rec.ratings >= Stats.MIN_RATINGS_FOR_TOP then
			local summary = ns.Ratings.Summary(rec, now, minRatings)
			if summary.weighted then
				result.topRated[#result.topRated + 1] = { pid = pid, avg = summary.weighted, count = summary.count }
			end
		end
	end
	table.sort(result.topRated, function(a, b)
		if a.avg ~= b.avg then
			return a.avg > b.avg
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return name(a.pid) < name(b.pid)
	end)
	table.sort(result.avoided, function(a, b)
		return name(a) < name(b)
	end)

	for _, key in ipairs({ "topGrouped", "topRated" }) do
		for i = #result[key], Stats.TOP + 1, -1 do
			result[key][i] = nil
		end
	end
	return result
end
