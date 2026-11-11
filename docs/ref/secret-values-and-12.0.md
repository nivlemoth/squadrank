# Secret values and the 12.0 API changes: reference for SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/Secret_Values
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes (both halves read)
- Blizzard_APIDocumentationGenerated, `forever` @ 4cd0ab7 (1.60.1.70888): UnitDocumentation.lua,
  RestrictedActions*Documentation.lua, SecretPredicateAPIDocumentation.lua, FrameScriptDocumentation.lua

## What secret values are (introduced in 12.0.0)
- On **tainted** (addon) execution, some API returns are opaque "secret" values. Untainted Blizzard code sees them normally.
- **Forbidden on a secret value:** arithmetic, comparisons and boolean tests (except nil/non-nil), `#`,
  **using it as a table key**, indexing it, calling it. Any of these raises an **immediate Lua error**.
- **Allowed:** storing it in a variable or table field, passing it to Lua functions, concatenation, `string.format`,
  `string.join`, `string.concat`, `type()`, and passing it to C functions marked as accepting secrets.
- Test helpers (present in Forever FrameScriptDocumentation): `issecretvalue(v)`, `canaccessvalue(v)`,
  `issecrettable(t)`, `canaccesstable(t)`, plus `hasanysecretvalues`, `scrubsecretvalues`, `canaccessallvalues`.

## When it applies: `Enum.AddOnRestrictionType` (Forever doc)
| Value | Name | Meaning (verbatim doc) |
|---|---|---|
| 0 | Combat | "The player is actively affecting combat." |
| 1 | Encounter | "...actively participating in an instance encounter." |
| 2 | ChallengeMode | "...in an active and incomplete challenge mode or mythic keystone dungeon." |
| 3 | PvPMatch | "...in an active and incomplete PvP match." |
| 4 | Map | "...on a map that applies addon restrictions." (wiki: "dungeon or raid") |
| 5 | Chat | "...addon chat communications are restricted." |

Query it with `C_RestrictedActions.IsAddOnRestrictionActive(type)` / `GetAddOnRestrictionState(type)`. Watch it with
`ADDON_RESTRICTION_STATE_CHANGED(type, state)`. All of these are in the Forever docs.

## The APIs SquadRank needs (Forever doc flags)
| API | Secret flag | Wiki description of the predicate |
|---|---|---|
| `UnitName(unit)` | `SecretWhenUnitNameIdentityRestricted` | "regular unit identity secrecy rules", except in PvP for player units |
| `UnitFullName(unit)` | `SecretWhenUnitIdentityRestricted` | secret "when the unit isn't player-controlled or in the party/raid" |
| `UnitGUID(unit)` | `SecretWhenUnitIdentityRestricted`; arg type `UnitTokenPvPRestrictedForAddOns` | as above |
| `UnitClass(unit)` | `SecretWhenUnitIdentityRestricted`; **only return 1 (localized name) is ConditionalSecret**; `classFilename`, `classID` not flagged | as above |
| `UnitGroupRolesAssigned(unit)` | `SecretWhenUnitIdentityRestricted` | as above |
| `UnitTokenFromGUID(guid)` | `SecretWhenUnitIdentityRestricted` | as above |
| `UnitFactionGroup(unit)` | no secret flag | |
| `GetInstanceInfo()` / `IsInInstance()` | no secret flag | |
| `ENCOUNTER_START/END` payload | no secret flag in the doc (but see `SecretWhenEncounterEvent`, 12.0.5, undocumented) | |

**Reading:** for party and raid members, identity (name, GUID, class) should NOT be secret, because the predicate excludes
"in the party/raid". That is the wiki's wording, and **it is not confirmed for every restriction state**.
Treat it as unverified until the in-game tests below pass.

## Other 12.0 changes that matter
- `COMBAT_LOG_EVENT_UNFILTERED` and `COMBAT_LOG_EVENT` **error on register**, and `CombatLogGetCurrentEventInfo` was removed.
  This rules out any "performance" metrics from the combat log (deaths, damage, interrupts) for ratings.
- New `UNIT_DIED`, `PARTY_KILL` events. Their secrecy is unknown and we do not plan to use them.
- Chat lockdown (`C_ChatInfo.InChatMessagingLockdown`, restriction type Chat): addon messages may be blocked
  in instances or combat. This is irrelevant while we make no network or addon-comm calls (a project rule).
- `message()` was removed (use `SetBasicMessageDialogText`). `C_ChallengeMode.GetCompletionInfo` was renamed
  to `GetChallengeCompletionInfo`.
- Legacy party globals are being moved to `C_PartyInfo.*`. The `Blizzard_DeprecatedPartyInfo` shims load only
  if the CVar `loadDeprecationFallbacks` is set.

## Testing CVars (not saved across restarts)
`secretCombatRestrictionsForced`, `secretEncounterRestrictionsForced`, `secretChallengeModeRestrictionsForced`,
`secretMapRestrictionsForced`, `secretPvPMatchRestrictionsForced`, `addonChatRestrictionsForced`,
`addonCombatRestrictionsForced`, `addonEncounterRestrictionsForced`.

## In-game tests to run (party with at least 1 other player, Forever client)
```
/run SetCVar("secretEncounterRestrictionsForced",1) SetCVar("secretMapRestrictionsForced",1) SetCVar("secretCombatRestrictionsForced",1)
/run for _,u in ipairs({"player","party1"}) do local n,r=UnitName(u) local g=UnitGUID(u) local _,c=UnitClass(u) print(u, issecretvalue(n), issecretvalue(r), issecretvalue(g), issecretvalue(c), canaccessvalue(g)) end
/run print(UnitFullName("party1"))
/run for i=0,5 do print(i, C_RestrictedActions.IsAddOnRestrictionActive(i)) end
/run SetCVar("secretEncounterRestrictionsForced",0) SetCVar("secretMapRestrictionsForced",0) SetCVar("secretCombatRestrictionsForced",0)
```
Expected (if the reading above is right): every `issecretvalue` prints `false` for party1. Run it a second time for real
inside a dungeon and during a boss pull, without the CVars.

## Design rules that follow
1. **Never use a value from a Unit* API as a table key or in a comparison without `canaccessvalue(v)` first.**
   If it is not accessible, queue the unit token and re-read it after `PLAYER_REGEN_ENABLED` or
   `ADDON_RESTRICTION_STATE_CHANGED` (state inactive).
2. Snapshot the roster **out of combat** (on GROUP_ROSTER_UPDATE and when entering the instance), not only at `ENCOUNTER_START`.
   ENCOUNTER_START is exactly when Encounter restrictions begin.
3. Never show a rating prompt or build UI during combat or an encounter. Defer it to regen-enabled.
