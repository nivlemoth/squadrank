local helper = dofile("spec/helper.lua")
local NOW = helper.NOW

describe("Debug", function()
	local ns, Debug

	before_each(function()
		issecretvalue = nil
		ns = helper.load()
		Debug = ns.Debug
	end)

	it("keeps only the last 200 log lines", function()
		for i = 1, 250 do
			Debug.Log("T", "line %d", i)
		end
		assert.equals(200, #Debug.lines)
		assert.is_not_nil(Debug.lines[200]:find("line 250", 1, true))
		assert.is_not_nil(Debug.lines[1]:find("line 51", 1, true))
	end)

	it("captures errors from wrapped handlers without raising", function()
		local handler = ns.Safe("test", function()
			error("kaboom")
		end)
		handler()
		assert.equals(1, Debug.errorCount)
		assert.is_not_nil(Debug.errors[1]:find("kaboom", 1, true))
	end)

	it("returns results from ns.Try and nil on error", function()
		assert.equals(
			5,
			ns.Try("ok", function(a, b)
				return a + b
			end, 2, 3)
		)
		assert.is_nil(ns.Try("bad", function()
			error("x")
		end))
	end)

	it("drops secret arguments instead of formatting them", function()
		local secret = {}
		issecretvalue = function(v)
			return v == secret
		end
		Debug.Log("T", "value %s", secret)
		assert.is_not_nil(Debug.lines[1]:find("secret argument dropped", 1, true))
		issecretvalue = nil
	end)

	it("builds a report with counts but no player names or notes", function()
		local db = ns.DB.Open(nil, NOW)
		ns.db = db
		ns.Players.BuildIndex(db)
		local pid = ns.Players.Resolve(db, { name = "Zzyzxname", suffix = "Qqsuffix", guid = "Player-9-ABCDEF" }, NOW)
		ns.Ratings.Save(db, pid, { score = 1, role = "dps", note = "privatenotetext" }, NOW)
		Debug.Log("ROSTER", "scan: %d members, pid hash %d", 1, ns.Util.Hash(pid))

		local text = Debug.ReportText()
		assert.is_not_nil(text:find("players: 1 (rated: 1), ratings: 1", 1, true))
		assert.is_nil(text:find("Zzyzxname", 1, true))
		assert.is_nil(text:find("Qqsuffix", 1, true))
		assert.is_nil(text:find("ABCDEF", 1, true))
		assert.is_nil(text:find("privatenotetext", 1, true))
	end)

	it("mirrors the report into the SquadRankDebug saved variable", function()
		ns.db = ns.DB.Open(nil, NOW)
		Debug.Mirror()
		assert.equals(ns.VERSION, SquadRankDebug.version)
		assert.equals("SquadRank debug report", SquadRankDebug.report[1])
	end)
end)
