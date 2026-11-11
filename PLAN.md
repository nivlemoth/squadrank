# SquadRank v0.1 plan

Target: WoW Forever only. One TOC, `## Interface: 16001`. No third-party libraries. Lua 5.1.
Written 2026-11-10. Sources for every "verified" below: `docs/api-verified.md` and Blizzard's Forever UI source
(Gethe/wow-ui-source, branch `forever`, build 1.60.1.70888).

## 1. Decisions that need your approval (checkpoint 1)

| # | Decision | Recommendation |
|---|---|---|
| A | **Extra globals the client forces.** The Addon Compartment calls `_G[name]`, so its click handler must be a global function. Slash commands need `SLASH_SQUADRANK1/2` globals. | Allow exactly these beyond `SquadRank`, `SquadRankDB`, `SquadRankDebug`: `SquadRank_OnAddonCompartmentClick`, `SLASH_SQUADRANK1`, `SLASH_SQUADRANK2`. |
| B | **Tooling is not installed.** This machine has git, npm, pip and winget, but no Lua, StyLua, luacheck or busted. | I install: StyLua (npm package `@johnnymorganz/stylua-bin`), luacheck (standalone Windows exe from its GitHub releases), Lua 5.1 + LuaRocks + busted (winget if a package exists, otherwise `hererocks` via pip). All installed for your user only. If busted cannot be installed, tests run on a plain Lua 5.1 interpreter with a small runner in `spec/`, and I log that in DECISIONS.md. |
| C | **Git.** The folder is not a repository. | `git init` here, first commit = legacy code + docs on `main`, then branch `v0.1`. Local commits only; no remote, no push. |
| D | **Legacy PNG icons** (8.5 MB, a format WoW does not reliably load). | Remove from the addon folder (they stay in git history). v0.1 uses a built-in Blizzard icon. |
| E | **Post-run prompt timing.** In a Vanilla-style game, dying puts you outside the instance, so "left the instance" is not "run over". | A run ends when you leave the group, enter a different instance, or stay outside for 5 minutes. The prompt appears then, out of combat. |
| F | **Role is required on a rating**, preselected from the group role if the client reports one, else the role you last rated that player in, else DPS. | As described. |
| G | **Toast only for players you have rated.** Players seen but never rated get no toast. | As described. |

## 2. File tree

```
SquadRank/
  SquadRank.toc
  Locales/enUS.lua          all user-facing strings (ns.L)
  Core/Init.lua             namespace, the SquadRank global, version, safe-call wrapper
  Core/Compat.lua           every unverified or secret-capable API goes through here
  Core/Util.lua             text sanitizing, time, table helpers (pure Lua, testable)
  Core/Debug.lua            ring buffer (200), error capture, report builder, SquadRankDebug mirror
  Core/SelfTest.lua         /sr selftest
  Core/Events.lua           one event frame, pcall dispatch, debounce, out-of-combat queue
  Data/DB.lua               defaults, load, backup, pruning (pure Lua)
  Data/Migrations.lua       schema 0 -> 1 and the framework (pure Lua)
  Data/Players.lua          identity: GUID key, name fallback, merge (pure Lua)
  Data/Ratings.lua          rating CRUD, tags, reputation and per-role stats (pure Lua)
  Data/Runs.lua             run records, current run (pure Lua)
  Track/Roster.lua          roster snapshot, group session, join detection
  Track/RunTracker.lua      instance enter/leave, run lifecycle
  Integrations/RecentAllies.lua   read-only, off by default
  UI/Toast.lua              join toast and "Rate your squad" prompt toast
  UI/RateFrame.lua          rating form (one player, or a whole squad)
  UI/MainWindow.lua         player list (ScrollBox), filters, run list
  UI/PlayerDetail.lua       history for one player
  UI/UnitMenu.lua           "Rate player" in unit right-click menus
  UI/Settings.lua           Blizzard Settings panel
  UI/DebugPanel.lua         /sr debug copy box
  UI/Slash.lua              /sr and /squadrank
  spec/                     busted tests + minimal WoW stubs
  docs/ref/*, docs/api-verified.md, docs/DECISIONS.md
  .luacheckrc  stylua.toml  .pkgmeta
  AUDIT.md  PLAN.md  INSTALL.md  RELEASE_NOTES.md  TESTING.md
```

`Data/*` and `Core/Util.lua` call no WoW API (time and logging are passed in), so they run under busted.
All UI is built in Lua with Blizzard templates; no XML unless a ScrollBox row needs a template (fallback noted in §8).

## 3. TOC

```
## Interface: 16001
## Title: SquadRank
## Notes: Remember how past groupmates performed and get a heads-up when they join.
## Author: Nivlemoth
## Version: 0.1.0
## Category: Group
## IconTexture: Interface\Icons\Achievement_GuildPerk_EverybodysFriend   (checked in game; fallback INV_Misc_GroupLooking)
## SavedVariables: SquadRankDB, SquadRankDebug
## LoadSavedVariablesFirst: 1
## AddonCompartmentFunc: SquadRank_OnAddonCompartmentClick
```

