# SquadRank vs TheList: feature-gap matrix

Updated 2026-11-13 after the first contextual-alert milestone. “TheList” findings are
source-observed from the distributed v0.5.10 package unless marked otherwise. “SquadRank” reflects
the working tree, not a released build.

Legend: **Yes** = implemented; **Partial** = some support but a meaningful gap remains;
**No** = not present. Priority is for SquadRank: **P0** = next release, **P1** = near-term,
**P2** = later/optional, **No** = deliberately out of scope.

## Identity and data model

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| Player identity | Name-based record keys in the observed UI | GUID-first with name fallback and merge | SquadRank is stronger; keep it. | — |
| Verdict model | Nice/Naughty counts plus incidents | 1–5 score per run, 16 tags, optional note | Different product models; keep run-based ratings. | — |
| One rating per run | No run concept | Yes, enforced by `runId` | Strength to preserve. | — |
| Structured tags | No | 16 tags, positive/negative, filterable | Strength to preserve. | — |
| Notes | Incident comments | Sanitised 140-character note per rating | Strength; never shared. | — |
| Role tracking | Profile metadata only | Role per rating, role averages | Strength. | — |
| Incident provenance | Time, location, comment per incident | Run ID, run date, instance, boss/quest context | Add richer per-incident source later. | P1 |
| Recency weighting | No | 90-day half-life summary | Strength. | — |
| Reputation labels | Implicit Nice/Naughty | Trusted/Mixed/Caution/New with threshold | Strength. | — |
| Founder/seeded entries | Hardcoded Nice founders | None | Deliberately not copied. | No |
| Profile enrichment | Level, race, class, faction, guild, rank | Level, class, faction, role; no race/guild snapshot | Optional enrichment later. | P2 |

## Capture and workflow

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| One-click score | Yes, verdict buttons | Yes, five score buttons per card | Both fast; SquadRank is post-run oriented. | — |
| Rate after group ends | Manual only | Persistent “Rate your squad” alert | Strength. | — |
| Fast-add modifier | Configurable Ctrl/Shift/Alt | No | Add a configurable quick-rating modifier later. | P2 |
| Undo destructive action | Yes for fast add | No | Add a short-lived undo for delete/purge and quick ratings. | P1 |
| Chat-name context menu | Yes | No (unit-frame menu only) | Add chat-name menu if the API is verified. | P2 |
| Unit-frame context menu | Yes | Yes, party/raid/target menus | Strength. | — |
| Keybinds / macros | Yes | No | Add optional keybinds after the capture flow stabilises. | P2 |
| Quick corner buttons | Yes, draggable Nice/Naughty | No | Consider an optional compact quick bar. | P3 |
| Batch rating | No | Yes, one window for several runs | Strength. | — |
| Rating without a group | Possible via dossier | Yes, `/sr rate <name>` | Strength. | — |

## Browsing and data management

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| Search players | No visible path | Yes, name search | Strength. | — |
| Filter by label/role/tag/type | No | Yes | Strength. | — |
| Sort | Alphabetical only | Score, status, last seen | Strength. | — |
| Pagination | 8-row alphabetical pages | ScrollBox/recycled rows for full list | Strength. | — |
| Player history | Dossier | History drawer with run-by-run ratings | Strength; add provenance later. | — |
| Run history | No run concept | Runs page with type, bosses, wipes, quests | Strength. | — |
| PvP separation | Separate journal by client, not by content | Dedicated PvP page and crowd rules | Strength. | — |
| Delete one player | No visible path | Yes, purge with exact-name handling | Strength. | — |
| Delete all data | No visible path | Yes, typed confirmation | Strength. | — |
| Export | No visible path | No | Add a validated, human-readable export. | P1 |
| Import | No visible path | No (1.x importer existed earlier) | Add validated import with preview and rollback. | P1 |
| Backup before migration | Unknown | Yes, one backup | Strength. | — |
| Read-only on newer schema | Unknown | Yes | Strength. | — |
| Pruning | Unbounded incidents observed | Runs, ratings per player, stale players, crowd data | Strength. | — |

## Alerts

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| Group-join alert | Yes, party and raid | Yes, one toast per group session | Partial parity. | — |
| Avoid-list warning | No equivalent | Yes, red warning even when join toasts are off | Strength. | — |
| Whisper alert | Yes, on by default | **Yes, opt-in** | Added in this milestone. | — |
| Target alert | Yes, on by default | **Yes, opt-in** | Added in this milestone. | — |
| Trade-request alert | Yes, on by default | **Yes, opt-in** | Added in this milestone. | — |
| Duel-request alert | Yes, on by default | **Yes, opt-in** | Added in this milestone. | — |
| Per-player cooldown | Yes, fixed 60 minutes, persisted | Yes, configurable 0–180 minutes, in memory | Configurable is stronger; persistence is a later option. | P2 |
| Alert queue | Yes, 5 items | Yes, existing 5-row/common toast queue | Shared queue; dedupe through cooldown. | — |
| Queue duplicate suppression | Yes | Yes (in-memory cooldown) | Strength for the session. | — |
| Sound choice | Four choices | One on/off switch, fixed per toast kind | Add per-alert or per-sound choice later. | P2 |
| Click alert to open history | Yes | Yes | Strength. | — |
| Alerts respect combat | Not audited | Yes, database reads deferred; toasts wait | Strength. | — |
| Alert only for known players | Record must exist | Rated or avoided only | Avoids noise about strangers. | — |
| Alert digest / quiet hours | No | No | Optional later; avoid scope creep. | P3 |

## Chat, social and sharing

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| Chat reputation badge | Yes, `+`/minus filter | No | Consider opt-in badge after API verification. | P2 |
| Addon-message score sharing | Yes, revisioned, capped | No | Deliberately out of scope: no network/player-data sharing. | No |
| First-save whisper | Yes, rate-limited | No | Deliberately out of scope: no outgoing whispers. | No |
| Ask to kick Naughty members | Yes | No | Deliberately out of scope for now; social/automation risk. | No |
| Share a summary | No visible path | Yes, opt-in one-line copy, never notes | Strength; manual copy only. | — |
| Telemetry | Not audited | None | Keep none. | No |

## Platform, quality and operations

| Capability | TheList | SquadRank | Gap / decision | Priority |
|---|---|---|---|---|
| Forever 1.60.1 support | Yes | Yes, `## Interface: 16001` | Parity. | — |
| Retail support | Yes, separate journal | No, Forever only | Do not add without an approved plan. | No |
| Third-party libraries | Unknown | Zero | Keep zero. | — |
| Localisation | Not audited | 11 catalogues, fallback and validation | Strength. | — |
| In-game validation | Assumed by author | Automated fake-client only; in-game checklist pending | Needs manual execution. | P0 for release |
| Automated tests | Unknown | 155 pure-Lua/smoke tests | Strength. | — |
| Static checks | Unknown | stylua + luacheck, 0 warnings | Strength. | — |
| Debug report | Unknown | Counts only, names scrubbed | Strength. | — |
| Schema/versioning | Unknown | Schema 1, migration, backup, read-only guard | Strength. | — |

## Summary

SquadRank already leads on **structured reputation, identity safety, search/filtering, data
protection, localisation, and testability**. TheList leads on **immediate capture**, **undo**,
**chat presence**, and **default-on context alerts**. This milestone closes the most useful alert
gap while deliberately keeping SquadRank quieter and more private. The next highest-value gaps are
**undo for destructive actions**, **richer incident provenance**, and **validated export/import**.
