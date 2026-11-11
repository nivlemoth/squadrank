# TOC format: reference for SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/TOC_format
- https://warcraft.wiki.gg/wiki/Create_a_WoW_AddOn_in_15_Minutes
- Blizzard source, Gethe/wow-ui-source branch `forever` @ 4cd0ab7 (build 1.60.1.70888)

## Basics
- File `SquadRank/SquadRank.toc`: the folder and file names must match, or the addon is not detected.
- `## Directive: Value` lines. A plain `#` starts a comment. Other lines are files, loaded top to bottom.
- Only the first 1024 characters of a line are read.
- Most directives: a later line overrides an earlier one. **These append instead:** Dependencies, LoadWith,
  LoadManagers, SavedVariables, SavedVariablesPerCharacter, AllowLoadGameType, ExcludeLoadGameType.
- Display fields can be localized: `## Title-frFR: ...` (put the unlocalized one first).

## Interface numbers (wiki table, 2026-11-10)
| Game type | Interface |
|---|---|
| Midnight Standard (retail) | 120105 |
| Midnight Standard Test | 120107 |
| **Forever** | **16001** |
| Mists | 50504 |
| Cata | 40402 |
| Vanilla (Classic Era) | 11509 |

- A comma list has been allowed since 10.2.7: `## Interface: 16001, 120105`
- Check in game: `/dump select(4, GetBuildInfo())`
- The legacy SquadRank TOC says `110105`, which is out of date on both clients.

## Per-flavor TOC files (since 9.1.0)
- Game suffixes: `_Standard`, `_Forever` **or** `_Camelot`, `_Mists`, `_Cata`, `_Wrath`, `_TBC`, `_Vanilla`, ...
- Family suffixes: `_Mainline` (standard, **forever/camelot**, plunderstorm, wowhack) and `_Classic` (vanilla..mists).
- A game suffix beats a family suffix, and a family suffix beats the plain `.toc`.
- The wiki prefers one TOC with a comma-separated Interface list plus inline file conditions over separate TOC files.
- **Forever is in the Mainline family**, not Classic. That matches its API surface (see forever-vs-retail.md).

## Directives we will use
| Directive | Notes | Since |
|---|---|---|
| `Interface` | `16001` (plus `120105` if retail is also supported) | |
| `Title`, `Notes`, `Author`, `Version` | Version should start with a number for updaters | |
| `Category` | Collapsible AddOn List header | 11.1.0 |
| `IconTexture` / `IconAtlas` | AddOn List icon; IconTexture wins | 10.1.0 |
| `AddonCompartmentFunc` (+`OnEnter`/`OnLeave`) | Global function name. The wiki says it "applies to Midnight and Forever". Forever has `Blizzard_Minimap/Camelot/AddonCompartment.xml` | 10.1.0 |
| `SavedVariables` | Account-wide: `WTF\Account\<acct>\SavedVariables\SquadRank.lua` | |
| `SavedVariablesPerCharacter` | Per-character file | |
| `LoadSavedVariablesFirst: 1` | SVs exist before any of our Lua runs. Cannot be switched off later in the file | 11.1.5 |
| `OptionalDeps` | e.g. `Ace3, LibDBIcon-1.0` when embedding | |
| `AllowLoadGameType` / `ExcludeLoadGameType` | Restrict to e.g. `camelot` / `standard`. **Wiki warning:** if no listed type is recognized, Allow is treated as satisfied; pair it with Exclude | 10.2.7 / 12.0.0 |
| `X-*` | Custom metadata, read with `C_AddOns.GetAddOnMetadata` | |
| `AllowAddOnTableAccess: 1` | Lets others read our `ns` via `C_AddOns.GetAddOnLocalTable`. **Do not set it** | 11.1.7 |

## Conditional file lines (11.1.5+)
```
Core.lua
Forever.lua  [AllowLoadGameType camelot][ExcludeLoadGameType standard, classic]
Retail.lua   [AllowLoadGameType standard]
```
- Variables `[Family]`, `[Game]`, `[TextLocale]` work in file paths. Since 12.1.7 they no longer work inside directives.
- `[RegionalTextLocale]` was added in 12.1.7 (Midnight and Forever).

## Restricted (not for third-party addons)
AllowLoad, LoadFirst, SavedVariablesMachine, UseSecureEnvironment, EscalateErrorDuringLoad.

## Unknowns (must verify in game)
- Whether the client accepts the `_Forever` suffix, `_Camelot`, or both. The wiki lists both, and Blizzard's own
  Forever TOCs use `camelot`, e.g. `Blizzard_GroupFinder_VanillaStyle.toc`: `## AllowLoadGameType: classic, camelot`.
  Test: ship `SquadRank_Camelot.toc` and `SquadRank_Forever.toc` with different `## Title:` values and see which
  one the AddOn List shows.
- The exact interface number on the live Forever client: `/dump select(4, GetBuildInfo())`