followed by the files in the order of §2. `.pkgmeta` will replace the version with `@project-version@` later.

## 4. Data model (`SquadRankDB`, schema 1)

```
schema   = 1
nextId   = 1                       counter for rating and run ids
settings = { toastEnabled=true, toastDuration=8, minRatings=3, promptAfterRun=true,
             recentAllies=false, debug=false }
players  = { [pid] = {
    guid,                  nil until seen non-secret
    name, suffix,          the two values UnitName returns (suffix = realm or surname, may be nil)
    classFile, level, faction,
    firstSeen, lastSeen,   GetServerTime()
    rulesets = { [tag]=true },   metadata only; one record per player across rulesets
    ratings  = { { id, createdAt, updatedAt, runId, role, score, tags={...}, note, imported } },
} }
runs     = { [runId] = { id, instanceID, instanceName, instanceType, maxPlayers, groupSize,
                         startedAt, endedAt, ruleset, bossKills, members = { {pid, role} }, prompt } }
currentRun = nil | run            written as events happen, so /reload loses nothing
session  = { key, startedAt, toasted = { [pid]=true } }   current group; survives /reload
backup   = nil | { schema, at, data }   one copy, taken before a migration
```

- **Player id (`pid`)**: `"g:"..GUID` when a non-secret GUID is known, else `"n:"..name.."-"..suffix` (lowercased).
  When a GUID first appears for a name-keyed record, the record is re-keyed and run members are updated.
  A name index (name -> pid) is rebuilt in memory at load, not saved.
- **Tags** are stored as short ids (`role_good`, `ninja`, ...); labels come from the locale table.
  7 positive and 7 negative, exactly the list in the spec.
- **Note**: trimmed, `|c |r |T |t |H |h |A |a |K |n` sequences and any remaining `|` removed, control characters
  removed, cut to 140 characters. Done by our own Lua code (tested); `C_StringUtil.StripHyperlinks` is not relied on.
- **Reputation**: weighted mean of scores, weight `0.5 ^ (ageDays / 90)`. Shown only with at least
  `minRatings` ratings, otherwise "New". Trusted >= 4.0, Caution <= 2.5, Mixed in between.
  Per role: plain mean and count ("Healer 4.5 over 4 runs").
- **One rating per player per run**; rating again edits it (`updatedAt`). Ratings made outside a run have no `runId`.
- **Pruning** (at load and after each finished run): keep the newest 300 runs; at most 50 ratings per player
  (oldest dropped); players with no ratings and not seen for 180 days are removed; `SquadRankDebug` is capped
  at 200 lines. Rated players are never removed automatically. `SAVED_VARIABLES_TOO_LARGE` is logged and shown as a warning.
- **Migrations**: `Migrations[n]` upgrades schema n to n+1. Before the first one runs, the whole table is
  deep-copied to `backup`. A DB with a schema newer than the addon is left untouched and the addon runs read-only.

## 5. Behaviour

**Group session and join toast**
- `GROUP_ROSTER_UPDATE` is debounced (1 second), then the roster is read out of combat. If in combat, the read
  waits for `PLAYER_REGEN_ENABLED`.
- Every identity value passes `issecretvalue` in `Compat`. A secret value is never stored, compared or shown;
  that unit is retried on the next roster read.
- A member not yet in `session.toasted` who has at least one rating gets a toast: name in class color,
  label (or "New" with the count), per-role line, top 3 tags, last note. Each player is toasted once per session.
- Several known players at once (you join a formed group) produce one combined toast with up to 5 rows.
- Toasts queue one at a time, hide after `toastDuration`, close on click, and never show in combat.
- The session ends when you are no longer in a group.

**Run tracking and the post-run prompt**
- On `PLAYER_ENTERING_WORLD` and `ZONE_CHANGED_NEW_AREA`: if `IsInInstance()` reports `party` or `raid`,
  start a run or resume `currentRun` when the instance ID matches. Roster reads while inside add members.
- `ENCOUNTER_END` / `BOSS_KILL` only increment `bossKills`. Nothing depends on them firing.
- End of run: decision E. Solo runs are discarded.
- Prompt: a small toast, "Rate your squad: <instance>", with Rate and Later. Rate opens the squad form:
  one row per member with 1-5 score, role, tag chips, note. Skipped runs stay in the Runs list and reopen
  with `/sr rate` (no name).

**Rate anytime**: "Rate in SquadRank" in the unit menus `MENU_UNIT_PARTY`, `MENU_UNIT_RAID_PLAYER`,
`MENU_UNIT_PLAYER`, `MENU_UNIT_TARGET` (players only), and `/sr rate <name>`.

**Main window**: Blizzard `ButtonFrameTemplate`; search box; filters (label, role, tag) through Blizzard Menu
dropdowns; ScrollBox player list; click opens the detail view; right-click menu has Rate and Purge player.
Second tab lists runs.

**Settings** (Blizzard Settings panel): toast on/off, toast duration, minimum-ratings threshold,
prompt after run, Recent Allies flag, purge all (confirmation popup), purge player (opens the main window).

