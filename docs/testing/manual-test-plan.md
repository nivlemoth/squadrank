# Manual test plan: contextual alerts

Created 2026-11-13 for the first contextual-alert milestone. This plan is **release-blocking** for
the milestone but has **not been executed**: no WoW Forever client is available in this
environment. Every case below is therefore marked `NOT EXECUTED`.

`TESTING.md` remains the full release checklist. This document adds the focused cases for the new
whisper, target, trade and duel alerts, plus regression checks for the paths they touch.

## How to record a result

- **PASS** — observed exactly the expected result.
- **FAIL** — anything else; capture `/sr debug` output and a screenshot.
- **BLOCKED** — the step could not be performed (missing second account, event unavailable).
- **NOT EXECUTED** — not yet tried. All cases start here.

Use a **copy** of the SavedVariables file when testing migration or destructive paths. Never test
purge or import against a file you cannot restore.

## Prerequisites

1. Two WoW Forever accounts, or one account and a cooperative friend. The second player must be
   saved in SquadRank with at least one rating, and ideally a second saved player on the avoid list.
2. `/console scriptErrors 1` before the session.
3. A quiet location where a duel and a trade can be started, and a training dummy for combat.
4. Note the current settings in `/sr` → Settings so they can be restored afterwards.

## A. Defaults and settings surface

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-01 | Install the build, log in, open `/sr` → Settings | A section **Heads-up outside groups** with four switches (whisper, target, trade, duel) and a **Heads-up cooldown** stepper showing **60**. All four switches are **off**. | NOT EXECUTED |
| CA-02 | Open Blizzard's AddOns options → SquadRank | The same four switches and cooldown slider, with the same values as the in-window page. | NOT EXECUTED |
| CA-03 | Toggle whisper on in Blizzard's panel, close it, open `/sr` → Settings | The in-window whisper switch is on. Toggle it off in the window and re-open Blizzard's panel; it is off there too. | NOT EXECUTED |
| CA-04 | Set the cooldown stepper to 0, then 180, then try to go past each end | It stops at 0 and 180; the value survives a `/reload`. | NOT EXECUTED |
| CA-05 | `/sr debug` | The settings block lists the four alert switches and the cooldown. No player names appear. | NOT EXECUTED |

## B. Whisper alert

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-06 | With **all four switches off**, have the saved player whisper you | No context toast. Normal chat still shows the whisper. | NOT EXECUTED |
| CA-07 | Turn **whisper alerts** on; `/reload`; whisper again | Within a second, a toast titled **"A saved player whispered you"**, with the player's name, reputation label, rating count/role line and top tag. It fades after the configured toast duration. | NOT EXECUTED |
| CA-08 | Click the toast | The SquadRank window opens on the Players page with that player's history drawer open. | NOT EXECUTED |
| CA-09 | Whisper again inside the 60-minute cooldown | No new toast. The chat line still appears. | NOT EXECUTED |
| CA-10 | Set cooldown to 0, whisper three times | A toast each time (the shared toast queue may stack or replace, but each whisper is accepted by the alert rule). | NOT EXECUTED |
| CA-11 | Set cooldown to 1; wait 61 seconds; whisper | The toast appears again. | NOT EXECUTED |
| CA-12 | Whisper from a player who is **not saved**, then from a saved player with **no ratings** | No alert for either. Confirm neither created a player record. | NOT EXECUTED |
| CA-13 | Whisper text contains `\|Hitem:...\|h`, newlines, and 4,000 characters | Chat may render it normally; SquadRank does not store it, and `/sr debug` contains no fragment of the text. | NOT EXECUTED |
| CA-14 | `/reload`, then whisper again inside the old cooldown window | A toast appears: the cooldown is in memory and resets on reload. (This is intended.) | NOT EXECUTED |

## C. Target alert

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-15 | Turn **target alerts** on, whisper alerts off; target the saved player | One toast titled **"You targeted a saved player"**. | NOT EXECUTED |
| CA-16 | Target the same player repeatedly, then another unit and back, inside the cooldown | No additional toasts. | NOT EXECUTED |
| CA-17 | Target an unsaved player, then a saved but unrated player | No toast. | NOT EXECUTED |
| CA-18 | Target the saved player while in combat | No toast during combat; if the event was queued, it resolves when combat ends. No database read occurs mid-combat. | NOT EXECUTED |
| CA-19 | Target a saved, avoided player with target alerts off | A red avoid-flavoured toast (because `avoidWarning` is on), subject to cooldown. | NOT EXECUTED |

## D. Trade and duel alerts

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-20 | Turn **trade alerts** on; have the saved player open a trade with you | A toast titled **"Trade request from a saved player"**. Declining the trade does not remove the toast. | NOT EXECUTED |
| CA-21 | Repeat inside the cooldown | No second toast. | NOT EXECUTED |
| CA-22 | Turn **duel alerts** on; have the saved player challenge you to a duel | A toast titled **"Duel request from a saved player"**. | NOT EXECUTED |
| CA-23 | Repeat inside the cooldown | No second toast. | NOT EXECUTED |
| CA-24 | Have an unsaved player request a trade and a duel | No toast for either. | NOT EXECUTED |
| CA-25 | Receive a trade or duel request in combat | No toast until combat ends; then at most one, subject to cooldown. | NOT EXECUTED |

