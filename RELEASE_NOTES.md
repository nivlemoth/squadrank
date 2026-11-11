# SquadRank 0.1.0

First build for **WoW Forever** (Interface 16001). A full rewrite of SquadRank 1.5.2; nothing from the old
code is loaded.

**Status: not yet run in the game client.** All logic is covered by 96 automated tests, including a scripted
session against a fake client, and every Blizzard call was checked against the Forever UI source
(build 1.60.1.70888). The windows have never been drawn by the real game. Expect the first in-game pass to
find layout problems or errors, and use `/sr debug` to report them.

## What it does

- **Heads-up when a known player joins.** When someone you have rated joins your group, or you join theirs,
  a small toast shows their reputation, per-role scores, top tags and your last note. Once per player per
  group, never in combat.
- **Ratings.** Score 1 to 5, the role they played, any of 14 tags (7 positive, 7 negative) and a note of
  up to 140 characters.
- **Reputation.** Trusted, Mixed or Caution from a recency-weighted average (a rating counts half as much
  after 90 days). Players with fewer than 3 ratings show as New. Per-role averages are tracked separately.
- **Rate your squad.** After a dungeon or raid run ends, a prompt offers to rate everyone who was in it.
  Skip it and reopen later with `/sr rate` or from the Runs tab.
- **Rate anytime.** Right-click a player's unit frame and choose "Rate in SquadRank", or `/sr rate <name>`.
- **Main window.** Searchable player list with filters by label, role and tag; history per player; list of runs.
- **Settings** in the game's own Options panel: toast on/off and duration, ratings needed for a label,
  post-run prompt, delete one player or everything.
- **Local only.** No network or addon-channel code. Your notes never leave your machine.

## Commands

| Command | Does |
|---|---|
| `/sr` | Open or close the window (also in the minimap Addon Compartment) |
| `/sr rate [name]` | Rate a player; with no name, rate the last unrated run |
| `/sr list [text]` | Print rated players to chat |
| `/sr purge <name>` or `/sr purge all` | Delete saved data, after a confirmation |
| `/sr debug` | Open the debug report for copying |
| `/sr selftest` | Check the game APIs the addon depends on |

`/squadrank` works in place of `/sr`.

## Things to know

- A run ends when you leave the group, enter a different instance, or stay outside for 5 minutes.
  Walking out and back in (a corpse run) does not end it. `/reload` inside a dungeon loses nothing.
- All rulesets share one record per player; the ruleset a player was seen on is stored as a note on the record.
- Windows close with their X button. Escape does not close them in this version.
- Data from SquadRank 1.x, if found, is converted on first load and a backup of the original is kept
  inside the saved file. Forever uses its own settings folder, so there is normally nothing to convert.

## Known limits and open questions

- **Names.** Forever may give players a surname instead of a realm. The addon stores both parts exactly as
  the game returns them; the self-test reports which it is.
- **Boss kills** are counted only if Forever fires encounter events in its dungeons. Nothing depends on it.
- **Recent Allies** integration is off by default and only looks up a typed name to find the player's ID.
- **Raids** use the same tracking as dungeons but are untested; Forever raids open on 2026-12-09.
- The addon icon is a built-in Blizzard icon. If it shows as a question mark, the icon name needs changing.
- English only. All text is in `Locales/enUS.lua`, ready for other languages.

## Not in this version

Import/export, sharing ratings with other players, a custom logo, tooltips on unit mouseover,
Escape-to-close, automatic performance data (the game no longer gives addons the combat log).
