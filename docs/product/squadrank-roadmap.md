# SquadRank roadmap

Updated 2026-11-13. This plan follows the evidence in
[the-list-analysis.md](../research/the-list-analysis.md) and the
[feature-gap matrix](feature-gap-matrix.md). It is a product plan, not a promise of dates.
Every milestone must keep SquadRank's identity, its local-only data model, and its zero-library
rule; anything that would break one of those needs explicit approval first.

## Guiding constraints

- **SquadRank stays SquadRank.** No naming, branding, or affiliation that suggests it is TheList,
  a fork of it, or endorsed by its author.
- **Original work only.** No third-party code, art, icons, sounds, or documentation. TheList is
  All Rights Reserved and was inspected read-only for behaviour, not copied.
- **Local and quiet.** No telemetry, no network calls, no addon messages, no outgoing whispers,
  no player-data sharing.
- **Additive, reversible changes.** Schema changes need a migration, a backup, and a rollback
  note. Settings-only changes stay additive with defaults.
- **Small and testable.** Each milestone ships with pure-Lua tests, a static-check pass, and a
  manual in-game checklist that is clearly marked executed or not executed.
- **Performance in combat is sacred.** No database reads or writes in combat; no new per-frame
  work that cannot idle.

## Milestone status at a glance

| Milestone | Theme | Status | Depends on |
|---|---|---|---|
| M1 | Opt-in contextual alerts | **Implemented in the working tree; in-game validation pending** | — |
| M2 | Undo and incident provenance | Planned | M1 |
| M3 | Validated export/import and search polish | Planned | M2 |
| M4 | Optional chat presence and profile snapshot | Needs approval and API verification | M2 |
| M5 | Keybinds, macros and a compact quick bar | Planned | M2, M3 |

M1–M3 are the recommended path. M4 and M5 are optional and gated (see the end of this document).

## M1 — Opt-in contextual alerts (implemented)

**Problem.** SquadRank tells you when a rated player *joins a group*, but not when one whispers,
is targeted, or asks to trade or duel. TheList covers those moments and is the main reason players
keep it installed alongside a reputation addon.

**Scope shipped**

- Four contexts: incoming whisper, target change, incoming trade request, incoming duel request.
- Each context has its own setting, **off by default**.
- A single per-player cooldown across all contexts, configurable from 0 to 180 minutes
  (default 60). The cooldown table is in memory only and resets on reload.
- Avoided players alert even when the per-context switch is off, as long as the existing
  `avoidWarning` setting is on. They still obey the cooldown.
- Unrated, non-avoided players never alert.
- The whisper message body is never read, logged, or stored. Only the sender's name is used to
  find an existing record.
- All database reads are deferred out of combat through the existing event queue.
- Clicking the toast opens the player's history drawer.

**Acceptance criteria**

1. With every new switch off, no context alert appears for a rated player.
2. With one switch on, only that context alerts.
3. A second whisper or target within the cooldown does not alert; after the cooldown it does.
4. An avoided player alerts regardless of the four switches (while `avoidWarning` is on).
5. An unrated, non-avoided player never alerts.
6. No alert, toast, or database read occurs during combat; queued events resolve afterwards.
7. The debug log records the context word and a count only — never a name, GUID, or message.
8. Settings appear in both Blizzard's panel and the in-window Settings page with the same values.
9. Existing databases load unchanged; schema stays 1.
10. `tools/check.sh` passes with zero lint warnings and all tests green.

**Evidence.** Automated tests and static checks pass. In-game behaviour is **not executed** here;
see [the manual test plan](../testing/manual-test-plan.md).

**Out of scope.** Persisted cooldowns, alert sounds per context, alert digests, quiet hours,
default-on alerts.

## M2 — Undo and incident provenance

**Problem.** Rating is now fast, but two things still make people hesitate: a mis-click has no
undo, and a saved rating does not say *which* pull, boss, or quest prompted it. TheList offers undo
and per-incident comments; SquadRank should offer undo and structured provenance without copying
its free-text incident model.

**Planned scope**

- A short-lived undo for the last destructive action: purge one player, purge all, and deleting a
  single rating. Undo is in memory, expires after 10 seconds, and is surfaced in the toast and in
  the history drawer.
- Each rating gains optional provenance already available on its run: run type, zone or instance,
  encounter or quest name when known, and the run's date. **No new free-text field.**
- The history drawer shows provenance per rating, not just the note.
- `/sr undo` as a keyboard path for the same action.

