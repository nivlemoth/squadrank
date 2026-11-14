# Data model, settings and migrations

Updated 2026-11-13. This describes what SquadRank saves, how it is upgraded, and what changes are
safe. It reflects the working tree (schema 1), the contextual-alert milestone and the 1.5 onboarding
window.

## Saved variables

The TOC loads saved variables before the addon, so settings can be read during load.

| Variable | Owner | Contents |
|---|---|---|
| `SquadRankDB` | `Data/DB.lua` | The user's players, runs, settings, optional current run, session marker and pre-migration backup. |
| `SquadRankDebug` | `Core/Debug.lua` | A bounded diagnostic log and counters. Counts and fixed words only. |

There is exactly one global addon table, `SquadRank`. Everything else lives on
`local _, ns = ...`, which is the standard WoW addon namespace.

## Database shape (schema 1)

```text
SquadRankDB = {
  schema   = 1,
  nextId   = <integer>,              -- shared counter for player/rating/run IDs
  seenVersion = "1.5",               -- optional: last version whose what's-new window was shown

  settings = { ... },                -- see below

  players  = {
    ["g:<GUID>"] = {                 -- GUID-first identity
      name       = "Bob",
      suffix     = "Realm or surname",  -- exactly as UnitName returned it
      guid       = "Player-...",
      classFile  = "MAGE",
      level      = 60,
      faction    = "Alliance",
      firstSeen  = <epoch>,
      lastSeen   = <epoch>,
      rulesets   = { hardcore = true },   -- optional
      avoid      = true,                  -- optional flag, never a label string
      ratings    = {
        {
          id        = "r12",
          createdAt = <epoch>,
          updatedAt = <epoch>,
          score      = 1..5,
          role       = "TANK"|"HEALER"|"DPS",
          tags       = { "communicator", ... },  -- stable IDs, never display text
          note       = "<= 140 sanitised characters",
          runId      = "run7",                  -- optional
          imported   = true,                    -- optional, legacy import only
        },
      },
    },
    ["n:Bob-Realm"] = { ... },       -- name fallback until a GUID is seen
  },

  runs = {
    ["run7"] = {
      id           = "run7",
      startedAt    = <epoch>,
      endedAt      = <epoch>,
      lastInside   = <epoch>,
      outsideSince = <epoch>,        -- optional
      kind         = "group",        -- nil for dungeon/raid
      instanceID   = 123,
      instanceName = "...",
      instanceType = "party"|"raid"|"pvp"|"arena",
      ruleset      = "...",          -- optional
      bosses       = { { id = 1, name = "...", at = <epoch> } },
      bossKills    = <integer>,
      wipes        = <integer>,
      quests       = { { id = 1, title = "...", done = true } },
      members      = { { pid = "g:...", name = "...", role = "DPS" } },
      prompt       = "pending"|"done"|"skipped",
      after        = "run6",         -- optional link from a group to its dungeon
    },
  },

  currentRun = { ... },              -- same shape as a run, while a group is active
  session    = { ... },              -- in-progress group-session markers
  backup     = { schema = 0, ... },  -- one pre-migration copy, only if data existed
  alertDismissedAt = <epoch>,        -- optional
  importBackup     = { ... },        -- reserved for the planned import milestone
}
```

### Why identity is keyed this way

- A GUID key (`g:<GUID>`) survives renames, realm transfers, and faction changes that the client
  reports.
- A name key (`n:<name>-<suffix>`) is a fallback for a typed name or an unavailable GUID.
- When a name-keyed record later meets its GUID, `Players.Resolve` merges the ratings, keeps the
  earlier `firstSeen`, unions rulesets, and removes the name key. This is the only merge path and
  it is unit-tested.
- Records are never keyed by display text, language, or formatted date.

### Why ratings carry stable IDs

Scores, roles, tags, labels, run types and prompt states are stored as stable tokens
(`"TANK"`, `"communicator"`, `"pending"`, `"pvp"`). Nothing stored is English display text. This is
why localisation needed no data migration.

## Settings

Defaults live in `DB.DEFAULT_SETTINGS` and are merged into an existing table on every load, so a
new key appears with its default without touching saved data.

| Key | Default | Range / meaning |
|---|---|---|
| `toastEnabled` | `true` | Join toasts on/off |
| `toastDuration` | `8` | 3–30 seconds |
| `minRatings` | `3` | 1–10 ratings before a reputation label |
| `promptAfterRun` | `true` | "Rate your squad" alert |
| `recentAllies` | `false` | Read-only Recent Allies lookup |
| `simpleLists` | `false` | Force the non-ScrollBox list fallback |
| `minimapButton` | `true` | Show the minimap button |
| `minimapAngle` | `200` | 0–359 degrees |
| `avoidWarning` | `true` | Red avoid warning on join |
| `sound` | `true` | All SquadRank sounds |
| `minRunMinutes` | `3` | 0–30; shorter dungeon/raid visits do not prompt |
| `tooltipInfo` | `true` | SquadRank line in unit tooltips |
| `allowShare` | `false` | Enable the manual share box |
| `alertWhisper` | `false` | **New:** context alert on incoming whisper |
| `alertTarget` | `false` | **New:** context alert on target change |
| `alertTrade` | `false` | **New:** context alert on trade request |
| `alertDuel` | `false` | **New:** context alert on duel request |
| `alertCooldown` | `60` | **New:** 0–180 minutes, per player across contexts |
| `showWhatsNew` | `true` | **New:** show the what's-new window once per version |
| `chatHello` | `true` | **New:** print one greeting line in chat per session |

Numeric values are clamped in `DB.repair` on every load. A missing or malformed value falls back
to the default through `Util.MergeDefaults`; a malformed table is replaced with `{}` first.

