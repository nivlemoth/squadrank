-- Minimal test runner for machines without busted (busted needs a C compiler to install).
-- Implements the small subset of the busted API the specs use, so the same spec files
-- also run under real busted. Usage, from the addon folder: luajit spec/run.lua
-- Kept local because the smoke test replaces the global print with a recorder.
local print = print

local SPECS = {
	"spec/util_spec.lua",
	"spec/db_spec.lua",
	"spec/players_spec.lua",
	"spec/alerts_spec.lua",
	"spec/ratings_spec.lua",
	"spec/runs_spec.lua",
	"spec/debug_spec.lua",
	"spec/locale_spec.lua",
	"spec/l10n_spec.lua",
	"spec/smoke_spec.lua",
}

local passed, failed = 0, 0
local stack = {}

local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function fail(message)
	error(message, 3)
end

local check = {}
function check.equals(expected, actual)
	if expected ~= actual then
		fail("expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
end
function check.same(expected, actual)
	if not same(expected, actual) then
		fail("tables differ")
	end
end
function check.is_true(v)
	if v ~= true then
		fail("expected true, got " .. tostring(v))
	end
end
function check.is_false(v)
	if v ~= false then
		fail("expected false, got " .. tostring(v))
	end
end
function check.is_nil(v)
	if v ~= nil then
		fail("expected nil, got " .. tostring(v))
	end
end
function check.is_not_nil(v)
	if v == nil then
		fail("expected a value, got nil")
	end
end

_G.assert = setmetatable(check, {
	__call = function(_, v, message)
		if not v then
			error(message or "assertion failed", 2)
		end
		return v
	end,
})

function _G.describe(name, body)
	stack[#stack + 1] = { name = name, before = {} }
	body()
	stack[#stack] = nil
end

function _G.before_each(fn)
	local level = stack[#stack]
	level.before[#level.before + 1] = fn
end

function _G.it(name, body)
	local names = {}
	for _, level in ipairs(stack) do
		names[#names + 1] = level.name
	end
	names[#names + 1] = name
	local ok, err = pcall(function()
		for _, level in ipairs(stack) do
			for _, fn in ipairs(level.before) do
				fn()
			end
		end
		body()
	end)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL " .. table.concat(names, " / ") .. "\n     " .. tostring(err))
	end
end

for _, path in ipairs(SPECS) do
	local chunk, err = loadfile(path)
	if not chunk then
		failed = failed + 1
		print("FAIL could not load " .. path .. ": " .. tostring(err))
	else
		local ok, runErr = pcall(chunk)
		if not ok then
			failed = failed + 1
			print("FAIL " .. path .. " crashed: " .. tostring(runErr))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
