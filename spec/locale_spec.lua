local helper = dofile("spec/helper.lua")

-- Reads the TOC to get the list of source files, so this check covers every file the game loads.
local function tocFiles()
	local files = {}
	for line in io.lines("SquadRank.toc") do
		local path = line:match("^%s*([%w_/\\]+%.lua)%s*$")
		if path then
			files[#files + 1] = (path:gsub("\\", "/"))
		end
	end
	return files
end

describe("locale table", function()
	local ns

	before_each(function()
		ns = helper.load()
	end)

	it("defines every L.KEY used in the source files", function()
		local missing = {}
		local files = tocFiles()
		assert.is_true(#files >= 26)
		for _, path in ipairs(files) do
			local handle = assert(io.open(path, "r"), "TOC lists a missing file: " .. path)
			local source = handle:read("*a")
			handle:close()
			if not path:match("^Locales/") then
				for key in source:gmatch("L%.([%u][%w_]+)") do
					if ns.Locale.base[key] == nil then
						missing[#missing + 1] = path .. ": " .. key
					end
				end
				for family in source:gmatch('Locale%.Count%(%s*"([%u_]+)"') do
					if ns.Locale.base[family .. "_OTHER"] == nil then
						missing[#missing + 1] = path .. ": " .. family .. "_OTHER"
					end
				end
			end
		end
		assert.equals("", table.concat(missing, ", "))
	end)

	it("has a label for every tag, role and reputation label", function()
		for _, tag in ipairs(ns.Ratings.TAGS) do
			assert.is_not_nil(ns.Locale.base["TAG_" .. tag.id])
		end
		for _, role in ipairs(ns.Ratings.ROLES) do
			assert.is_not_nil(ns.Locale.base["ROLE_" .. role])
		end
		for _, label in ipairs({ "new", "trusted", "mixed", "caution" }) do
			assert.is_not_nil(ns.Locale.base["LABEL_" .. label])
		end
	end)

	it("has exactly eight positive and eight negative tags", function()
		local positive, negative = 0, 0
		for _, tag in ipairs(ns.Ratings.TAGS) do
			if tag.positive then
				positive = positive + 1
			else
				negative = negative + 1
			end
		end
		assert.equals(8, positive)
		assert.equals(8, negative)
	end)
end)
