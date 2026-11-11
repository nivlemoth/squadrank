-- All user-facing text. To add a language, create Locales/<locale>.lua that fills the same
-- keys when GetLocale() matches, and list it in the TOC after this file.
local _, ns = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return tostring(key)
	end,
})
ns.L = L

L.ADDON = "SquadRank"
L.MSG_PREFIX = "|cff33bbffSquadRank|r: "

-- Reputation labels
L.LABEL_new = "New"
L.LABEL_trusted = "Trusted"
L.LABEL_mixed = "Mixed"
L.LABEL_caution = "Caution"

-- Roles
L.ROLE_tank = "Tank"
L.ROLE_healer = "Healer"
L.ROLE_dps = "DPS"

-- Tags
L.TAG_role_good = "Great at role"
L.TAG_communicator = "Good communicator"
L.TAG_helpful = "Patient/helpful"
L.TAG_efficient = "Efficient"
L.TAG_fair_loot = "Fair with loot"
L.TAG_stayed = "Stayed to the end"
L.TAG_knows_dungeon = "Knows the dungeon"
L.TAG_role_bad = "Bad at role"
L.TAG_ninja = "Ninja looted"
L.TAG_left_early = "Left early"
L.TAG_afk = "AFK"
L.TAG_toxic = "Toxic"
L.TAG_reckless = "Reckless pulls"
L.TAG_ignores_mechanics = "Ignores mechanics"

-- Player summary lines (toast and history)
L.FMT_RATED_ONE = "Rated once, score %.1f"
L.FMT_RATED_MANY = "Rated %d times, recent average %.1f"
L.FMT_ROLE_ONE = "%s %.1f over 1 run"
L.FMT_ROLE_MANY = "%s %.1f over %d runs"
L.FMT_TAGS = "Tags: %s"
L.FMT_NOTE = "Note: %s"
L.FMT_MORE = "...and %d more"

-- Toasts
L.TOAST_JOIN_ONE = "You have played with this player"
L.TOAST_JOIN_MANY = "Players you have rated are in your group"
L.PROMPT_TITLE = "Rate your squad"
L.PROMPT_BODY = "%s is over. %d players to rate."
L.BTN_RATE = "Rate"
L.BTN_LATER = "Later"

-- Rating window
L.RATE_TITLE = "Rate players"
L.RATE_RUN_FMT = "%s, %s"
L.RATE_NO_RUN = "Rating outside a run"
L.RATE_SCORE = "Score"
L.RATE_ROLE = "Role played"
L.RATE_TAGS = "Tags"
L.RATE_NOTE = "Note (optional, up to 140 characters)"
L.RATE_DONE_MARK = "(rated)"
L.RATE_NEED_SCORE = "Pick a score from 1 to 5 first."
L.RATE_SAVED = "Saved your rating for %s."
L.RATE_FAILED = "The rating could not be saved (%s)."
L.RATE_EMPTY = "Nobody to rate here."
L.BTN_SAVE = "Save"
L.BTN_DISMISS_RUN = "Stop asking"

-- Main window
L.MAIN_TITLE = "SquadRank"
L.TAB_PLAYERS = "Players"
L.TAB_RUNS = "Runs"
L.FILTER_LABEL = "Label"
L.FILTER_ROLE = "Role"
L.FILTER_TAG = "Tag"
L.FILTER_ALL = "All"
L.FILTER_FMT = "%s: %s"
L.COUNT_FMT = "%d shown"
L.COL_PLAYER = "Player"
L.COL_LABEL = "Reputation"
L.COL_RATINGS = "Ratings"
L.COL_ROLES = "Role scores"
L.COL_SEEN = "Last seen"
L.COL_INSTANCE = "Instance"
L.COL_DATE = "Date"
L.COL_PLAYERS = "Group"
L.COL_RATED = "Rated"
L.COL_BOSSES = "Bosses"
L.EMPTY_PLAYERS = "No players match. Group up, then rate someone."
L.EMPTY_RUNS = "No runs recorded yet."
L.MAIN_HINT = "Click a row for history. Right-click for more."
L.RUN_PLAYERS_FMT = "%d players"
L.RUN_RATED_FMT = "%d/%d rated"
L.UNKNOWN_INSTANCE = "Unknown instance"
L.MENU_RATE = "Rate in SquadRank"
L.MENU_HISTORY = "Show history"
L.MENU_PURGE = "Purge player"

