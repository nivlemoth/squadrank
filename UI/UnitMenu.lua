-- Adds "Rate in SquadRank" and the avoid-list toggle to the right-click menu of player unit frames, using
-- Blizzard's supported Menu.ModifyMenu hook. Tags are "MENU_UNIT_" .. menu name, as built in
-- Blizzard_UnitPopupShared/UnitPopupShared.lua.
local _, ns = ...

local L = ns.L
local Debug = ns.Debug

local UnitMenu = {}
ns.UnitMenu = UnitMenu

local TAGS = { "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS" }

local function isOtherPlayer(unit)
	if type(unit) ~= "string" then
		return false
	end
	local ok, result = pcall(function()
		return UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
	end)
	return ok and result == true
end

local function addEntry(_, root, contextData)
	local unit = type(contextData) == "table" and contextData.unit or nil
	if not isOtherPlayer(unit) then
		return
	end
	root:CreateDivider()
	root:CreateButton(
		L.MENU_RATE,
		ns.Safe("unit menu click", function()
			ns.RateFrame.OpenUnit(unit)
		end)
	)
	-- The label shows the current state only when the player is already saved (read out of combat).
	local db = ns.db
	local pid = db and not ns.Compat.InCombat() and ns.Players.Lookup(db, ns.Compat.UnitIdentity(unit))
	local avoided = pid and db.players[pid].avoid
	root:CreateButton(
		avoided and L.MENU_UNAVOID or L.MENU_AVOID,
		ns.Safe("unit menu avoid", function()
			ns.MainWindow.ToggleAvoidUnit(unit)
		end)
	)
end

function UnitMenu.Register()
	if not (Menu and Menu.ModifyMenu) then
		Debug.notes.unitMenu = "Menu.ModifyMenu missing; use /sr rate <name>"
		return
	end
	local registered = 0
	local handler = ns.Safe("unit menu", addEntry)
	for _, tag in ipairs(TAGS) do
		if pcall(Menu.ModifyMenu, tag, handler) then
			registered = registered + 1
		end
	end
	Debug.notes.unitMenu = ("ok, %d of %d menus"):format(registered, #TAGS)
end