## E. Avoid-list exception

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-26 | Put the saved player on the avoid list; turn **all four** context switches off; keep **avoid warning** on; whisper from them | A red toast with the avoid label and sound, even though whisper alerts are off. | NOT EXECUTED |
| CA-27 | Repeat the whisper inside the cooldown | No second toast. The avoid exception does not bypass the cooldown. | NOT EXECUTED |
| CA-28 | Turn **avoid warning** off and repeat | No toast at all (the avoid exception depends on `avoidWarning`; the context switch is still off). | NOT EXECUTED |
| CA-29 | Turn whisper alerts on as well and repeat | A normal context toast; the avoid record still shows the red avoid styling. | NOT EXECUTED |

## F. Combat, queue and reload behaviour

| ID | Steps | Expected | Status |
|---|---|---|---|
| CA-30 | Pull a dummy; while in combat, have the player whisper, target you, and request a trade | No toasts and no window appears during combat. `/sr debug` does not show a database read error. | NOT EXECUTED |
| CA-31 | Leave combat | At most one queued context toast appears per player/context key, subject to cooldown. Nothing is replayed twice. | NOT EXECUTED |
| CA-32 | Queue several whispers from different saved players in combat, then leave combat | Toasts appear for eligible players, up to the shared queue limit; older ones may be dropped rather than overflowing. | NOT EXECUTED |
| CA-33 | `/reload` while a context toast is visible | The toast disappears; no error. The alert cooldown is forgotten. | NOT EXECUTED |
| CA-34 | `/sr selftest` after the above | No new failures. Existing rows for events, settings and database still PASS. | NOT EXECUTED |

## G. Regressions in touched paths

| ID | Steps | Expected | Status |
|---|---|---|---|
| REG-01 | Form a group with the saved player and a stranger | Normal join toast appears for the rated player only; no context alert fires merely from joining. | NOT EXECUTED |
| REG-02 | Have an avoided player join the group | The existing red avoid warning appears once, with sound; context alerts do not duplicate it. | NOT EXECUTED |
| REG-03 | Hover a rated player's unit frame | The existing SquadRank tooltip line still appears; no context toast fires from hovering. | NOT EXECUTED |
| REG-04 | Complete a short dungeon and leave the group | The "Rate your squad" alert and rating flow behave exactly as before. | NOT EXECUTED |
| REG-05 | Open and close every page (Rate, Players, Runs, PvP, Stats, Settings, About) | No layout change, no Lua error, no unexpected scroll jump. | NOT EXECUTED |
| REG-06 | Switch the game language to German (or any non-English locale), `/reload`, repeat CA-07 | The four toast titles and all six settings labels are translated and fit their controls; no English fallback appears for the new keys. | NOT EXECUTED |
| REG-07 | Load a schema-1 SavedVariables file from the previous build | All players, runs, ratings, notes and settings are intact. The four new switches default to off and the cooldown to 60. | NOT EXECUTED |
| REG-08 | Load a file with `schema = 99` | SquadRank opens read-only, prints its warning, and does not modify the file. | NOT EXECUTED |
| REG-09 | `/sr purge <saved player>` then whisper from that name | No alert; the name is unknown again. | NOT EXECUTED |

## Automated coverage (executed in this environment)

These do not replace the in-game cases, but they pin the logic:

| Area | Test file | Result |
|---|---|---|
| Defaults are off, cooldown 60, clamp 0–180 | `spec/alerts_spec.lua` | PASS (in `tools/check.sh`) |
| Name resolution: exact, case-insensitive, ambiguous, blank | `spec/alerts_spec.lua` | PASS |
| Opt-in requirement for rated players | `spec/alerts_spec.lua` | PASS |
| Unrated non-avoided player never alerts | `spec/alerts_spec.lua` | PASS |
| Cooldown shared across contexts; zero disables it | `spec/alerts_spec.lua` | PASS |
| Avoid exception, and its dependence on `avoidWarning` | `spec/alerts_spec.lua` | PASS |
| Unknown player/context; reset | `spec/alerts_spec.lua` | PASS |
| All 18 settings controls register (mock) | `spec/smoke_spec.lua` | PASS |
| TOC load order, event wiring, out-of-combat queue | `spec/smoke_spec.lua` | PASS |
| Formatting and lint (58 → 61 files) | `tools/check.sh` | PASS, 0 warnings |

Static and mock tests prove load order and pure logic against a fake client. They do **not** prove
that Blizzard's event payloads, secret values, toast anchoring, or sound behaviour match the mock.
Only section A–G above can do that.
