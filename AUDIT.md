# SquadRank legacy audit

Audited 2026-11-10 against `docs/ref/*` and `docs/api-verified.md`.
Target for the rewrite: WoW Forever only, Interface 16001 (build 1.60.1.70888 in Blizzard's source).

Legacy code: `SquadRank.toc` (v1.5.2, Interface 110105) and one file, `SquadRank.lua` (1,578 lines), plus four PNG files.

## Verdict

**Rewrite everything. Keep the idea, the name, the slash command, and migrate the data shape.**
No module can be kept as is: every one either has a bug that breaks it on Forever, conflicts with the v0.1 spec,
or reinvents something Blizzard ships. The legacy file stays in git history (first commit) and is removed from the addon.

## Module by module

| Legacy module (lines) | Decision | Why |
|---|---|---|
| TOC | **Rewrite** | Interface 110105 is out of date. No icon, category or compartment entry. `LoadSavedVariablesFirst` is kept |
| Color and icon tables (12-33) | **Drop** | v0.1 uses Blizzard's look. Custom colors and backdrops go |
| PNG icons (8.5 MB total) | **Drop for v0.1** | WoW reliably loads only TGA/BLP textures at power-of-two sizes; these PNGs are also multi-megabyte. v0.1 uses built-in Blizzard icons. A proper logo can be added later |
| Class colors (36-73) | **Rewrite** as a 3-line call | `C_ClassColor.GetClassColor` is verified. The hardcoded table lists 4 classes Forever does not have |
| Date helpers (76-87) | **Rewrite** | Stores formatted local-time strings. New code stores `GetServerTime()` numbers and formats on display |
| Instance type and difficulty (99-146) | **Drop** | Retail difficulty IDs, and wrong even there (Mythic+ level is not `difficultyID - 7`). Forever has only group size 5/10/20/40 |
| DB init (149-166) | **Rewrite** | No schema version, no defaults merge (new settings never reach old saves), no migration |
| Import/Export popups (169-256) | **Drop for v0.1** | Not in the v0.1 spec. Also broken: see bugs 1 and 8 |
| Minimap button (259-357) | **Drop** | Replaced by the TOC Addon Compartment directives. See bug 2 |
| Role guess from class (363-380) | **Drop** | Wrong by design: says every Paladin and Druid is a tank or healer. v0.1 records the role the rater observed |
| Group scan (382-427, duplicated 675-716) | **Rewrite** in one place | Duplicated code, faction in the key, no secret-value checks, splits names on `-` |
| Run tracking (429-561) | **Rewrite** | See bugs 3, 4, 5, 6. Only starts on a boss pull, so a run with no boss fight is never recorded |
| "Player left" toast (564-670) | **Rewrite as the join toast** | The spec inverts it: warn when a known player joins, not when anyone leaves. Legacy creates a new global-named frame per toast and can show during combat |
| Main window (719-904, 997-1527) | **Rewrite** | 1100x700 hardcoded layout; creates new frames for every row on every refresh and never frees them; filter "dropdowns" are plain buttons with no menu; settings tab says "Coming soon" |
| Rating dialog (906-995) | **Rewrite** | Three near-identical button handlers repeated in two places; rating is GOOD/OK/BAD with no tags, note or role |
| Event handler (1530-1558) | **Rewrite** | No error isolation, no combat deferral, no debounce on `GROUP_ROSTER_UPDATE` |
| Slash commands (1561-1578) | **Refactor** | Keep `/squadrank`, add `/sr` with subcommands. Three separate commands become one |

## Bugs found (the ones from Phase 0 plus new ones)

| # | Bug | Where | Effect |
|---|---|---|---|
| 1 | Popup text box is read as `self.editBox`; Forever names it `EditBox` | 181, 249 | Import and Export throw a Lua error |
| 2 | Minimap shape test checks that `Minimap.SetArchBlobRingScalar` exists (it always does) and reads a CVar that does not exist | 262-267 | Button always placed for a square minimap |
| 3 | `table.getn` on a table keyed by strings | 480 | "Tracking N players" always prints 0 |
| 4 | Current run lives only in local variables | 360-361 | `/reload` or a disconnect mid-dungeon loses the run |
| 5 | Starting a run deletes every earlier run of the same instance | 443-448 | History is destroyed by design |
| 6 | Run ends on any `PLAYER_ENTERING_WORLD` | 1550-1554 | Any loading screen ends the run, including a `/reload` inside the dungeon |
| 7 | Player key is `Realm-Name-Faction` | 10, 412, 700 | Breaks on faction change; not a GUID; realm names containing `-` are ambiguous |
| 8 | Import keys records by a field it calls `guid`, but export writes the `Realm-Name-Faction` key; fields are split on `:` | 188-190, 238 | Works only by accident; no validation of imported text at all |
| 9 | Names are split at the first `-` | 408-410, 696-698 | Mangles any name where the separator is part of the name data. On Forever the second value from `UnitName` may be a **surname**, not a realm (see below) |
| 10 | New frames per refresh, old ones only hidden and unparented | 1115-1121, 1317-1323 | Memory grows every time the window refreshes |
| 11 | Toast and dialog frames use fixed global names and are created on every call | 565, 907 | Global name collisions; frames pile up |
| 12 | Inner `playerName` local shadows the outer one inside the filter loop | 1134 | Harmless today, a trap for edits |
| 13 | Version shown at load is "v2.0", TOC says 1.5.2 | 1541 | Confusing bug reports |
| 14 | `SquadRank` is one of several globals: also `SquadRankMinimapIcon`, `SquadRankMovableToast`, `SquadRankMainWindow`, `SquadRankPlayerDialog` | various | Breaks the one-global rule |
| 15 | Everything prints to chat on every boss pull and kill | 479-487 | Chat spam |

## API status of what the legacy code calls

| Status | APIs |
|---|---|
| Verified in Forever source | `UnitName`, `UnitClass`, `UnitFactionGroup`, `UnitExists`, `UnitIsPlayer`, `GetRealmName`, `GetInstanceInfo`, `IsInInstance`, `GetZoneText`, `GetCVar`, `GetCursorPosition`, `C_ClassColor.GetClassColor`, `C_Timer.After`, events `ADDON_LOADED`, `ENCOUNTER_START`, `ENCOUNTER_END`, `PLAYER_ENTERING_WORLD`, `GROUP_ROSTER_UPDATE` |
| Not in Blizzard's generated docs (old globals, need the in-game self-test) | `IsInGroup`, `IsInRaid`, `GetNumGroupMembers`, `strsplit` |
| Broken on Forever | `StaticPopup` `.editBox` field, CVar `minimapShapeshiftTracking` |

## Secret-value, taint and combat risks in the legacy code

- No `issecretvalue` checks anywhere. Names and class values go straight into table keys and string compares.
  If any of them is secret, that is an immediate Lua error inside the event handler.
- The roster is read at `ENCOUNTER_START`, which is exactly when encounter restrictions begin.
- UI is built and shown from event handlers with no combat check.
- No secure frames are touched, so there is no action-blocking taint risk. The new unit-menu entry (see PLAN.md)
  uses Blizzard's supported `Menu.ModifyMenu` hook.

## New finding that affects the data model: surnames

Forever's unit menu code (`Blizzard_UnitPopupShared/UnitPopupShared.lua:34-50`) treats the second value from
`UnitNameUnmodified` as a **surname** when "regionally unique names" are enabled, and Forever alone has a
`C_NameUtil` surname API. On a one-realm-per-ruleset game this is plausible: players may be "Name Surname"
rather than "Name-Realm". This is unconfirmed at runtime. The plan therefore stores the two name parts as
returned, never splits a combined string itself, and the self-test reports what the client really returns.

## Data model: legacy to new

Legacy `SquadRankDB` (no version field, treated as schema 0):

```
players[Realm-Name-Faction] = { name, realm, class, groupedCount, lastGrouped, lastLocation,
                                rankGood, rankOk, rankBad, lastRank, instanceHistory }
squadHistory[date-random]   = { date, location, type, difficulty, players{...}, rating, encountersCompleted }
settings                    = { showMinimapIcon, showToast, minimapIconAngle, toastPos, filter*, searchText }
```

Migration 0 to 1 (implemented and unit-tested even though Forever keeps its own, probably empty, WTF folder):
- Each legacy player becomes a name-keyed record (no GUID known). Faction moves from the key to a field.
- `lastRank` GOOD/OK/BAD becomes one rating with score 5/3/1, no tags, no role, flagged `imported`.
  The good/ok/bad counters are not expanded into fake ratings.
- `squadHistory` entries become run records with the date string parsed to a timestamp; members link by name key.
- Legacy settings are dropped except `showToast`, which maps to `toastEnabled`.
- A full copy of the old table is kept in `SquadRankDB.backup` before the migration runs.
