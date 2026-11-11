-- Every WoW API that is unverified at runtime, or that can return a secret value, is called
-- through this file. Nothing here returns a secret value: a secret becomes nil.
local _, ns = ...

local Debug = ns.Debug

local Compat = {}
ns.Compat = Compat

function Compat.IsSecret(v)
	return type(issecretvalue) == "function" and issecretvalue(v) == true
end

-- Returns v only if it is a plain, non-secret value of the expected type.
local function clean(v, kind)
	if v == nil or Compat.IsSecret(v) or type(v) ~= kind then
		return nil
	end
	return v
end
Compat.Clean = clean

function Compat.Now()
	if type(GetServerTime) == "function" then
		local t = clean(GetServerTime(), "number")
		if t then
			return t
		end
	end
	return time()
end

function Compat.InCombat()
	if type(InCombatLockdown) == "function" then
		return InCombatLockdown() and true or false
	end
	return false
end

function Compat.Build()
	local info = { version = "?", build = "?", interface = "?" }
	if type(GetBuildInfo) == "function" then
		local version, build, _, interface = GetBuildInfo()
		info.version = tostring(version)
		info.build = tostring(build)
		info.interface = tostring(interface)
	end
	return info
end

-- Best guess at the ruleset. Forever has one realm per ruleset, so the realm name is the tag.
function Compat.Ruleset()
	local tag = "unknown"
	if type(GetRealmName) == "function" then
		tag = clean(GetRealmName(), "string") or tag
	end
	if C_GameRules and C_GameRules.IsHardcoreActive then
		local ok, hardcore = pcall(C_GameRules.IsHardcoreActive)
		if ok and hardcore == true then
			tag = tag .. " (hardcore)"
		end
	end
	return tag
end

function Compat.IsInRaid()
	if type(IsInRaid) == "function" then
		return IsInRaid() and true or false
	end
	return UnitExists("raid1") and true or false
end

function Compat.IsInGroup()
	if type(IsInGroup) == "function" then
		return IsInGroup() and true or false
	end
	return (UnitExists("party1") or UnitExists("raid1")) and true or false
end

-- Unit tokens of the other players in the group (never "player").
function Compat.GroupUnits()
	local units = {}
	if Compat.IsInRaid() then
		for i = 1, 40 do
			local unit = "raid" .. i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") then
				units[#units + 1] = unit
			end
		end
	else
		for i = 1, 4 do
			local unit = "party" .. i
			if UnitExists(unit) then
				units[#units + 1] = unit
			end
		end
	end
	return units
end

local ROLES = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

local function identity(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil, "notplayer"
	end
	local name, suffix = UnitName(unit)
	if Compat.IsSecret(name) or Compat.IsSecret(suffix) then
		return nil, "secret"
	end
	if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
		return nil, "unknown"
	end
	if type(suffix) ~= "string" or suffix == "" then
		suffix = nil
	end

	local guid = clean(UnitGUID(unit), "string")
	if guid and guid:sub(1, 7) ~= "Player-" then
		guid = nil
	end
	local _, classFile = UnitClass(unit)
	local level = clean(UnitLevel(unit), "number")
	if level and level <= 0 then
		level = nil
	end
	local faction = UnitFactionGroup(unit)
	local role = clean(UnitGroupRolesAssigned(unit), "string")

	return {
		name = name,
		suffix = suffix,
		guid = guid,
		classFile = clean(classFile, "string"),
		level = level,
		faction = clean(faction, "string"),
		role = role and ROLES[role] or nil,
	}
end

-- Returns an identity table, or nil plus a reason ("notplayer", "secret", "unknown", "error").
function Compat.UnitIdentity(unit)
	local ok, result, reason = pcall(identity, unit)
	if not ok then
		Debug.Error("UnitIdentity", result)
		return nil, "error"
	end
	return result, reason
end

-- Where the player is right now, with every field checked for secrecy.
function Compat.InstanceState()
	local state = { inInstance = false, inGroup = Compat.IsInGroup() }
	local ok, err = pcall(function()
		local inInstance, instanceType = IsInInstance()
		state.inInstance = clean(inInstance, "boolean") or false
		state.instanceType = clean(instanceType, "string")
		local name, _, difficultyID, _, maxPlayers, _, _, instanceID = GetInstanceInfo()
		state.instanceName = clean(name, "string")
		state.difficultyID = clean(difficultyID, "number")
		state.maxPlayers = clean(maxPlayers, "number")
		state.instanceID = clean(instanceID, "number")
	end)
	if not ok then
		Debug.Error("InstanceState", err)
	end
	return state
end

-- Wraps text in the class color. Falls back to plain text.
function Compat.ClassColored(text, classFile)
	if classFile and C_ClassColor and C_ClassColor.GetClassColor then
		local ok, colored = pcall(function()
			local color = C_ClassColor.GetClassColor(classFile)
			return color and color:WrapTextInColorCode(text)
		end)
		if ok and type(colored) == "string" then
			return colored
		end
	end
	return text
end
