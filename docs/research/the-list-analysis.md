# “The List” research and evidence log

Researched 2026-11-13 for the SquadRank product review. This document records what was
verified, how it was verified, and what SquadRank should and should not take from it.

## Identity of the competitor

| Field | Finding | Evidence |
|---|---|---|
| Display name | **TheList** (the addon folder and commands use `YouJustMadeTheList`) | Distributed `.toc` and Lua files |
| Author | **Spinosaur** | CurseForge project metadata |
| CurseForge project | **1786119**, slug `you-just-made-the-list` | CurseForge page/API metadata |
| URL | https://www.curseforge.com/wow/addons/you-just-made-the-list | CurseForge |
| Game client | **Forever 1.60.1** (same target as SquadRank) | Project description and distributed package |
| Distributed build inspected | **v0.5.10**, 19 public versions, latest dated 2026-11-11 | CurseForge metadata + downloaded package |
| Licence | **All Rights Reserved** | CurseForge project metadata |
| Similar-name warning | Not “The Sh*t List” by Hexx98 | CurseForge search results |

The package was downloaded read-only (`TheList-0.5.10.zip`, file 9550763) to verify behaviour.
It was not executed, loaded into a client, or copied into SquadRank. Only filenames, settings,
event names, command names, and user-facing behaviour are referenced here.

**Evidence levels used below**

- **Documented** — stated on the CurseForge description or project metadata.
- **Observed** — present in the distributed Lua/XML/TOC that ships in `TheList-0.5.10.zip`.
- **Inferred** — a reasonable product conclusion from the observed implementation or UI.
- **Unverified** — needs an in-game check, a native-speaker review, or a source we could not reach.

## What TheList does

### Verdict and history model

- **Observed:** A player record holds `Nice` and `Naughty` counts, a list of incidents, and an
  optional profile snapshot. A verdict is a count, not a run-based score.
- **Observed:** Each incident can carry a comment and is shown in a dossier/journal with the
  player's encounter history.
- **Observed:** Some founder characters are seeded as hardcoded Nice entries.
- **Observed:** A profile snapshot can include level, race, class, faction, guild, guild rank, and
  first-seen level.
- **Inferred:** The model is optimised for “what is this person's reputation?” rather than “how did
  they perform in this particular group?”.

### Capture workflow

- **Observed:** Nice and Naughty buttons create a new incident. A fast-add path uses a
  configurable Ctrl/Shift/Alt modifier.
- **Observed:** A fast add offers an Undo action.
- **Observed:** Right-click menus on chat names and unit frames open the dossier or add a verdict.
- **Observed:** Keybinds and macros exist for “mark target Nice”, “mark target Naughty”, opening the
  dossier, and toggling the list.
- **Observed:** Commands include `/thelist`, `/listnice`, `/listnaughty`, `/quicknice`,
  `/quicknaughty`, `/listdossier`, `/listjournal`, and `/listledger`.
- **Inferred:** The design favours speed over structured post-run evaluation. A verdict can be
  recorded in one click, at any time, without a group ending.

### Browsing and comparison

- **Observed:** A dossier shows one player's history; a journal lists players; a ledger compares
  contributors' scores.
- **Observed:** Alphabetical browsing with 8-row pagination was found in the distributed UI.
- **Observed:** No visible delete, purge, export, import, or free-text search path was found in the
  distributed Lua.
- **Inferred:** The review flow is fast for a known name but weaker for finding an old player,
  removing bad data, or moving a journal between machines.

### Alerts

- **Observed:** Six alert types: incoming whisper, party join, raid join, targeting a player,
  incoming trade request, and incoming duel request.
- **Observed:** Alerts are on by default for every type in a fresh profile.
- **Observed:** A per-player, cross-context cooldown of **60 minutes** is persisted in the saved
  variables. Old timestamps are pruned at login.
- **Observed:** Up to **5** alerts wait in a queue; duplicate players are suppressed while queued.
- **Observed:** Four sound choices: off, soft click, whisper chime, ready check.
- **Observed:** `TRADE_REQUEST` and `DUEL_REQUESTED` are the request events; `CHAT_MSG_WHISPER`
  supplies the whisper sender; `PLAYER_TARGET_CHANGED` supplies the target.