### `seenVersion` is onboarding state, not player data

`db.seenVersion` stores the last version whose what's-new window was shown. It is optional:

- it contains only a short version string (`1.5`), never a name, GUID or note;
- `DB.repair` clears it if it is not a string or is longer than 16 characters;
- deleting it makes the window appear once more, which is harmless;
- no migration is needed: an old file simply lacks the key and shows the window once.

### Context-alert cooldown is not saved

`Alerts.last` is a plain in-memory table: `pid -> last alert epoch`. It is intentionally **not** in
`SquadRankDB`, so:

- no new player data is written;
- a reload resets the cooldown;
- there is no schema change and no migration;
- deleting a player leaves no orphan timestamp.

If a future milestone persists it, that is an additive table plus pruning, and will be documented
as a schema change.

## Load, repair, migration and read-only mode

`DB.Open(raw, now)` is the only entry point. It returns `db, info`.

1. **No table** → create a fresh schema-1 database (`info.created = true`).
2. **Schema newer than `ns.SCHEMA`** → `info.readOnly = true`, reason `"newer schema N"`, and an
   empty in-memory database is returned. The saved file is never assigned or written.
3. **Schema older** → `Migrations.Run(db, old, ns.SCHEMA, now)` runs each step in order.
   - Before a migration, one `db.backup` is taken if the old database held players or runs.
   - On success, `info.migratedFrom` is set.
   - On failure, `info.readOnly = true`, reason `"migration failed: ..."`, and the caller gets a
     throwaway database. The saved file is left exactly as it was.
4. **Repair** ensures `settings`, `players`, `runs` are tables, `nextId` is numeric,
   `seenVersion` is nil or a short string, optional tables are tables or removed, defaults are
   merged, and numeric settings are clamped.
5. **Prune** enforces the size limits (below) and reports counts in `info.pruned`.

`Core/Main.lua` only assigns `SquadRankDB = db` when `info.readOnly` is false. This is the safety
contract: a database this build does not understand is never downgraded or overwritten.

### Pruning limits

| Limit | Value | Notes |
|---|---|---|
| Runs kept | 300 | Oldest by `startedAt` removed first |
| Ratings per player | 50 | Oldest by `createdAt` removed first |
| Unrated players | 180 days after `lastSeen` | Rated and avoided players are kept |
| Unrated crowd-only players | 14 days after `lastSeen` | Strangers met only in battlegrounds, world PvP or world raids |
| Bosses per run | 30 | Metadata cap |
| Quest entries per run | 40 | Metadata cap |

Pruning never removes a player who is in `currentRun`, has any rating, or is on the avoid list.

## Migration rules for future changes

A change needs a migration when it renames/retypes a stored field, moves data between tables, or
changes the meaning of an existing token. It does **not** need one when it only adds a settings key
with a default or adds an optional field that old readers can ignore.

**Required for every schema bump**

1. Increment `ns.SCHEMA` and add exactly one `Migrations.steps[n]` function.
2. Keep the step pure: no game API calls, `now` is passed in, no I/O.
3. Make it idempotent-safe where practical; a failed step must leave enough data for the backup.
4. Add a test that loads a representative old-shape table and asserts the upgraded shape.
5. Add a test that loads a **newer** schema and asserts `readOnly` with no writes.
6. Document the rollback below and run `TESTING.md` section A against a copied SavedVariables file.
7. Never renumber or delete an existing step.

**Compatibility policy**

- Two schema numbers of read support are the goal for any future bump; dropping older support
  requires approval.
- Unknown fields on a known schema are preserved, not stripped, unless they are known to be
  unsafe.
- A newer schema is opened read-only, never auto-upgraded or silently ignored.

**Rollback**

- Before migrating, the addon keeps `SquadRankDB.backup` (schema and data, one copy).
- To roll back manually: close the client, restore the `SquadRankDB` table from
  `SquadRankDB.lua` or from a file backup, and reload an older build that supports that schema.
- `/sr purge all` removes `players`, `runs`, `currentRun`, `session`, `backup` and `importBackup`,
  but keeps `settings`. This is intentional so preferences survive a data reset.

## Data safety and privacy properties

- **No network.** The luacheck allowlist contains no chat-send, addon-message, mail, Battle.net,
  club or note-writing API. Input arrives through game events only.
- **No combat writes.** Events that fire in combat queue in memory; the queue is applied out of
  combat. Context alerts read the database only through the same out-of-combat queue.
- **Whisper text is not touched.** `CHAT_MSG_WHISPER` supplies a sender name; the message argument
  is ignored by the handler signature.
- **Sanitisation.** All player-supplied text passes `Util.Sanitize` (control/escape stripping,
  length caps) before storage. Notes are capped at 140 characters.
- **Diagnostics.** `Debug.Scrub` replaces saved names and realms in error text. Log lines use
  counts, hashes and fixed words.

## Change checklist for this milestone

- [x] Setting defaults added; no existing key renamed or removed.
- [x] `alertCooldown` clamped on load.
- [x] Cooldown state kept out of SavedVariables.
- [x] No database read in combat (event queue).
- [x] No new global, library, network call or file.
- [x] Existing schema-1 data loads unchanged; no migration step added.
- [x] `seenVersion` is optional, length-checked on load and never contains player data.
- [x] The what's-new window and chat hello default on and can each be turned off.
- [x] Automated tests cover defaults, clamping, opt-in behaviour, avoid exception, cooldown,
      the unrated case, the once-per-version window and the chat hello switch.
- [ ] In-game validation on a copied SavedVariables file — **not executed** (no client available).
