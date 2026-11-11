# SquadRank 0.1.0: in-game test checklist

Run these in order on a WoW Forever character. Each step has what to type or do, and what should happen.
You need one other player (a friend or a second account) for steps 9 to 21.

**If anything goes wrong:** type `/sr debug`, click in the box, press Ctrl+A then Ctrl+C, and paste the text
back to me. If the window itself fails, type `/reload` and send the file
`WTF\Account\<ACCOUNT>\SavedVariables\SquadRank.lua` (the `SquadRankDebug` part).
To see Lua errors on screen, type `/console scriptErrors 1` once.

## A. Loading

| # | Do this | Expected |
|---|---|---|
| 1 | `/console scriptErrors 1` then `/reload` | No error window. Nothing printed by SquadRank (it is silent at load). |
| 2 | `/dump select(4, GetBuildInfo())` | `16001`. If it is another number, tell me: the TOC needs it. |
| 3 | Open the AddOn list (Esc > AddOns) | SquadRank 0.1.0 is listed under the "Group" category and is not marked out of date. |
| 4 | Click the addon button on the minimap (Addon Compartment) and pick SquadRank | The SquadRank window opens. Click it again: it closes. |
| 5 | `/sr help` | Five help lines are printed. |

## B. Debug and self-test

| # | Do this | Expected |
|---|---|---|
| 6 | `/sr selftest` | One line: `Self-test: N pass, 0 fail, M info`. Any number of fails other than 0 is worth sending me. |
| 7 | `/sr debug` | A window with a text box. It shows the addon version, `interface 16001`, counts, settings, the self-test rows and a log. No player names anywhere in it. |
| 8 | In that window click **Run self-test**, then **Refresh** | The self-test section updates with a new time. |

## C. Group and rating (needs a second player)

| # | Do this | Expected |
|---|---|---|
| 9 | Invite the other player to a party. Wait 2 seconds. `/sr` | The other player is in the list with reputation "New" and 0 ratings. No toast (you have not rated them). |
| 10 | In the party: `/sr selftest`, then `/sr debug` | Rows "group members can be identified" and "group member values are not secret" say PASS. Note what "UnitName second value" says: I need that line. |
| 11 | Right-click the other player's party frame | The menu has "Rate in SquadRank" at the bottom. |
| 12 | Click it. Click **4**, click **Healer**, click **Efficient**, type a note, click **Save** | Chat says "Saved your rating for <name>". The window closes. |
| 13 | `/sr`, click the player's row | History window: one rating, score 4, Healer, tag Efficient, your note. |
| 14 | Have the other player leave the party, then invite them again | A toast appears near the top of the screen: their name, "New", "Rated once, score 4.0", "Healer 4.0 over 1 run", the tag, your note. It disappears after 8 seconds. |
| 15 | `/reload` while still grouped | No second toast. |
| 16 | Leave and re-form the group while you are in combat (hit a training dummy or a mob) | No toast during combat. It appears when combat ends. |
| 17 | `/sr rate <their name>` twice more, giving scores 5 and 5 | After the third rating the list shows "Trusted" in green. |

## D. Dungeon run

| # | Do this | Expected |
|---|---|---|
| 18 | With the other player, walk into any dungeon. `/sr debug` | "current run: yes". The log has a `[RUN] started` line. |
| 19 | `/reload` inside the dungeon, then `/sr debug` | Still "current run: yes", and the log has `[RUN] resumed`. |
| 20 | Walk out of the dungeon and wait 30 seconds. `/sr debug` | Still "current run: yes" (you could be on a corpse run). The log has `[RUN] pending`. |
| 21 | Leave the party | Within a few seconds a toast: "Rate your squad", with **Rate** and **Later**. Click **Rate**, rate the player, **Save**. In `/sr` > **Runs**, the run shows `1/1 rated`. |
| 22 | Repeat 18 and 21 but click **Later**, then type `/sr rate` | The rating window opens for that run. |
| 23 | Kill a dungeon boss during a run, then `/sr selftest` and `/sr debug` | The "events seen" row shows whether `ENCOUNTER_END` and `BOSS_KILL` are above 0. Either answer is fine; I need to know which. |

## E. Main window and settings

| # | Do this | Expected |
|---|---|---|
| 24 | `/sr`, type part of a name in the search box | The list narrows as you type. |
| 25 | Click **Label: All**, choose **Trusted** | Only Trusted players remain; the button reads "Label: Trusted". Set it back to All. |
| 26 | Scroll the list (rate a few players first, or skip if the list is short) | Smooth scrolling. If the list is blank or broken: `/sr debug lists`, `/reload`, and tell me. |
| 27 | Esc > Options > AddOns > SquadRank | Seven controls: three checkboxes, two sliders, two buttons. |
| 28 | Untick "Show a toast when a rated player joins". Repeat step 14 | No toast. Tick it again. |
| 29 | Set "Ratings needed for a label" to 1, reopen `/sr` | Players with one rating now show a label instead of "New". Set it back to 3. |
| 30 | `/reload`, reopen the settings | Your changes are still there. |

## F. Deleting data

| # | Do this | Expected |
|---|---|---|
| 31 | `/sr purge <name>` and confirm | Chat says "Deleted <name>". They are gone from `/sr`. |
| 32 | `/sr purge all` and confirm | Chat says all data deleted. The list is empty. Settings are unchanged. |
| 33 | `/sr rate Testdummy`, click a score, paste this as the note: `|TInterface\Icons\x:16|t hi |Hitem:1|h[x]|h` then **Save**. `/sr`, click Testdummy | The note shows as plain text `hi [x]`. No icon, no color, no link. |

## What I most need back

1. The full `/sr debug` text after step 10 and after step 23.
2. Any Lua error text.
3. Whether the windows look right (title bar, close button, list, buttons readable).
