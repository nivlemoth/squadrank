# SquadRank 0.2.0

## New in 0.2.0: faster rating

- **One click per player.** The rating window shows a card for every player. Click a score from 1 to 5 and it
  is saved: no player to select first, no Save button. The card then opens with the tags that fit that score
  and a note box, both optional and saved as you click. Click the role icon to change the role.
- **"Rate your squad" waits for a good moment.** When a group you played in breaks up, a small card slides
  down from the top of the screen and waits, with a soft pulse, until you click it or close it. It never shows
  in combat or while you are still in a group, and it has no timeout.
- **Open-world groups count.** Questing or world-boss groups of 5 minutes or more can be rated too, not only
  dungeons and raids. A group that walks into a dungeon together becomes that dungeon run; a squad is never
  offered twice for the same session.
- **Several groups at once.** If more than one group ended since you last looked, they open together in one
  window, one section each. "Skip all" stops asking about them.
- **Motion.** Windows fade in and out, cards appear one after another and open and close smoothly, scores and
  checkmarks pop, the progress bar fills, and the toast slides in and out. The rating window steps aside in
  combat and comes back after.

0.1.0 was tested in game by John: loading, the settings panel, the main window, player history and manual
rating all worked. The 0.2.0 window and alert have **not** been run in the game client yet; they are covered by
104 automated tests and every new Blizzard call was checked against the Forever UI source.

---

# SquadRank 0.1.0

First build for **WoW Forever** (Interface 16001). A full rewrite of SquadRank 1.5.2; nothing from the old
code is loaded.

## What it does

- **Heads-up when a known player joins.** When someone you have rated joins your group, or you join theirs,
  a small toast shows their reputation, per-role scores, top tags and your last note. Once per player per
  group, never in combat.
- **Ratings.** Score 1 to 5, the role they played, any of 14 tags (7 positive, 7 negative) and a note of
  up to 140 characters. (0.2.0: one click on a score saves it.)
- **Reputation.** Trusted, Mixed or Caution from a recency-weighted average (a rating counts half as much
  after 90 days). Players with fewer than 3 ratings show as New. Per-role averages are tracked separately.
- **Rate your squad.** After a dungeon or raid run ends, a prompt offers to rate everyone who was in it.
  Skip it and reopen later with `/sr rate` or from the Runs tab. (0.2.0: replaced by the alert above.)
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