**Data impact.** Provenance is additive on new ratings. Old ratings show "no source recorded".
Schema stays 1 if provenance can be derived by run lookup; if it must be denormalised, a schema 2
migration with a backup is required and will be proposed separately.

**Acceptance criteria.** Undo restores exactly the removed record or rating, including tags, note,
role, and timestamps; a second undo does nothing; provenance never includes another player's text;
purge-all undo restores runs and players but not settings (settings were never removed).

**Why after M1.** Undo touches destructive paths and needs a careful test matrix; it should not
share a release with new event wiring.

## M3 — Validated export/import and search polish

**Problem.** Players move between machines, keep backups, and want to inspect their own data.
SquadRank has no export or import, and the Players search is name-only.

**Planned scope**

- **Export** to a plain, human-readable text block in a copy box: schema marker, addon version,
  export time, then one record per player with ratings, tags, notes, and avoid flag. Names are
  included because the user asked for their own data; nothing is uploaded.
- **Import** with a preview: record count, duplicates, schema mismatch, and a required
  confirmation. Import is merge-only; it never overwrites a newer local rating silently.
- **Rollback snapshot** taken automatically before an import, kept as `db.importBackup`, and
  removed by purge-all.
- **Search** matches name, realm, tag text, and note text, with the same out-of-combat rule.
- `/sr export` and `/sr import` commands, plus buttons on the Settings or About page.

**Data impact.** The export format is versioned independently of the schema. Import validates
every field and rejects the whole block on error. No network access.

**Acceptance criteria.** Round-trip export → purge → import restores ratings, tags, notes, avoid
flags, and run links where the run still exists; malformed input is rejected with a count, not a
Lua error; duplicate ratings are skipped or merged by rating ID; notes are sanitised on the way in.

## M4 — Optional chat presence and profile snapshot (gated)

**Problem.** TheList makes reputation visible in chat with a `+`/minus badge and stores a richer
profile snapshot. Both are useful, and both carry privacy or API risk.

**Candidate scope**

- **Opt-in chat badge** before a known player's chat line, using a verified chat filter API.
  Default off. No message content is stored.
- **Profile snapshot** of level, class, faction, and guild name at first/last seen, refreshed only
  when the player is in the group (no lookups for strangers).

**Approval gates**

- Chat filtering must be verified in the Forever client, including secret-value behaviour and
  performance in busy channels.
- Guild/race snapshots add stored personal data; the user must be able to turn them off and purge
  them with the existing purge paths.
- No addon-message sharing, no outgoing whispers, and no kick prompts will be added under this
  milestone.

**Why gated.** A chat badge modifies every incoming line and can break other addons' filters. It
needs an explicit decision, not a quiet default.

## M5 — Keybinds, macros and a compact quick bar

**Problem.** TheList offers keybinds and draggable Nice/Naughty buttons. SquadRank's window-based
flow is deliberate, but power users want a rating path that does not open the window.

**Planned scope**

- Bindings for "open SquadRank", "rate current target", and "open the newest pending run".
- Secure-friendly macro helpers that never act in combat: `/sr rate target` and `/sr rate last`.
- An optional compact bar with five score buttons for the current target, hidden by default,
  movable, and hidden in combat.
- No automatic rating and no default-on keybinds.

**Data impact.** None beyond existing rating records.

**Acceptance criteria.** Keybinds are listed in Blizzard's binding UI, survive reloads, do nothing
in combat, and can be unbound; the quick bar never covers the default unit frames unless moved
there by the user.

## Non-goals

These are deliberately excluded, not deferred:

- Addon-message score sharing, network sync, or any server component.
- First-save whispers, kick prompts, or automated social actions.
- Founder lists, seeded reputation, or imported third-party reputations.
- Retail client support without a separate approved plan.
- Telemetry, analytics, crash reporting, or player-data sharing.
- Copying TheList's code, UI assets, sounds, strings, or branding.
- Default-on context alerts or forced onboarding.

## Sequencing and release gates

1. **M1 release gate:** automated checks green, manual context-alert cases executed in game by the
   author or a tester, and no regression in group-join, avoid, tooltip, or combat behaviour.
2. **M2 gate:** undo tests cover interrupted sessions and reloads; provenance has a documented
   schema decision.
3. **M3 gate:** export/import round-trip tested on a copy of a real SavedVariables file; malformed
   input fuzzed in the pure-Lua suite.
4. **M4 gate:** explicit approval plus in-game API verification.
5. **M5 gate:** keybind conflict check and a combat-safety test.

Each release also re-runs the full `TESTING.md` checklist. A milestone that cannot be validated in
game is documented as such; it is not described as verified.
