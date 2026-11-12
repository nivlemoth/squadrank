std = "lua51"
max_line_length = 120
self = false
exclude_files = { ".git", ".release" }

globals = {
	"SquadRank",
	"SquadRankDB",
	"SquadRankDebug",
	"SquadRank_OnAddonCompartmentClick",
	"SLASH_SQUADRANK1",
	"SLASH_SQUADRANK2",
	"SlashCmdList",
	"StaticPopupDialogs",
}

read_globals = {
	-- Lua additions in the WoW client
	"date",
	"time",
	"issecretvalue",
	-- frames and templates
	"CreateFrame",
	"UIParent",
	"GameTooltip",
	"ButtonFrameTemplate_HidePortrait",
	"ButtonFrameTemplate_HideButtonBar",
	"ChatFontNormal",
	"StaticPopup_Show",
	"CreateScrollBoxListLinearView",
	"CreateDataProvider",
	"ScrollUtil",
	"ScrollBoxConstants",
	"MenuUtil",
	"Menu",
	"Settings",
	"CreateSettingsButtonInitializer",
	"MinimalSliderWithSteppersMixin",
	"CreateColor",
	"GetCursorPosition",
	-- unit and group
	"UnitExists",
	"UnitIsPlayer",
	"UnitIsUnit",
	"UnitName",
	"UnitGUID",
	"UnitClass",
	"UnitLevel",
	"UnitFactionGroup",
	"UnitGroupRolesAssigned",
	"IsInGroup",
	"IsInRaid",
	"GetNumGroupMembers",
	"GetNumSubgroupMembers",
	"UNKNOWNOBJECT",
	-- instance and system
	"IsInInstance",
	"GetInstanceInfo",
	"GetZoneText",
	"C_Texture",
	"GetRealmName",
	"GetServerTime",
	"GetBuildInfo",
	"InCombatLockdown",
	"C_Timer",
	"C_ClassColor",
	"C_GameRules",
	"C_RestrictedActions",
	"C_RecentAllies",
	"C_StringUtil",
	"C_AddOns",
	"OKAY",
	"CANCEL",
	"YES",
	"NO",
}

files["spec/**"] = {
	std = "+busted",
	globals = { "time", "date", "issecretvalue", "SquadRank" },
}
