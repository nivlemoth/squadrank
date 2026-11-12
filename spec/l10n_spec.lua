-- Localization: locale selection, fallback to English, placeholder safety, plural forms and
-- the completeness of every shipped catalog. Each case loads the locale files the way the
-- client does, with GetLocale() returning the language under test.
local CODES = { "deDE", "frFR", "esES", "esMX", "ptBR", "itIT", "ruRU", "koKR", "zhCN", "zhTW" }
local PLURAL_FAMILIES = {
	"FMT_RATED_TIMES",
	"FMT_ROLE_RUNS",
	"RATE_HEADLINE_PLAYERS",
	"RUN_PLAYERS",
	"DETAIL_AVG_RATINGS",
	"MINIMAP_PENDING",
	"MSG_LIST",
}

local function run(path, ns)
	local chunk = assert(loadfile(path))
	chunk("SquadRank", ns)
end

-- Loads the locale layer for a client language. extra(ns) runs after English, before the
-- shipped translations (used to register a test catalog).
local function load(clientLocale, extra, skipShipped)
	_G.GetLocale = clientLocale and function()
		return clientLocale
	end or nil
	local ns = {}
	run("Core/Init.lua", ns)
	run("Locales/Locale.lua", ns)
	run("Locales/enUS.lua", ns)
	if extra then
		extra(ns)
	end
	if not skipShipped then
		for _, code in ipairs(CODES) do
			run("Locales/" .. code .. ".lua", ns)
		end
	end
	_G.GetLocale = nil
	return ns
end

local function count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

