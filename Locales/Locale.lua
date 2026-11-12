-- Localization engine. English (Locales/enUS.lua) is the complete, authoritative catalog in
-- Locale.base. Each other locale file calls Locale.Register(code, fill); only the file that
-- matches the client language (GetLocale) actually runs its fill function, and every string it
-- sets is checked against English before use. ns.L reads: translation -> English -> the key.
--
-- Rules enforced on every translation (a failing string is dropped, so English shows instead):
--   * the key must exist in English (plural forms: the family's _OTHER key must exist)
--   * the value must be a non-blank string
--   * printf placeholders (%s, %d, %.1f, ...) must match English exactly, in the same order
--   * WoW escape sequences (|c |r |T |t |H |h |n) must match English, in the same order
-- See docs/LOCALIZATION.md.
local _, ns = ...

local Locale = {}
ns.Locale = Locale

-- Client locales SquadRank ships a catalog for. enGB clients use the English catalog.
Locale.SUPPORTED = {
	enUS = true,
	deDE = true,
	frFR = true,
	esES = true,
	esMX = true,
	ptBR = true,
	itIT = true,
	ruRU = true,
	koKR = true,
	zhCN = true,
	zhTW = true,
}
local ALIASES = { enGB = "enUS" }

-- Keys that are never translated (product name, author, layout-only formats).
Locale.NEUTRAL = {
	ADDON = true,
	AUTHOR = true,
	MSG_PREFIX = true,
	RUN_RATED_SHORT = true,
	DETAIL_SCORE_FMT = true,
	RATE_RUN_FMT = true,
}

local base = {}
local active = {}
Locale.base = base
Locale.active = active
Locale.rejected = {}
Locale.missing = {}
Locale.registered = {}

local function clientLocale()
	local ok, code = pcall(GetLocale)
	if ok and type(code) == "string" and code:match("^%a%a%a%a$") then
		return code
	end
	return nil
end

-- Developer-only: "/sr debug locale deDE" stores a code here and asks for a /reload.
-- SavedVariables are loaded before the addon's files (LoadSavedVariablesFirst in the TOC).
local function developerOverride()
	local db = SquadRankDB
	local settings = type(db) == "table" and type(db.settings) == "table" and db.settings or nil
	local code = settings and settings.devLocale
	if type(code) == "string" and code:match("^%a%a%a%a$") then
		return code
	end
	return nil
end

Locale.client = clientLocale() or "enUS"
Locale.override = developerOverride()
Locale.requested = Locale.override or Locale.client
do
	local code = ALIASES[Locale.requested] or Locale.requested
	Locale.code = Locale.SUPPORTED[code] and code or "enUS"
end

-- The printf conversions in a string, in order, e.g. { "%s", "%.1f", "%d" }. "%%" is skipped.
function Locale.Placeholders(text)
	local list = {}
	local stripped = tostring(text):gsub("%%%%", "")
	for spec in stripped:gmatch("%%[%-%+ #0]*%d*%.?%d*%a") do
		list[#list + 1] = spec
	end
	return list
end

-- The WoW escape letters in a string, in order (|c, |r, |T, |t, |H, |h, |n). "||" is skipped.
function Locale.Escapes(text)
	local list = {}
	local stripped = tostring(text):gsub("||", "")
	for letter in stripped:gmatch("|(%a)") do
		list[#list + 1] = letter
	end
	return list
end

local function sameList(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- The English string a key is checked against: itself, or for a plural form
-- (KEY_ONE, KEY_FEW, KEY_MANY) the family's KEY_OTHER.
local function reference(key)
	if base[key] ~= nil or type(key) ~= "string" then
		return base[key]
	end
	for _, suffix in ipairs({ "_ONE", "_FEW", "_MANY" }) do
		if key:sub(-#suffix) == suffix then
			return base[key:sub(1, -#suffix - 1) .. "_OTHER"]
		end
	end
	return nil
end

-- Returns true, or false and the reason a translation cannot be used.
function Locale.Check(key, value)
	local english = reference(key)
	if english == nil then
		return false, "unknown key"
	end
	if type(value) ~= "string" or not value:find("%S") then
		return false, "empty"
	end
	if not sameList(Locale.Placeholders(value), Locale.Placeholders(english)) then
		return false, "placeholders differ from English"
	end
	if not sameList(Locale.Escapes(value), Locale.Escapes(english)) then
		return false, "escape codes differ from English"
	end
	return true
end

-- Called by each Locales/<code>.lua. fill(T) sets T.KEY = "translation".
function Locale.Register(code, fill)
	Locale.registered[code] = true
	if code ~= Locale.code or code == "enUS" then
		return
	end
	local strings = {}
	local ok, err = pcall(fill, strings)
	if not ok then
		Locale.rejected["(file)"] = tostring(err)
	end
	for key, value in pairs(strings) do
		local good, why = Locale.Check(key, value)
		if good then
			active[key] = value
		else
			Locale.rejected[key] = why
		end
	end
end

local function lookup(key)
	local value = active[key]
	if value ~= nil then
		return value
	end
	return base[key]
end

ns.L = setmetatable({}, {
	__index = function(_, key)
		local value = lookup(key)
		if value ~= nil then
			return value
		end
		-- A missing key never breaks the UI: the key itself shows, and it is logged once.
		if not Locale.missing[key] then
			Locale.missing[key] = true
			if ns.Debug and ns.Debug.Log then
				ns.Debug.Log("LOCALE", "missing key %s", tostring(key))
			end
		end
		return tostring(key)
	end,
})

-- Plural categories (CLDR cardinal rules, integers only).
local function slavic(n)
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then
		return "ONE"
	elseif m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14) then
		return "FEW"
	end
	return "MANY"
end
local function zeroOrOne(n)
	return (n == 0 or n == 1) and "ONE" or "OTHER"
end
local function none()
	return "OTHER"
end
local RULES = {
	ruRU = slavic,
	frFR = zeroOrOne,
	ptBR = zeroOrOne,
	koKR = none,
	zhCN = none,
	zhTW = none,
}
local function english(n)
	return n == 1 and "ONE" or "OTHER"
end

function Locale.PluralForm(n, code)
	n = math.abs(math.floor(tonumber(n) or 0))
	return (RULES[code or Locale.code] or english)(n)
end

-- Formats a plural family: KEY_ONE / KEY_FEW / KEY_MANY / KEY_OTHER chosen for n, then
-- string.format(text, ...). Falls back to the locale's _OTHER, then to English.
-- Returns the text for a plural family and count, and where it came from ("locale" or "english").
function Locale.Resolve(family, n)
	local form = Locale.PluralForm(n)
	local text = active[family .. "_" .. form] or active[family .. "_OTHER"] or active[family .. "_MANY"]
	if text then
		return text, "locale"
	end
	text = base[family .. "_" .. english(math.abs(math.floor(tonumber(n) or 0)))] or base[family .. "_OTHER"]
	if text then
		return text, "english"
	end
	return nil
end

function Locale.Count(family, n, ...)
	local text = Locale.Resolve(family, n)
	if not text then
		return ns.L[family .. "_OTHER"]
	end
	return text:format(...)
end

-- Counts for the debug report (no strings, no player data).
function Locale.Summary()
	local translated, rejected, missing = 0, 0, 0
	for _ in pairs(active) do
		translated = translated + 1
	end
	for _ in pairs(Locale.rejected) do
		rejected = rejected + 1
	end
	for _ in pairs(Locale.missing) do
		missing = missing + 1
	end
	return ("client %s, using %s%s; %d translated, %d rejected, %d missing keys"):format(
		Locale.client,
		Locale.code,
		Locale.override and (" (developer override " .. Locale.override .. ")") or "",
		translated,
		rejected,
		missing
	)
end
