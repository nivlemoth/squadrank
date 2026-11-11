-- /sr selftest: exercises every API that docs/api-verified.md lists as unverified, plus the
-- Blizzard UI pieces the addon builds on. Results hold types, counts and yes/no only:
-- never a name, GUID or any other identity.
local _, ns = ...

local L = ns.L
local Util = ns.Util
local Debug = ns.Debug
local Compat = ns.Compat

local SelfTest = {}
ns.SelfTest = SelfTest

local PASS, FAIL, INFO = "PASS", "FAIL", "INFO"

local function yn(v)
	return v and "yes" or "no"
end

local function exists(path)
	local value = _G
	for part in path:gmatch("[^%.]+") do
		if type(value) ~= "table" then
			return false
		end
		value = value[part]
	end
	return value ~= nil
end

local checks = {}
local function check(name, fn)
	checks[#checks + 1] = { name = name, fn = fn }
end

-- Unverified globals (not in Blizzard's generated API docs).
for _, name in ipairs({ "IsInGroup", "IsInRaid" }) do
	check("global " .. name .. "() returns a boolean", function()
		local fn = _G[name]
		if type(fn) ~= "function" then
			return FAIL, "missing; fallback in Compat is used"
		end
		local value = fn()
		return type(value) == "boolean" and PASS or FAIL, "returned " .. type(value)
	end)
end
for _, name in ipairs({ "GetNumGroupMembers", "GetNumSubgroupMembers" }) do
	check("global " .. name .. "() returns a number", function()
		local fn = _G[name]
		if type(fn) ~= "function" then
			return FAIL, "missing; fallback in Compat is used"
		end
		local value = fn()
		return type(value) == "number" and PASS or FAIL, "returned " .. type(value) .. " " .. tostring(value)
	end)
end

check("issecretvalue exists", function()
	if type(issecretvalue) ~= "function" then
		return FAIL, "missing; values are treated as never secret"
	end
	return issecretvalue("plain") == false and PASS or FAIL, "plain string reported as not secret"
end)

check("own identity can be read", function()
	local ident, reason = Compat.UnitIdentity("player")
	if not ident then
		return FAIL, "reason: " .. tostring(reason)
	end
	return PASS,
		("guid=%s class=%s level=%s faction=%s role=%s"):format(
			yn(ident.guid),
			yn(ident.classFile),
			yn(ident.level),
			yn(ident.faction),
			tostring(ident.role)
		)
end)

check("UnitName second value (realm or surname)", function()
	local _, suffix = UnitName("player")
	if Compat.IsSecret(suffix) then
		return INFO, "secret"
	end
	local kind = type(suffix)
	if kind == "string" then
		return INFO, ("string of %d characters, spaces=%s"):format(#suffix, yn(suffix:find(" ", 1, true)))
	end
	return INFO, kind
end)

check("group members can be identified", function()
	if not Compat.IsInGroup() then
		return INFO, "not in a group: run this again in a party"
	end
	local units = Compat.GroupUnits()
	local okCount, withGuid, reasons = 0, 0, {}
	for _, unit in ipairs(units) do
		local ident, reason = Compat.UnitIdentity(unit)
		if ident then
			okCount = okCount + 1
			if ident.guid then
				withGuid = withGuid + 1
			end
		else
			reasons[reason] = (reasons[reason] or 0) + 1
		end
	end
	local detail = ("%d units, %d identified, %d with GUID"):format(#units, okCount, withGuid)
	for reason, n in pairs(reasons) do
		detail = detail .. (", %d %s"):format(n, reason)
	end
	return (#units > 0 and okCount == #units and withGuid == okCount) and PASS or FAIL, detail
end)

check("group member values are not secret", function()
	if not Compat.IsInGroup() then
		return INFO, "not in a group"
	end
	local unit = Compat.GroupUnits()[1]
	if not unit then
		return INFO, "no other member found"
	end
	local name, suffix = UnitName(unit)
	local guid = UnitGUID(unit)
	local _, classFile = UnitClass(unit)
	local secrets = {
		name = Compat.IsSecret(name),
		suffix = Compat.IsSecret(suffix),
		guid = Compat.IsSecret(guid),
		class = Compat.IsSecret(classFile),
	}
	local any = secrets.name or secrets.suffix or secrets.guid or secrets.class
	return any and FAIL or PASS,
		("secret: name=%s suffix=%s guid=%s class=%s; in combat=%s"):format(
			yn(secrets.name),
			yn(secrets.suffix),
			yn(secrets.guid),
			yn(secrets.class),
			yn(Compat.InCombat())
		)
end)

check("instance detection", function()
	local state = Compat.InstanceState()
	return INFO,
		("inInstance=%s type=%s instanceID=%s maxPlayers=%s inGroup=%s"):format(
			yn(state.inInstance),
			tostring(state.instanceType),
			tostring(state.instanceID),
			tostring(state.maxPlayers),
			yn(state.inGroup)
		)
end)

check("addon restriction states", function()
	if not (C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive) then
		return FAIL, "C_RestrictedActions.IsAddOnRestrictionActive missing"
	end
	local parts = {}
	for i = 0, 5 do
		local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, i)
		parts[#parts + 1] = i .. "=" .. (ok and tostring(active) or "error")
	end
	return INFO, table.concat(parts, " ") .. " (0 combat, 1 encounter, 2 challenge, 3 pvp, 4 map, 5 chat)"
end)

check("ruleset detection", function()
	local hardcoreApi = C_GameRules ~= nil and C_GameRules.IsHardcoreActive ~= nil
	return INFO, ("tag='%s', hardcore API present=%s"):format(Compat.Ruleset(), yn(hardcoreApi))
end)

check("C_RecentAllies (optional)", function()
	if not C_RecentAllies then
		return INFO, "API absent; integration stays off"
	end
	local parts = {}
	for _, name in ipairs({ "IsSystemSupported", "IsSystemEnabled", "IsRecentAllyDataReady" }) do
		if C_RecentAllies[name] then
			local ok, value = pcall(C_RecentAllies[name])
			parts[#parts + 1] = name .. "=" .. (ok and tostring(value) or "error")
		else
			parts[#parts + 1] = name .. "=missing"
		end
	end
	return INFO, table.concat(parts, " ")
end)

check("events seen this session", function()
	local names = {
		"PLAYER_ENTERING_WORLD",
		"ZONE_CHANGED_NEW_AREA",
		"GROUP_ROSTER_UPDATE",
		"GROUP_JOINED",
		"GROUP_LEFT",
		"ENCOUNTER_START",
		"ENCOUNTER_END",
		"BOSS_KILL",
		"ADDON_RESTRICTION_STATE_CHANGED",
	}
	local parts = {}
	for _, name in ipairs(names) do
		parts[#parts + 1] = name .. "=" .. (ns.Events.counts[name] or 0)
	end
	return INFO, table.concat(parts, " ")
end)

for _, path in ipairs({
	"Menu.ModifyMenu",
	"MenuUtil.CreateContextMenu",
	"Settings.RegisterVerticalLayoutCategory",
	"Settings.RegisterAddOnSetting",
	"Settings.CreateCheckbox",
	"Settings.CreateSlider",
	"CreateSettingsButtonInitializer",
	"CreateScrollBoxListLinearView",
	"ScrollUtil.InitScrollBoxListWithScrollBar",
	"CreateDataProvider",
	"C_ClassColor.GetClassColor",
	"C_Timer.After",
	"StaticPopup_Show",
	"ButtonFrameTemplate_HidePortrait",
	"GetServerTime",
}) do
	check("Blizzard API " .. path, function()
		return exists(path) and PASS or FAIL, ""
	end)
end

check("C_StringUtil.StripHyperlinks (not relied on)", function()
	return INFO, "present=" .. yn(exists("C_StringUtil.StripHyperlinks"))
end)

check("unit menu entry registered", function()
	local note = Debug.notes.unitMenu
	return (note and note:find("^ok")) and PASS or FAIL, tostring(note)
end)

check("settings panel registered", function()
	local note = Debug.notes.settings
	return (note and note:find("^ok")) and PASS or FAIL, tostring(note)
end)

check("text sanitizer", function()
	local out = Util.Sanitize("|cffff0000x|r|TInterface\\Icons\\y:16|t|Hitem:1|h[z]|h")
	return out == "x[z]" and PASS or FAIL, "got '" .. out .. "'"
end)

check("database is writable", function()
	if ns.readOnly then
		return FAIL, "read-only: " .. tostring(ns.readOnlyReason)
	end
	if SquadRankDB ~= ns.db then
		return FAIL, "SquadRankDB is not the live table"
	end
	return PASS, "schema " .. tostring(ns.db.schema)
end)

-- Runs every check. Returns the result table that is also stored for the debug report.
function SelfTest.Run()
	local results = { results = {}, pass = 0, fail = 0, info = 0, at = date("%Y-%m-%d %H:%M:%S") }
	for _, item in ipairs(checks) do
		local ok, status, detail = pcall(item.fn)
		if not ok then
			status, detail = FAIL, "error: " .. (Compat.IsSecret(status) and "<secret>" or tostring(status))
		end
		if Compat.IsSecret(detail) then
			detail = "<secret>"
		end
		results.results[#results.results + 1] = { name = item.name, status = status, detail = detail or "" }
		if status == PASS then
			results.pass = results.pass + 1
		elseif status == FAIL then
			results.fail = results.fail + 1
		else
			results.info = results.info + 1
		end
	end
	Debug.selftest = results
	Debug.Log("SELFTEST", "%d pass, %d fail, %d info", results.pass, results.fail, results.info)
	Debug.Mirror()
	ns.Print(L.MSG_SELFTEST:format(results.pass, results.fail, results.info))
	return results
end