- **Observed:** A toast lasts about 5 seconds and pauses while hovered; clicking opens the dossier.
- **Inferred:** Default-on alerts plus a per-player cooldown favour “never miss a known player” over
  “stay quiet”. SquadRank should keep the opposite default.

### Chat and social features

- **Observed:** A chat filter prepends a green `+` or a red minus badge to messages from known
  players.
- **Observed:** Addon-message score sharing exists: one vote per contributor/subject, revisioned
  packets, channel limits, caps of 10,000 subjects and 500 sources.
- **Observed:** An optional first-save whisper can be sent to a newly recorded player, limited to
  five per minute and once per player.
- **Observed:** An optional “ask to kick Naughty party members” workflow exists.
- **Observed:** Retail and Forever journals are kept separate.
- **Inferred:** These are strong social features, but they conflict with SquadRank's current
  no-network, no-player-data-sharing, no-addon-message design. They are not candidates for a small
  first milestone.

## What TheList does well

1. **Immediate capture.** A verdict is one click away from a unit frame, chat name, or keybind.
2. **Undo for mistakes.** Destructive-feeling actions are reversible.
3. **Context alerts.** Whispers, targets, trades, and duels are exactly the moments when a
   reputation memory is useful.
4. **Incident provenance.** A verdict has a time, place, and optional comment.
5. **Visible in the chat.** The `+`/minus badge makes reputation part of the normal chat flow.
6. **Low-friction defaults.** A new user gets useful alerts without opening settings.

## What SquadRank should not copy

- **No code, art, icons, sounds, documentation, or branding.** TheList is All Rights Reserved.
  SquadRank implementations must be original and independently written.
- **No founder list or seeded characters.** Reputation must come from the user's own ratings.
- **No addon-message score sharing, first-save whispers, or kick prompts.** They conflict with the
  project's privacy and no-network rules, and some require new dependencies or social contracts.
- **No “The List” naming or affiliation claim.** SquadRank stays SquadRank.
- **No unbounded incident history.** SquadRank already caps ratings per player and prunes old data.

## Weaknesses and opportunities for SquadRank

| TheList observation | SquadRank opportunity |
|---|---|
| Verdict counts, no run context | Keep run-based ratings: one rating per run, with boss/quest/duration context. |
| Free-text incidents, no structured tags | Keep the 16 structured tags plus an optional sanitised note. |
| Alerts default on for all six triggers | Make every new context opt-in, with a configurable per-player cooldown. |
| 60-minute cooldown fixed | Let the user choose 0–180 minutes. |
| Alerts warn even about unrated names? Record must exist | Alert only for rated players, plus avoided players as a safety exception. |
| Alphabetical browsing, 8-row pages | Keep search, filters, sorting, and the Players/Runs/PvP split. |
| No visible purge/export/import | Keep purge; plan validated export/import later. |
| Hardcoded founder characters | Never seed reputation. |
| All Rights Reserved | Keep SquadRank original and independently licensed. |

## Limitations of this research

- **No in-game execution.** The package was not loaded in the Forever client. Event payloads,
  secret-value behaviour, and UI rendering are source-observed, not runtime-verified.
- **CurseForge subpages and download endpoints returned 403** during research. The main project
  page, API metadata, and the edge CDN package were reachable.
- **The distributed Lua is minified/compacted in places.** Line-level conclusions are limited to the
  behaviour that is readable in the shipped file.
- **Translations and client language coverage of TheList were not audited.**
- **No claim is made about TheList's internal data safety or future versions.**

## Product conclusion

TheList's strongest ideas for SquadRank are **contextual, opt-in alerts**, **fast capture with
undo**, and **incident provenance**. SquadRank's strongest differentiators are its **run-based,
structured, recency-weighted reputation model**, **GUID-first identity**, **data safety**, **search
and filtering**, and **localisation**. The first milestone therefore adds contextual alerts without
adopting TheList's code, defaults, social features, or data model.
