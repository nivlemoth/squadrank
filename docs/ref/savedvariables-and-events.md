# SavedVariables and events: reference for SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/SavedVariables
- https://warcraft.wiki.gg/wiki/Events
- https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes
- https://warcraft.wiki.gg/wiki/TOC_format (LoadSavedVariablesFirst)
- Blizzard_APIDocumentationGenerated, `forever` @ 4cd0ab7 (1.60.1.70888) and `live` @ 297d7aa (12.1.5.70783)

## SavedVariables: facts
- Files live under `<WoW>/<game_type>/WTF/Account/<ACCOUNT>/`:
  - `SavedVariables/<Addon>.lua`: account-wide (`## SavedVariables`)
  - `<Realm>/<Char>/SavedVariables/<Addon>.lua`: per character (`## SavedVariablesPerCharacter`)
- Each game type (Forever, retail, Classic) has its **own WTF folder**, so Forever data is separate from retail data.
- The files are plain Lua tables, rewritten on save. Anything hand-edited in them is overwritten.
- Pitfall: a stray `SavedVariables.lua` elsewhere can load instead, and the addon then appears to "forget".
- Access SVs only after `ADDON_LOADED` with `addOnName == "SquadRank"`, or anywhere if `LoadSavedVariablesFirst: 1`.
- Pattern: `DB = DB or {}`, then copy any missing keys from a `defaults` table. Reset with `CopyTable(defaults)`.

### Known from general WoW practice but NOT stated on the fetched wiki page (verify before relying on it)
- SVs are written on logout and `/reload`, not on a client crash. A crash loses the whole session.
- Functions, userdata and metatables are not serialized. Shared or circular table references are duplicated or broken.
- A large SV file slows login and reload, so cap history size.
- Test: `/reload`, then check that the file timestamp changed. Kill the client during play and confirm that edits are lost.

## Event handling
- `local f = CreateFrame("Frame"); f:RegisterEvent("X"); f:SetScript("OnEvent", function(self, event, ...) end)`
- Dispatch pattern from the wiki: `function f:OnEvent(event, ...) self[event](self, event, ...) end`
- 12.0 added `Frame:RegisterEventCallback` / `RegisterUnitEventCallback` and global `RegisterEventCallback`.
  They are optional, and the classic `RegisterEvent` still works.
- `EventUtil.ContinueOnAddOnLoaded(name, fn)` exists in Forever SharedXML (Blizzard helper).

## Events relevant to SquadRank (present in BOTH forever and live generated docs)
| Event | Payload (Forever doc) | Notes |
|---|---|---|
| `ADDON_LOADED` | addOnName, containsBindings | Init DB |
| `PLAYER_LOGIN` | none | Fires once. UI and player info ready |
| `PLAYER_ENTERING_WORLD` | isInitialLogin, isReloadingUi (verify) | Every loading screen. Legacy code uses it as "left instance" |
| `PLAYER_LOGOUT` | none | Last chance to tidy the SV before it is written |
| `GROUP_ROSTER_UPDATE` | none (`UniqueEvent`) | Fires often; coalesce |
| `GROUP_JOINED` / `GROUP_LEFT` | (check doc) | Cleaner session start and end |
| `ENCOUNTER_START` | encounterID, encounterName, difficultyID, groupSize | `SynchronousEvent` |
| `ENCOUNTER_END` | encounterID, encounterName, difficultyID, groupSize, success | **live adds a 6th field `encounterUnitStatus`; Forever does not** |
| `BOSS_KILL` | encounterID, encounterName | |
| `LFG_COMPLETION_REWARD` | (check doc) | Blizzard's dungeon-complete toast (`AlertFrames.lua`). Applies only to LFG-queued runs |
| `CHALLENGE_MODE_START/COMPLETED` | mapID ... | Present in the Forever API, but Forever has **no Mythic+** (see forever-vs-retail.md) |
| `SCENARIO_COMPLETED` | | Probably not relevant to Forever |
| `ZONE_CHANGED_NEW_AREA` | none | Instance enter and exit |
| `PLAYER_REGEN_DISABLED/ENABLED` | none | Combat enter and exit. Defer UI work until combat ends |
| `ADDON_RESTRICTION_STATE_CHANGED` | type (`Enum.AddOnRestrictionType`), state | 12.0+. Tells us when secrets start and stop |
| `UNIT_NAME_UPDATE` | unit | Names can resolve late ("Unknown") |
| `LFG_LIST_JOINED_GROUP` | (check doc) | Group Finder join |
| `INSTANCE_GROUP_SIZE_CHANGED` | | |

## Login and reload order (well known, but the fetched page was truncated, so verify)
`ADDON_LOADED` (each addon) → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)`.
In-game test: `/etrace`, then `/reload` and read the order.

## Consequences for the design
1. Save state incrementally into the SV table and never keep critical data only in locals. A crash loses
   the in-memory session, and the legacy `currentInstanceRun` is a local that is lost on `/reload` inside a dungeon.
2. `PLAYER_ENTERING_WORLD` also fires on `/reload` and on every loading screen inside an instance, so use
   `IsInInstance()` plus the instance ID to decide whether the run really ended.
3. Coalesce `GROUP_ROSTER_UPDATE` (C_Timer.After(0.5) or an event bucket) because it fires in bursts.