local function isPluralKey(base, key)
	for _, suffix in ipairs({ "_ONE", "_FEW", "_MANY", "_OTHER" }) do
		if key:sub(-#suffix) == suffix and base[key:sub(1, -#suffix - 1) .. "_OTHER"] then
			return true
		end
	end
	return false
end

describe("localization", function()
	before_each(function()
		SquadRankDB = nil
	end)

	it("lists every shipped locale in the TOC, after English and before any code that uses text", function()
		local order, firstUser = {}, nil
		local i = 0
		for line in io.lines("SquadRank.toc") do
			local path = line:match("^%s*([%w_/\\]+%.lua)%s*$")
			if path then
				i = i + 1
				path = path:gsub("\\", "/")
				order[path] = i
				if not firstUser and not path:match("^Locales/") and path ~= "Core/Init.lua" then
					firstUser = i
				end
			end
		end
		assert.is_not_nil(order["Locales/Locale.lua"])
		assert.is_true(order["Locales/Locale.lua"] < order["Locales/enUS.lua"])
		for _, code in ipairs(CODES) do
			local at = order["Locales/" .. code .. ".lua"]
			assert.is_not_nil(at, code .. " missing from the TOC")
			assert.is_true(at > order["Locales/enUS.lua"] and at < firstUser, code .. " loads too late")
		end
	end)

	it("uses English for enUS, enGB, unknown locales and a missing GetLocale", function()
		for _, client in ipairs({ "enUS", "enGB", "xxXX", "ptPT", false }) do
			local ns = load(client or nil)
			assert.equals("enUS", ns.Locale.code)
			assert.equals(0, count(ns.Locale.active))
			assert.equals("Done", ns.L.BTN_DONE)
		end
	end)

	it("never returns a blank label and survives a missing key", function()
		local ns = load("frFR", function(ns)
			ns.Locale.Register("frFR", function(L)
				L.BTN_DONE = ""
				L.BTN_SKIP = "   "
				L.RATE_PROGRESS = "%d notés"
				L.FMT_NOTE = "|cffff0000Note|r : %s"
				L.NOT_A_REAL_KEY = "x"
				L.NAV_ABOUT = "À propos"
			end)
		end, true)
		local L = ns.L
		assert.equals("Done", L.BTN_DONE)
		assert.equals("Skip all", L.BTN_SKIP)
		assert.equals("%d of %d rated", L.RATE_PROGRESS)
		assert.equals("Note: %s", L.FMT_NOTE)
		assert.equals("À propos", L.NAV_ABOUT)
		assert.equals("Settings", L.NAV_SETTINGS)
		assert.equals("empty", ns.Locale.rejected.BTN_DONE)
		assert.equals("empty", ns.Locale.rejected.BTN_SKIP)
		assert.equals("placeholders differ from English", ns.Locale.rejected.RATE_PROGRESS)
		assert.equals("escape codes differ from English", ns.Locale.rejected.FMT_NOTE)
		assert.equals("unknown key", ns.Locale.rejected.NOT_A_REAL_KEY)
		assert.equals("NO_SUCH_KEY", L.NO_SUCH_KEY)
		assert.is_true(ns.Locale.missing.NO_SUCH_KEY)
	end)

	it("reads the placeholders and escape codes of a string in order", function()
		local Locale = load("enUS").Locale
		assert.same({ "%s", "%.1f", "%d" }, Locale.Placeholders("%s %.1f over %d runs (100%%)"))
		assert.same({ "c", "r" }, Locale.Escapes("|cff33bbffSquadRank|r: a || b"))
	end)

	it("chooses plural forms per language", function()
		local Locale = load("enUS").Locale
		local function forms(code, list)
			local out = {}
			for i, n in ipairs(list) do
				out[i] = Locale.PluralForm(n, code)
			end
			return table.concat(out, " ")
		end
		assert.equals("OTHER ONE OTHER", forms("enUS", { 0, 1, 2 }))
		assert.equals("ONE ONE OTHER", forms("frFR", { 0, 1, 2 }))
		assert.equals("ONE ONE OTHER", forms("ptBR", { 0, 1, 2 }))
		assert.equals("OTHER OTHER", forms("zhCN", { 1, 2 }))
		assert.equals(
			"MANY ONE FEW FEW MANY MANY MANY ONE FEW MANY MANY",
			forms("ruRU", { 0, 1, 2, 4, 5, 11, 12, 21, 22, 25, 111 })
		)
		local ns = load("enUS")
		assert.equals("Bob - New, 1 rating", ns.Locale.Count("MSG_LIST", 1, "Bob", "New", 1))
		assert.equals("Bob - New, 2 ratings", ns.Locale.Count("MSG_LIST", 2, "Bob", "New", 2))
		assert.equals("1 player waiting to be rated", ns.Locale.Count("MINIMAP_PENDING", 1, 1))
	end)

	it("has a working developer override that reads only a valid code", function()
		SquadRankDB = { settings = { devLocale = "ruRU" } }
		local ns = load("enUS")
		assert.equals("ruRU", ns.Locale.code)
		assert.equals("ruRU", ns.Locale.override)
		SquadRankDB = { settings = { devLocale = "../evil" } }
		assert.equals("enUS", load("enUS").Locale.code)
	end)

	for _, code in ipairs(CODES) do
		it(code .. " is complete, valid, and keeps every placeholder", function()
			local ns = load(code)
			local Locale = ns.Locale
			assert.equals(code, Locale.code)
			local rejected = {}
			for key, why in pairs(Locale.rejected) do
				rejected[#rejected + 1] = key .. " (" .. why .. ")"
			end
			table.sort(rejected)
			assert.equals("", table.concat(rejected, ", "))

			local missing = {}
			for key in pairs(Locale.base) do
				if not Locale.NEUTRAL[key] and not isPluralKey(Locale.base, key) and Locale.active[key] == nil then
					missing[#missing + 1] = key
				end
			end
			table.sort(missing)
			assert.equals("", table.concat(missing, ", "))

			for _, family in ipairs(PLURAL_FAMILIES) do
				assert.is_not_nil(Locale.base[family .. "_OTHER"], family)
				for n = 0, 130 do
					local text, source = Locale.Resolve(family, n)
					assert.equals("locale", source, family .. " for " .. n)
					assert.is_true(text:find("%S") ~= nil)
				end
			end

			-- Every translation formats without error using sample arguments.
			for key, text in pairs(Locale.active) do
				local args = {}
				for i, spec in ipairs(Locale.Placeholders(text)) do
					local kind = spec:sub(-1)
					args[i] = (kind == "s") and "x" or 3
				end
				local ok, err = pcall(string.format, text, unpack(args))
				assert.is_true(ok, key .. ": " .. tostring(err))
			end
		end)
	end
end)
