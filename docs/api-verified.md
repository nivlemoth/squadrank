# API verification log (per SKILL.md `wow-api-check`)

Checked 2026-11-10 against Blizzard_APIDocumentationGenerated in Gethe/wow-ui-source:
- **F** = `forever` branch @ 4cd0ab7, build 1.60.1 (70888)
- **L** = `live` branch @ 297d7aa, build 12.1.5 (70783)

Status: **verified-src** = present in the generated docs on both clients, signature as shown.
**undocumented** = a global absent from the generated docs (normal for old globals), so it **needs the in-game test**
before use. **in-game ✔** = John has confirmed it in game (no entries yet).

## Unit / group
| API | Status | Secret flag (F) | In-game test |
|---|---|---|---|
| `UnitName(unit)` → name, server | verified-src F+L | SecretWhenUnitNameIdentityRestricted | `/run print(UnitName("party1"))` |
| `UnitFullName(unit)` → name, server | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitFullName("party1"))` |
| `UnitGUID(unit)` → guid? | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitGUID("party1"))` |
| `UnitClass(unit)` → locName, classFile, classID | verified-src F+L | ret1 ConditionalSecret only | |
| `UnitFactionGroup(unit)` → tag, localized | verified-src F+L | none | |
| `UnitExists`, `UnitIsPlayer`, `UnitIsUnit` | verified-src F+L | | |
| `UnitGroupRolesAssigned(unit)` | verified-src F+L | SecretWhenUnitIdentityRestricted | `/run print(UnitGroupRolesAssigned("party1"))` (may be NONE in Forever, which has no queue roles) |
| `UnitTokenFromGUID(guid)` | verified-src F+L | SecretWhenUnitIdentityRestricted | |
| `GetPlayerInfoByGUID(guid)` → locClass, class, locRace, race, sex, name, realm, level? | verified-src F+L | none flagged | `/run print(GetPlayerInfoByGUID(UnitGUID("party1")))` |
| `IsInGroup()` | **undocumented** | | `/run print(type(IsInGroup), IsInGroup())` |
| `IsInRaid()` | **undocumented** | | `/run print(type(IsInRaid), IsInRaid())` |
| `GetNumGroupMembers()` | **undocumented** | | `/run print(type(GetNumGroupMembers), GetNumGroupMembers())` |
| `GetNumSubgroupMembers()` | **undocumented** (used by Blizzard CompactRaidFrames) | | `/run print(type(GetNumSubgroupMembers), GetNumSubgroupMembers())` |
| `GetRaidRosterInfo(i)` | **undocumented** (used by Blizzard) | | `/run print(GetRaidRosterInfo(1))` |
| `GetRealmName()` / `GetNormalizedRealmName()` | verified-src F+L | | `/run print(GetRealmName(), GetNormalizedRealmName())` |

## Instance / encounter
| API / event | Status | Notes |
|---|---|---|
| `IsInInstance()` | verified-src F+L | |
| `GetInstanceInfo()` → name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID, hasWorldTier | verified-src F+L | use **instanceID** for keys, not the name |
| `GetDifficultyInfo(id)` | verified-src F+L | |
| `GetZoneText()` | verified-src F+L | localized, so display only |
| `ENCOUNTER_START` (id, name, difficultyID, groupSize) | verified-src F+L | need to test that it fires in Forever dungeons |
| `ENCOUNTER_END` (+ success; L adds encounterUnitStatus) | verified-src F+L | **payload differs** |
| `BOSS_KILL`, `GROUP_ROSTER_UPDATE`, `GROUP_JOINED`, `GROUP_LEFT`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_REGEN_*`, `ADDON_RESTRICTION_STATE_CHANGED`, `LFG_COMPLETION_REWARD` | verified-src F+L | |

## Restrictions / secrets
| API | Status |
|---|---|
| `issecretvalue`, `canaccessvalue`, `issecrettable`, `canaccesstable` | verified-src F+L |
| `C_RestrictedActions.IsAddOnRestrictionActive(type)`, `.GetAddOnRestrictionState(type)`, `InCombatLockdown()` | verified-src F+L |
| `C_Secrets.ShouldUnitIdentityBeSecret` | verified-src F+L |

## UI / util
| API | Status | Notes |
|---|---|---|
| `C_Timer.After`, `C_Timer.NewTicker` | verified-src F+L | |
| `C_ClassColor.GetClassColor(classFile)` | verified-src F+L | |
| `C_AddOns.GetAddOnMetadata` | verified-src F+L | |
| `C_StringUtil.StripHyperlinks(text, ...)` | verified-src F+L | test: see widget-api-and-blizzard-ui.md |
| `GetCursorPosition`, `Region:GetEffectiveScale` | verified-src F+L | |
| `GetServerTime()`, `date()` | verified-src F+L | store `GetServerTime()` epoch, not formatted strings |
| `GetCVar`, `GetCVarBool` | verified-src F+L | |
| `Minimap:SetArchBlobRingScalar` | verified-src F (method **exists**) | so legacy `GetMinimapShape()` always returns "square" (bug) |
| CVar `minimapShapeshiftTracking` | **not found** anywhere in F source | legacy uses it, and it is meaningless |
| `strsplit` | **undocumented** (WoW Lua global) | `/run print(strsplit(":", "a:b"))` |
| `StaticPopup` dialog `.editBox` | **absent in F**; the field is `.EditBox` | test in widget-api-and-blizzard-ui.md |
| `table.getn` | Lua 5.0 compatibility, present in WoW's 5.1 | legacy calls it on a hash table, so it always returns 0 (bug) |

## C_RecentAllies (candidate dependency)
All functions listed in widget-api-and-blizzard-ui.md are verified-src F+L. **Runtime enablement on Forever is unknown:**
`/run print(C_RecentAllies.IsSystemSupported(), C_RecentAllies.IsSystemEnabled())`
