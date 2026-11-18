# WoW Forever vs retail (Midnight): what applies to SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever
- https://warcraft.wiki.gg/wiki/TOC_format
- https://news.blizzard.com/en-us/article/24315820/world-of-warcraft-forever-goes-live-globally-november-4
- Blizzard source, Gethe/wow-ui-source: `forever` @ 4cd0ab7 = **1.60.1 (70888)**, committed 2026-11-10;
  `live` @ 297d7aa = **12.1.5 (70783)**, committed 2026-11-04
- Third-party guide sites turned up in search; they are **not** used as sources (unverified, partly promotional).

## What Forever is
- A standalone branch of WoW, released 2026-11-04, running alongside retail and Classic. Its design roots are in
  Vanilla ("crunchy systems, an emphasis on community building over auto-matchmaking").
- Internal game type name **Camelot**. TOC suffix `_Forever`/`_Camelot`. **Interface 16001**. **Mainline family.**
- Its client is built on the modern engine: it has the 12.x API surface, including secret values and C_RestrictedActions.

## Verified (from source): the API surface is the same as retail for everything we use
- Diffing all `Name`/`LiteralName` entries in Blizzard_APIDocumentationGenerated gives 334 extra in Forever (Vanilla-era
  systems: pet happiness, ammo, resistances, defense skill, `C_LFGList` roles, raid list, voice providers)
  and 18 only in live (mostly constants, e.g. `RecentAlliesFriendTag`). Nothing SquadRank depends on is missing.
- Every unit, instance, encounter and secret API listed in api-verified.md exists in both clients with identical flags.
- **Difference found:** `ENCOUNTER_END` has a 6th payload field `encounterUnitStatus` in live and not in Forever. Read
  only the first 5 fields.
- `Blizzard_RecentAllies` loads on `mainline`, which includes Forever. `Blizzard_GroupFinder_VanillaStyle` loads on
  `classic, camelot`, so Forever uses the Vanilla-style group finder (a listing board), not the retail
  premade/queue UI.
- Forever has its own override files: `Blizzard_Minimap/Camelot/AddonCompartment.xml`,
  `Blizzard_FrameXML/Camelot/InstanceDifficultyOverrides.lua` (difficulty is shown as 5/10/20/40 players only).

## Game-content differences that change the design
| Topic | Retail | Forever (wiki) | Impact on SquadRank |
|---|---|---|---|
| Classes | 13, incl. DK, DH, Monk, Evoker | 9: Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior | Do not hardcode class lists. Use `classFilename` + `C_ClassColor` |
| Races | all | Vanilla races + "Skyborne" (both factions) | none |
| Realms | many, cross-realm | **one "mega-realm" per ruleset per region** (Normal/PvP/RP/RP-PvP, Hardcore later) | Realm names still exist in GUIDs and names, so keep the Name-Realm key |
| Factions | cross-faction groups | Alliance / Horde; cross-faction grouping not stated | Store faction as an attribute, **not part of the key** |
| Level | 90 cap, scaling | cap 60, "no level scaling" | Store the player's level at the time of the run |
| Dungeons | Normal/Heroic/Mythic/M+ | level-banded dungeons (10-39, 40-60) | Legacy "Mythic+N from difficultyID" logic is wrong for both clients |
| Raids | LFR..Mythic | Barrow Deeps (10), Hyjal Summit (20), Onyxia (40). **Raids open 2026-12-09** | Raid support can wait until after the MVP |
| Group finder | queue (LFD) + premade | Vanilla-style listing board | `LFG_COMPLETION_REWARD` probably never fires (it is for queued runs), so we need our own "run complete" logic |
| Dual spec | yes | at level 40, swap outside combat | role can change between runs |
| Addon rules | 12.x restrictions | the wiki does not say; the source has the same restriction system | assume retail-equivalent restrictions |

## Unknowns (not answerable from docs, so they need in-game tests or Nivlemoth)
1. Does `C_RecentAllies.IsSystemEnabled()` return true on Forever? (TOC allows it; server may disable)
2. Are party/raid member names and GUIDs ever secret on Forever during an encounter or on a restricted map? (secret-values doc)
3. Does `ENCOUNTER_START`/`END` fire for Forever dungeon bosses? (Vanilla dungeons did not always have encounter IDs)
4. Is any Forever map flagged `Map` restricted (`C_RestrictedActions.IsAddOnRestrictionActive(4)` inside a dungeon)?
5. Which TOC suffix does the Forever client accept: `_Forever`, `_Camelot`, or both?
6. Is the folder `_forever_\Interface\AddOns`? Check the WoW install directory.
7. Is cross-faction grouping possible? (`UnitFactionGroup("party1")` ≠ the player's faction)
8. What does `GetRealmName()` return on a mega-realm, and does `UnitName("party1")` ever return a realm?
9. Do the embedded Ace3/LibDBIcon libraries run without errors on Forever?
10. Is retail support wanted at all, or only Forever? (question for Nivlemoth)

## Test script for the unknowns (Forever, in a party, ideally inside a dungeon)
```
/dump select(4, GetBuildInfo()), GetBuildInfo()
/run print(GetRealmName(), GetNormalizedRealmName(), UnitName("party1"))
/run print(UnitFactionGroup("player"), UnitFactionGroup("party1"))
/dump GetInstanceInfo()
/run for i=0,5 do print(i, C_RestrictedActions.IsAddOnRestrictionActive(i)) end
/run local f=CreateFrame("Frame") f:RegisterEvent("ENCOUNTER_START") f:RegisterEvent("ENCOUNTER_END") f:RegisterEvent("BOSS_KILL") f:SetScript("OnEvent",function(_,e,...) print(e,...) end)
```
