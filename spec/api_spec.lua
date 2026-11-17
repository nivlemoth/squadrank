-- Guards the privacy and combat rules: SquadRank must never call the aura, threat or combat-log
-- APIs. The names are assembled from pieces so this scanner does not flag its own source.
local BANNED = {
	"C_Unit" .. "Auras",
	"Unit" .. "Aura",
	"Unit" .. "Buff",
	"Unit" .. "Debuff",
	"UnitDetailed" .. "ThreatSituation",
	"UnitCasting" .. "Info",
	"C_Combat" .. "Log",
	"CombatLog" .. "GetCurrentEventInfo",
	"COMBAT_LOG_" .. "EVENT",
	"COMBAT_LOG_" .. "EVENT_UNFILTERED",
}

local function read(path)
	local file = assert(io.open(path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local function tocFiles()
	local list = {}
	for line in io.lines("SquadRank.toc") do
		local path = line:match("^%s*([%w_/\\]+%.lua)%s*$")
		if path then
			list[#list + 1] = (path:gsub("\\", "/"))
		end
	end
	return list
end

local function specFiles()
	local separator = package.config:sub(1, 1)
	local command = separator == "\\" and "dir /b spec\\*.lua" or "ls spec/*.lua"
	local pipe = assert(io.popen(command, "r"))
	local list = {}
	for line in pipe:lines() do
		line = line:gsub("\r$", "")
		if line ~= "" then
			list[#list + 1] = "spec/" .. line:match("([^/\\]+)$")
		end
	end
	pipe:close()
	return list
end

local function violations(path)
	local found = {}
	local lineNumber = 0
	for line in (read(path) .. "\n"):gmatch("(.-)\n") do
		lineNumber = lineNumber + 1
		for _, token in ipairs(BANNED) do
			if line:find(token, 1, true) then
				found[#found + 1] = ("%s:%d uses %s"):format(path, lineNumber, token)
			end
		end
	end
	return found
end

describe("banned combat APIs", function()
	it("are not referenced by addon or test files", function()
		local files, seen = {}, {}
		for _, list in ipairs({ tocFiles(), specFiles() }) do
			for _, path in ipairs(list) do
				if not seen[path] then
					seen[path] = true
					files[#files + 1] = path
				end
			end
		end
		assert.is_true(#files > 10)
		local bad = {}
		for _, path in ipairs(files) do
			for _, entry in ipairs(violations(path)) do
				bad[#bad + 1] = entry
			end
		end
		assert.equals("", table.concat(bad, "\n"))
	end)
end)
