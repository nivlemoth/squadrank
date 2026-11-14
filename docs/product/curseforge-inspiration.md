# CurseForge inspiration for 1.5

Updated 2026-11-13. This note records what SquadRank looked at on CurseForge, what it adopted in 1.5,
and what it deliberately left out. It is a design record, not a compatibility claim.

## Method and limits

- Research was **read-only**: public project pages, screenshots and documentation. No add-on code,
  art, icons, sounds, locale strings or saved-variable formats were copied.
- The main competitor study is [TheList analysis](../research/the-list-analysis.md)
  (TheList by Spinosaur, project 1786119, v0.5.10, All Rights Reserved).
- Other projects were used only for **general product patterns** that are common across large
  add-ons: a short post-update note, a single chat greeting, opt-in notification spam, and a clear
  settings entry point. No specific implementation was reproduced.
- SquadRank keeps its own name, logo, data model, code, text and licence.

## What 1.5 adopted

| Pattern seen on CurseForge | How SquadRank applies it | Where |
|---|---|---|
| A short "what's new" panel after a major update | One flat, skippable window per version with five headlines and a direct link to Settings | `UI/WhatsNew.lua`, `db.seenVersion` |
| A single friendly chat line on login | One line per session with the add-on icon, a short explanation and the `/sr` hint | `Core/Main.lua`, `L.MSG_HELLO` |
| Keep contextual notifications opt-in | Four alert contexts, each off by default, plus one shared cooldown | `Data/Alerts.lua`, `Track/ContextAlerts.lua` |
| Make the add-on easy to find again | `/sr whatsnew`, a Settings button, and a seven-line `/sr help` | `UI/Slash.lua`, `UI/Settings.lua` |
| Respect combat restrictions | Every window, toast and popup hides in combat and returns afterwards | all UI modules |

The emoji treatment is intentionally split: README, release notes and product docs use emoji for
readability, while in-game text uses Blizzard colour escapes and built-in textures. WoW Forever's
client fonts do not reliably render colour emoji, so shipping emoji as UI text would produce boxes
on some clients. No emoji font or texture pack is bundled.

## What was deliberately not adopted

- **No shared player database, sync or telemetry.** SquadRank stays local-only, as before.
- **No automatic upload, add-on channel or external service.**
- **No dependency on Ace3 or any third-party library.** The TOC loads only SquadRank files.
- **No "rate this add-on" nag or external link popup.** The About page has a copyable support
  address, nothing that opens a browser.
- **No second settings surface or command sprawl.** Existing commands stay; 1.5 adds one.
- **No copy of TheList's rating wording, colours, categories or icons.** The feature-gap matrix
  records the differences.

## Ideas kept for later (not in 1.5)

These appeared during the review but are out of scope for this release. They are not promises.

- A compact "recently met" strip on the Rate page.
- An optional per-encounter summary card after a dungeon.
- Explicit, user-initiated export/import of ratings (would need a schema decision and a privacy
  review first).
- Minimap badge variants for "players waiting" versus "new version".

Any of these would need the same bar as 1.5: small, testable, backward-compatible, and free of new
dependencies or network calls.

## References

- [TheList analysis](../research/the-list-analysis.md)
- [Feature gap matrix](feature-gap-matrix.md)
- [SquadRank roadmap](squadrank-roadmap.md)
- [Decisions 84–91](../DECISIONS.md)
- [Manual test plan](../testing/manual-test-plan.md)