**Slash**: `/sr` (window), `/sr rate [name]`, `/sr list [text]`, `/sr purge <name>|all`, `/sr debug`, `/sr selftest`.
`/squadrank` is an alias.

**Debug**: every handler runs through a pcall wrapper that records errors in the ring buffer; the global
error handler is not touched. The report contains versions, build, ruleset guess, schema, counts, settings,
self-test results, the last 200 buffer lines and captured errors. It never contains names, GUIDs or notes of
other players, only counts and pids hashed to short numbers. The same text is mirrored to `SquadRankDebug`.

## 6. Events and APIs

| Event | Use | Status |
|---|---|---|
| `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT` | init, migrate, flush debug | verified |
| `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA` | instance enter/leave | verified |
| `GROUP_ROSTER_UPDATE`, `GROUP_JOINED(category, partyGUID)`, `GROUP_LEFT` | session, joins | verified |
| `PLAYER_REGEN_DISABLED/ENABLED` | combat gate | verified |
| `ENCOUNTER_END`, `BOSS_KILL` | boss counter only | verified in source; firing in Forever dungeons unknown (self-test listens) |
| `ADDON_RESTRICTION_STATE_CHANGED` | logged for diagnosis | verified |
| `SAVED_VARIABLES_TOO_LARGE(addOnName)` | warning | verified |

| API | Status | Handling |
|---|---|---|
| `UnitName`, `UnitGUID`, `UnitClass`, `UnitLevel`, `UnitFactionGroup`, `UnitExists`, `UnitIsPlayer`, `UnitIsUnit`, `UnitGroupRolesAssigned`, `GetInstanceInfo`, `IsInInstance`, `GetServerTime`, `InCombatLockdown`, `issecretvalue`, `C_ClassColor`, `C_Timer`, `C_AddOns.GetAddOnMetadata`, `GetBuildInfo` | verified in source | secret-capable ones only via `Compat` |
| `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `GetNumSubgroupMembers` | **unverified** | `Compat` wrappers; fallback counts `UnitExists("partyN"/"raidN")`; self-test |
| Second return of `UnitName` (realm or surname) | **unverified** | stored as returned; self-test reports its shape, not its value |
| Ruleset: `C_GameRules.IsHardcoreActive`, `GetRealmName` | **unverified at runtime** | tag = realm name plus hardcore flag; "unknown" if absent |
| `Menu.ModifyMenu` and the four menu tags | function verified; tags built as `"MENU_UNIT_"..which` in source | wrapped in pcall; self-test reports registration |
| `Settings.RegisterVerticalLayoutCategory`, `RegisterAddOnSetting`, `CreateCheckbox`, `CreateSlider`, `RegisterAddOnCategory`, `OpenToCategory` | verified in source | pcall; if it fails, settings stay reachable through `/sr` |
| ScrollBox (`WowScrollBoxList`, `MinimalScrollBar`, `CreateScrollBoxListLinearView`, `CreateDataProvider`) | verified in source | see §8 |
| `C_RecentAllies.*` | verified in source; enabled state unknown | behind the flag, nil-checked, read-only |

New entries are added to `docs/api-verified.md` as "unverified" before first use.

## 7. Build order (one commit per step on `v0.1`; StyLua + luacheck clean before each commit)

0. Tooling, `git init`, `.luacheckrc`, `stylua.toml`, new TOC, Init, locale table.
1. Debug + self-test + `/sr debug` panel + slash skeleton.
2. DB, migrations, pruning, with busted tests.
3. Run tracking (Compat, Events, Roster, RunTracker).
4. Rating model (Players, Ratings) with tests.
5. Join toast.
6. Rating UI (form, prompt toast, unit menu, `/sr rate`).
7. Main window and detail.
8. Settings panel, Recent Allies flag.
9. Checkpoint 2: RELEASE_NOTES.md, TESTING.md (numbered in-game checklist), INSTALL.md, `.pkgmeta`.

## 8. Tests

**Automated (busted, no game client):** sanitizer (escape codes, 140 limit, control characters); defaults merge;
migration 0 to 1 with backup; newer-schema guard; pruning limits; pid creation, name to GUID re-key and merge;
rating add/edit/delete, one per run; reputation thresholds, recency weighting, minimum-ratings rule; per-role
stats; run start/resume/end rules including the 5-minute rule and the same-instance-twice case; session
"toast once" logic; debug report contains no player names.

**In game (you, from TESTING.md):** addon loads with no errors; `/sr selftest` all rows; `/sr debug` copy box;
join toast with a second character or a friend; no toast in combat; `/reload` inside a dungeon keeps the run;
prompt after leaving; unit menu entry; settings persist; purge.

**What I cannot test here:** anything that needs the client. UI code is written against Blizzard's source but
first runs on your machine. Expect the first in-game pass to surface errors; `/sr debug` exists to report them.
Known risk: whether a ScrollBox row can be created from a plain frame type without an XML template. If not,
I add one small XML template file.
