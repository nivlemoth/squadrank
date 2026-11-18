# Ace3, community libraries and the BigWigs packager: reference for SquadRank

Sources (accessed 2026-11-10):
- https://warcraft.wiki.gg/wiki/Ace3_for_Dummies (last edited April 2025; adapted from older Fandom content and
  has inconsistent interface numbers)
- https://www.wowace.com/projects/ace3/pages/getting-started (an old page: its example uses `## Interface: 40000`)
- https://github.com/BigWigsMods/packager (README)
- Web search for Ace3 / LibDBIcon Forever support: **nothing found**. The latest Ace3 found was r1390 (2026-02-03, "retail 12.0.1").

## Ace3 modules
| Module | Purpose | Use in SquadRank? |
|---|---|---|
| AceAddon-3.0 | `NewAddon(name, mixins...)`, lifecycle `OnInitialize` (once, SVs ready) / `OnEnable` / `OnDisable` | yes |
| AceDB-3.0 | `New("SquadRankDB", defaults, true)`; scopes `char, realm, class, race, faction, factionrealm, profile, global`; defaults are not written to disk; profiles | yes: `global` for player data, `profile` for UI settings |
| AceDBOptions-3.0 | ready-made profile management panel | optional |
| AceConsole-3.0 | `Print`, `RegisterChatCommand("squadrank", "SlashHandler")` (no slash) | yes |
| AceEvent-3.0 | `RegisterEvent` (method named after the event by default; the event name is the first arg), `RegisterMessage`/`SendMessage` for in-client messages; unregisters on disable | yes |
| AceConfig-3.0 / AceConfigDialog-3.0 | declarative options table (`type="group"`, `args`, `get`/`set`), `RegisterOptionsTable`, `AddToBlizOptions` | yes, for settings |
| AceTimer-3.0 | timers | optional (`C_Timer` is enough) |
| AceBucket-3.0 | coalesce bursty events | useful for GROUP_ROSTER_UPDATE |
| AceGUI-3.0 | widget toolkit | **no**: use Blizzard ScrollBox / templates for the main list |
| AceSerializer-3.0 | serialize tables to strings | for export/import (plus LibDeflate for encoding) |
| AceComm-3.0 | addon messages between players | **no**: project rule, no network calls |
| AceHook-3.0 | safe hooking | probably not needed |
| AceLocale-3.0 | localization | later (v1.0) |

## Embedding
- Libraries go in `Libs/`. Load LibStub first, then each lib's `.xml`, usually via an `embeds.xml` the TOC lists.
- `## OptionalDeps: Ace3` lets a standalone Ace3 install be used instead of the embedded copy.
- Embedded libs run under **our** TOC, so their own Interface number is irrelevant. Only their **runtime API
  calls** must exist in Forever. That is an unknown and must be tested: load them and check for errors with
  `/console scriptErrors 1` or BugSack.

## Other community libraries to consider
| Lib | Replaces |
|---|---|
| LibDataBroker-1.1 + LibDBIcon-1.0 | the custom minimap button. LibDBIcon handles shape, drag, hide and position saving |
| LibDeflate (+ AceSerializer) | the legacy `:`/`;` export string (which breaks on realm names containing `:` or `-`) |
| LibSharedMedia-3.0 | only if we offer font or texture choices (probably not for the MVP) |
| CallbackHandler-1.0 | comes with Ace3. Use it for module events, or Blizzard's `CallbackRegistryMixin` |

Alternative with no libraries: Blizzard's Addon Compartment + Settings API + ScrollBox + `CallbackRegistryMixin` cover
most of the same ground (see widget-api-and-blizzard-ui.md). **This is a decision for Nivlemoth (see the questions).**

## BigWigs packager (`release.sh`)
- Builds a zip from git and can upload to CurseForge (`CF_API_TOKEN`), WoWInterface (`WOWI_API_TOKEN`),
  Wago (`WAGO_API_TOKEN`) and GitHub releases (`GH_API_TOKEN`). Tokens go in `.env` or the environment.
- `.pkgmeta`: `externals` (pull libs from git or svn at build time instead of committing them), `ignore`,
  `move-folders`, `plain-copy`, `enable-nolib-creation` (nolib zips go to GitHub only).
- Keywords: `@project-version@`. Blocks: `--@debug@ ... --@end-debug@` (stripped from release builds),
  `do-not-package`, `alpha`, `no-lib-strip`, `retail` / `version-*`. In a TOC write them as `#@keyword@`.
- Multi-flavor: one TOC per game type, or a single TOC with `## Interface-[Type]:` lines plus `-S`.
  **The README lists classic/bcc/wrath/cata/mists, not forever/camelot**, so Forever is unknown and
  needs testing with `-S`, or we ship a hand-written TOC.
- `-g` sets the game version(s) for upload.
- Local flags: `-d` skip upload, `-z` skip zip, `-l` skip localization, `-o` overwrite the package dir.
- GitHub Actions: `BigWigsMods/packager@v2` with `args:`.
- **Rule conflict:** uploading is a network action by the build tooling, not by the addon, so it does not break
  "no network calls from the addon". Still, publishing is outward-facing, so ask before any upload.
