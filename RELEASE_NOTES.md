# SquadRank 1.5: heads-up outside groups

Version **1.5**. The database schema is unchanged (1) and no existing data or setting is touched.

## New: optional heads-up alerts

- **Four new moments.** A player you saved can now get your attention when they **whisper you**,
  when you **target them**, or when they **ask to trade or duel**. Each has its own switch.
- **Off by default.** SquadRank stays quiet unless you ask for it. The join toast, rating alert and
  avoid warning work exactly as before.
- **One cooldown per player.** At most one heads-up per player across all four moments, adjustable
  from 0 to 180 minutes (default 60). It resets on `/reload` and is never written to your saved file.
- **Avoid list still wins.** A player on your avoid list can produce a red warning even when that
  moment's switch is off, as long as the existing avoid warning is on. The cooldown still applies.
- **Only players you know.** Players with no rating and no avoid flag never trigger a heads-up.
- **Private by design.** A whisper alert uses only the sender's name. The message text is never
  read, logged or stored.
- **Combat-safe.** Nothing is looked up during combat; events wait and resolve afterwards.
- **Click to remember.** Clicking the pop-up opens that player's history.

## New: a friendlier welcome

- **What's new, once per version.** After an update, a short window shows the five things worth
  knowing about 1.5. It never appears twice for the same version and does not show in combat.
- **Reopen it any time.** Type `/sr whatsnew`, or use the button on the Settings page.
- **A quiet hello in chat.** At login, SquadRank prints one short line with its icon so you know it
  is tracking your groups. Once per session.
- **Both are optional.** New switches in Settings (and Blizzard's AddOns panel) turn the automatic
  window and the chat hello off. The `/sr whatsnew` command still works when the automatic window is off.
- **No new data categories.** The window records only the last version it was shown for
  (`seenVersion`, a short string in the saved file). No player data is added or changed.
- **A little personality, safely.** 🎉 The README and release notes use emoji, and the in-game hello
  carries the SquadRank icon. In-game text itself uses Blizzard colours and textures rather than
  emoji, because Forever's fonts do not reliably draw colour emoji on every client. No extra font or
  texture pack is shipped.

## Where to find it

`/sr` → **Settings** → **Heads-up outside groups**, or Blizzard's AddOns options for SquadRank.
The four new switches and the cooldown slider show the same values in both places.
The welcome switches are under **Interface**, with the what's-new button just below them.

## Validation

Automated checks pass (style, lint, 157 tests). An in-game pass has **not** been run: the cases are
listed in [docs/testing/manual-test-plan.md](docs/testing/manual-test-plan.md) and are marked
`NOT EXECUTED`. The player-facing behaviour should be treated as unverified until that pass happens.

The competitor research and product plan behind this change are in
[docs/research/the-list-analysis.md](docs/research/the-list-analysis.md),
[docs/product/feature-gap-matrix.md](docs/product/feature-gap-matrix.md) and
[docs/product/squadrank-roadmap.md](docs/product/squadrank-roadmap.md). SquadRank is an independent
addon and is not affiliated with TheList or its author.

---

# SquadRank 1.0.0-release: first release

Checked for 1.0: nothing is ever sent to other players; the debug report holds counts only (names are
scrubbed even from error messages); every window, alert and toast steps aside in combat; `/sr purge
<name>` removes exactly that player and `/sr purge all` everything but your settings; translated labels fit
or show in full on hover. Licensed All Rights Reserved (LICENSE.txt); no third-party files are bundled.

**PvP page.** Battlegrounds, arenas, world PvP and open-world raids have their own page. A 40-player raid
never floods your Players list, never asks you to rate 39 strangers, and never skews "Most grouped with";
players you rated or avoid still show everywhere and still trigger their warnings.

Everything from 0.1.0 to 0.3.0 below, plus:

## New: what your group did

- **Group types.** Every group is labelled Questing, Open world, Dungeon, Raid, World raid, PvP or World PvP,
  with a coloured label and a **Type** filter on the Runs page. Groups you recorded before get a type too.
- **Bosses and quests.** Dungeons and raids remember each boss defeated; groups remember the quests completed
  and progressed together. Hover a group on the Runs page (or a section header on the Rate page) to see them,
  with how long the group lasted.
- **Battlegrounds and arenas** are recorded. Battlegrounds don't pop the "Rate your squad" alert (too many
  strangers); rate them from the Runs page if you want.
- **New tags:** "Needed off-spec loot" (negative) and "Led the group well" (positive).
- **Support SquadRank:** the About page has a link to copy: buymeacoffee.com/nivlemoth.

## New: avoid list, stats and more

- **Avoid list.** Mark a player to avoid (player list, history, or right-click their party frame). If they
  join your group you get a red warning with a sound. They show in red in your list and on the Stats page.
- **Player tooltips.** Hover a player you rated to see their SquadRank reputation, or the avoid warning.
- **Stats page.** Groups, hours, bosses and quests in total; who you group with most; who you rated highest;
  your avoid list; and your groups by type.
- **Wipes** are counted per dungeon or raid run.
- **No prompt for quick dungeon visits** (under 3 minutes by default, adjustable).
- **Share a player summary** (opt-in in Settings): one line to copy into chat. Your notes are never included.
- **Sounds** for the rating alert, join toasts and avoid warnings, with a setting to turn them off.

## New: SquadRank in your language

- **Follows your game language.** German, French, Spanish (Spain and Latin America), Brazilian Portuguese,
  Italian, Russian, Korean, Simplified and Traditional Chinese, with English for everything else.
- **Your data is unchanged.** Ratings, tags and notes are stored the same way in every language; switching the
  game language changes only what you see.
- **Better counts.** "1 rating" instead of "1 ratings", with proper plural forms in each language.
- **Long labels fit.** Text that does not fit a button or tag ends in "..." and shows in full on hover.
- Translations are machine-assisted and waiting for native-speaker review: corrections are welcome
  (see docs/LOCALIZATION.md).

---

# SquadRank 0.3.0

## New in 0.3.0: one window, new look

- **Everything in one window.** A sidebar switches between Rate, Players, Runs, Settings and About, with a
  short slide between pages. No more stacks of separate windows.
- **Player history slides in.** Click a player and their history slides in from the right: average score,
  a bar per role, their top tags, Rate and Purge buttons, then every rating you gave them. The list stays
  in view, so you can click the next player straight away.
- **Rate page.** Opening it shows every group still waiting for a rating, or "All caught up". The sidebar
  shows how many players are waiting.
- **Minimap button.** Left-click opens SquadRank, right-click opens Settings, drag to move it. A gold dot
  pulses when players are waiting to be rated. Hide it in Settings or with `/sr minimap`.
- **Settings inside the window,** with switches and +/- steppers. Blizzard's options panel still works and
  shows the same values.
- **About page,** by Nivlemoth.
- **A flat, modern look** everywhere, including the toast and the "Rate your squad" alert, with gliding
  mouse-wheel scrolling.
- **New commands:** `/sr settings`, `/sr about`, `/sr minimap`.

The 0.3.0 window has **not** been run in the game client yet; it is covered by 105 automated tests and every
new Blizzard call was checked against the Forever UI source.

---

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
