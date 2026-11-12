-- SquadRank: namespace and the one public global.
local addonName, ns = ...

ns.ADDON = addonName or "SquadRank"
ns.VERSION = "0.3.0"
ns.SCHEMA = 1

-- The only global this addon defines on purpose, besides its two SavedVariables and the
-- names the client forces on us (slash command and Addon Compartment handler).
SquadRank = SquadRank or {}
SquadRank.version = ns.VERSION