-- Player history window
L.DETAIL_TITLE = "Player history"
L.DETAIL_SEEN = "First seen %s, last seen %s"
L.DETAIL_CLASS_LEVEL = "Level %s %s"
L.DETAIL_RULESETS = "Seen on: %s"
L.DETAIL_NO_RATINGS = "No ratings yet."
L.DETAIL_RATING_FMT = "%s   score %d   %s"
L.DETAIL_IMPORTED = "imported from SquadRank 1.x"
L.BTN_PURGE = "Purge"

-- Settings
L.SET_TOAST = "Show a toast when a rated player joins"
L.SET_TOAST_TIP = "Shown once per player per group, never in combat."
L.SET_DURATION = "Toast duration (seconds)"
L.SET_DURATION_TIP = "How long a toast stays on screen."
L.SET_MIN = "Ratings needed for a label"
L.SET_MIN_TIP = "Players with fewer ratings are shown as New."
L.SET_PROMPT = "Offer to rate the squad after a run"
L.SET_PROMPT_TIP = "A small prompt after you leave a dungeon or raid group."
L.SET_RECENT = "Use Blizzard's Recent Allies list (read-only)"
L.SET_RECENT_TIP = "Looks up players you rate by name. Never writes to Blizzard's notes."
L.SET_PURGE_ALL = "Delete all SquadRank data"
L.SET_PURGE_ALL_TIP = "Removes every saved player, rating and run. Settings are kept."
L.SET_PURGE_PLAYER = "Delete one player"
L.SET_PURGE_PLAYER_TIP = "Opens the player list. Right-click a player and choose Purge."
L.BTN_OPEN_LIST = "Open list"
L.CONFIRM_PURGE_ALL = "Delete every player, rating and run SquadRank has saved?\nThis cannot be undone."
L.CONFIRM_PURGE_PLAYER = "Delete %s and every rating you gave them?"

-- Debug window
L.DEBUG_TITLE = "SquadRank debug report"
L.DEBUG_HINT = "Click in the box, press Ctrl+A, then Ctrl+C to copy."
L.BTN_SELFTEST = "Run self-test"
L.BTN_REFRESH = "Refresh"

-- Chat messages
L.MSG_COMBAT = "Not available in combat. Try again after the fight."
L.MSG_READONLY = "Read-only mode (%s). Nothing will be saved. See /sr debug."
L.MSG_TOO_LARGE = "The saved data file is too large and may not load. Use /sr purge."
L.MSG_NOT_FOUND = "No saved player named '%s'."
L.MSG_AMBIGUOUS = "More than one player matches '%s'. Add the part after the dash:"
L.MSG_PURGED = "Deleted %s."
L.MSG_PURGED_ALL = "All SquadRank data deleted."
L.MSG_NO_PENDING = "No run is waiting for a rating."
L.MSG_UNIT_UNKNOWN = "That player's details are not available right now. Try again in a moment."
L.MSG_SELFTEST = "Self-test: %d pass, %d fail, %d info. Type /sr debug for details."
L.MSG_LIST_NONE = "No saved players match."
L.MSG_LIST_FMT = "%s - %s, %d ratings"
L.MSG_LIST_MORE = "...and %d more. Open /sr for the full list."
L.MSG_LISTS_SIMPLE = "Simple list mode is now %s. Type /reload to apply."
L.MSG_HELP_1 = "/sr - open the window"
L.MSG_HELP_2 = "/sr rate [name] - rate a player, or the last run when no name is given"
L.MSG_HELP_3 = "/sr list [text] - print saved players"
L.MSG_HELP_4 = "/sr purge <name> | all - delete saved data"
L.MSG_HELP_5 = "/sr debug - open the debug report;  /sr selftest - check the game APIs"
