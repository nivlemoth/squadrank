-- Ratings, tags and the reputation summary. Pure Lua: time is passed in.
local _, ns = ...

local Util = ns.Util

local Ratings = {}
ns.Ratings = Ratings

-- Order matters: it is the display order and the tie-break for "top tags".
Ratings.TAGS = {
	{ id = "role_good", positive = true },
	{ id = "communicator", positive = true },
	{ id = "helpful", positive = true },
	{ id = "efficient", positive = true },
	{ id = "fair_loot", positive = true },
	{ id = "stayed", positive = true },
	{ id = "knows_dungeon", positive = true },
	{ id = "role_bad", positive = false },
	{ id = "ninja", positive = false },
	{ id = "left_early", positive = false },
	{ id = "afk", positive = false },
	{ id = "toxic", positive = false },
	{ id = "reckless", positive = false },
	{ id = "ignores_mechanics", positive = false },
}

Ratings.TAG_INFO = {}
for order, tag in ipairs(Ratings.TAGS) do
	Ratings.TAG_INFO[tag.id] = { order = order, positive = tag.positive }
end

Ratings.ROLES = { "tank", "healer", "dps" }
Ratings.ROLE_SET = { tank = true, healer = true, dps = true }

Ratings.HALF_LIFE_DAYS = 90
Ratings.TRUSTED_AT = 4.0
Ratings.CAUTION_AT = 2.5
Ratings.NOTE_MAX = 140

-- Returns a cleaned copy of user input, or nil and the name of the bad field.
function Ratings.Validate(input)
	if type(input) ~= "table" then
		return nil, "input"
	end
	local score = tonumber(input.score)
	if not score or score ~= math.floor(score) or score < 1 or score > 5 then
		return nil, "score"
	end
	if not Ratings.ROLE_SET[input.role] then
		return nil, "role"
	end
	local tags, seen = {}, {}
	if type(input.tags) == "table" then
		for _, id in ipairs(input.tags) do
			if Ratings.TAG_INFO[id] and not seen[id] then
				seen[id] = true
				tags[#tags + 1] = id
			end
		end
	end
	table.sort(tags, function(a, b)
		return Ratings.TAG_INFO[a].order < Ratings.TAG_INFO[b].order
	end)
	return {
		score = score,
		role = input.role,
		tags = tags,
		note = Util.Sanitize(input.note, Ratings.NOTE_MAX),
		runId = type(input.runId) == "string" and input.runId or nil,
	}
end

-- Adds a rating, or updates the existing one when input.id matches or the player already
-- has a rating for input.runId. Returns the stored rating, or nil and an error name.
function Ratings.Save(db, pid, input, now)
	local rec = db.players[pid]
	if not rec then
		return nil, "player"
	end
	local clean, err = Ratings.Validate(input)
	if not clean then
		return nil, err
	end

	local target
	for _, rating in ipairs(rec.ratings) do
		if (input.id and rating.id == input.id) or (clean.runId and rating.runId == clean.runId) then
			target = rating
			break
		end
	end

	if target then
		target.updatedAt = now
		target.imported = nil
	else
		target = { id = ns.DB.NextId(db, "r"), createdAt = now, updatedAt = now }
		rec.ratings[#rec.ratings + 1] = target
		while #rec.ratings > ns.DB.LIMITS.ratingsPerPlayer do
			table.remove(rec.ratings, 1)
		end
	end
	target.score = clean.score
	target.role = clean.role
	target.tags = clean.tags
	target.note = clean.note
	target.runId = clean.runId or target.runId
	return target
end

function Ratings.Delete(db, pid, ratingId)
	local rec = db.players[pid]
	if not rec then
		return false
	end
	for i, rating in ipairs(rec.ratings) do
		if rating.id == ratingId then
			table.remove(rec.ratings, i)
			return true
		end
	end
	return false
end

function Ratings.ForRun(rec, runId)
	if type(rec) == "table" and runId then
		for _, rating in ipairs(rec.ratings) do
			if rating.runId == runId then
				return rating
			end
		end
	end
	return nil
end

-- Everything the UI shows about a player:
-- { count, label = "new"|"trusted"|"mixed"|"caution", weighted, roles = { role = { avg, count } },
--   topTags = { { id, count } ... }, lastNote, lastRole, lastRatedAt }
function Ratings.Summary(rec, now, minRatings)
	local list = type(rec) == "table" and rec.ratings or {}
	local summary = { count = #list, label = "new", roles = {}, topTags = {} }
	local weightedSum, weightTotal = 0, 0
	local tagCounts = {}
	local latest, latestNote

	for _, rating in ipairs(list) do
		local score = tonumber(rating.score) or 3
		local ageDays = math.max(0, now - (rating.createdAt or now)) / 86400
		local weight = 0.5 ^ (ageDays / Ratings.HALF_LIFE_DAYS)
		weightedSum = weightedSum + score * weight
		weightTotal = weightTotal + weight

		if Ratings.ROLE_SET[rating.role] then
			local role = summary.roles[rating.role] or { sum = 0, count = 0 }
			role.sum = role.sum + score
			role.count = role.count + 1
			summary.roles[rating.role] = role
		end
		if type(rating.tags) == "table" then
			for _, id in ipairs(rating.tags) do
				if Ratings.TAG_INFO[id] then
					tagCounts[id] = (tagCounts[id] or 0) + 1
				end
			end
		end
		local at = rating.updatedAt or rating.createdAt or 0
		if not latest or at >= (latest.updatedAt or latest.createdAt or 0) then
			latest = rating
		end
		if type(rating.note) == "string" and rating.note ~= "" then
			if not latestNote or at >= (latestNote.updatedAt or latestNote.createdAt or 0) then
				latestNote = rating
			end
		end
	end

	for _, role in pairs(summary.roles) do
		role.avg = role.sum / role.count
		role.sum = nil
	end
	for id, count in pairs(tagCounts) do
		summary.topTags[#summary.topTags + 1] = { id = id, count = count }
	end
	table.sort(summary.topTags, function(a, b)
		if a.count ~= b.count then
			return a.count > b.count
		end
		return Ratings.TAG_INFO[a.id].order < Ratings.TAG_INFO[b.id].order
	end)

	if weightTotal > 0 then
		summary.weighted = weightedSum / weightTotal
		if summary.count >= (minRatings or 3) then
			if summary.weighted >= Ratings.TRUSTED_AT then
				summary.label = "trusted"
			elseif summary.weighted <= Ratings.CAUTION_AT then
				summary.label = "caution"
			else
				summary.label = "mixed"
			end
		end
	end
	if latest then
		summary.lastRole = latest.role
		summary.lastRatedAt = latest.updatedAt or latest.createdAt
	end
	if latestNote then
		summary.lastNote = latestNote.note
	end
	return summary
end
