# SquadRank 0.2.0: in-game test checklist

Run these in order on a WoW Forever character. Each step has what to type or do, and what should happen.
You need one other player (a friend or a second account) for steps 9 to 27.

**If anything goes wrong:** type `/sr debug`, click in the box, press Ctrl+A then Ctrl+C, and paste the text
back to me. If the window itself fails, type `/reload` and send the file
`WTF\Account\<ACCOUNT>\SavedVariables\SquadRank.lua` (the `SquadRankDebug` part).
To see Lua errors on screen, type `/console scriptErrors 1` once.

**Before you start:** if you have ratings from 0.1.0 you want to keep, nothing to do: 0.2.0 reads them as is.

## A. Loading

| # | Do this | Expected |
|---|---|---|
| 1 | `/console scriptErrors 1` then `/reload` | No error window. Nothing printed by SquadRank (it is silent at load). |
| 2 | `/dump select(4, GetBuildInfo())` | `16001`. If it is another number, tell me: the TOC needs it. |
| 3 | Open the AddOn list (Esc > AddOns) | **SquadRank 0.2.0** is listed under the "Group" category and is not marked out of date. |
| 4 | Click the addon button on the minimap (Addon Compartment) and pick SquadRank | The SquadRank window opens. Click it again: it closes. |
| 5 | `/sr help` | Five help lines are printed. |

## B. Debug and self-test

| # | Do this | Expected |
|---|---|---|
| 6 | `/sr selftest` | One line: `Self-test: N pass, 0 fail, M info`. Any number of fails other than 0 is worth sending me. Two new rows: "animation groups" and "role and checkmark atlases" should say PASS. |
| 7 | `/sr debug` | A window with a text box. It shows the addon version, `interface 16001`, counts, settings, the self-test rows and a log. No player names anywhere in it. |
| 8 | In that window click **Run self-test**, then **Refresh** | The self-test section updates with a new time. |

## C. Rating one player (needs a second player)

| # | Do this | Expected |
|---|---|---|
| 9 | Invite the other player to a party. Wait 2 seconds. `/sr` | The other player is in the list with reputation "New" and 0 ratings. No toast (you have not rated them). |
| 10 | In the party: `/sr selftest`, then `/sr debug` | Rows "group members can be identified" and "group member values are not secret" say PASS. "current run" says `group`. Note what "UnitName second value" says: I need that line. |
| 11 | Right-click the other player's party frame | The menu has "Rate in SquadRank" at the bottom. |
| 12 | Click it | The "Rate a player" window **fades in**. One card: role icon on the left, their name in class color, a grey line with role, level, class and reputation, and five colored score squares (1 red to 5 green) on the right. |
| 13 | Hover a score square | Tooltip such as "4: Good". The square lightens. |
| 14 | Click **4** | One click saves it: the square fills green-yellow and **pops**, a checkmark pops in, the bar at the top fills, and the card **slides open** to show 7 positive tags, a "Negative tags..." link and a note box. No chat line. |
| 15 | Click **Efficient**, click the role icon until it shows the healer cross, type a note, press Enter | The tag lights up green. The grey line now says Healer. Nothing else to click. |
| 16 | Click **Done**. `/sr`, click the player's row | The window fades out. History: one rating, score 4, Healer, tag Efficient, your note. |
| 17 | Have the other player leave the party, then invite them again | A toast **slides down** near the top of the screen: their name, "New", "Rated once, score 4.0", "Healer 4.0 over 1 run", the tag, your note. It fades away after 8 seconds. |
| 18 | `/reload` while still grouped | No second toast. |
| 19 | Leave and re-form the group while you are in combat (hit a training dummy or a mob) | No toast during combat. It appears when combat ends. |
| 20 | `/sr rate <their name>` twice more, giving scores 5 and 5 | After the third rating the list shows "Trusted" in green. |

## D. "Rate your squad" after a group

| # | Do this | Expected |
|---|---|---|
| 21 | Stay grouped with the other player for **at least 5 minutes** anywhere outside a dungeon. Then leave the party | About 2 seconds later a small card **slides down** from the top of the screen: three role icons, "Rate your squad", "Group in <zone>, 1 to rate", with a slow gold pulse. It stays until you act. |
| 22 | Fight something while it is showing | It disappears in combat and slides back after the fight. |
| 23 | Click the card | It slides away and "Rate your squad" opens. A section header "Group in <zone>  <date>  0/1 rated", then the card; cards **fade in one after another**. |
| 24 | Click a score, then click **Done** | Saved with one click, as in step 14. The card does not come back. In `/sr` > **Runs** the group shows `1/1 rated`. |
| 25 | Group again, walk into any dungeon together. `/sr debug` | "current run: instance". The log has `[RUN] started`. The open-world group turned into the dungeon run. |
| 26 | `/reload` inside the dungeon, then `/sr debug`. Walk out, wait 30 seconds, `/sr debug` | Still "current run: instance" after the reload (`[RUN] resumed`), and outside (`[RUN] pending`). |
| 27 | Leave the party | The alert slides in: "<dungeon>, 1 to rate". Click it, rate with one click. In `/sr` > **Runs** the run shows `1/1 rated`. |
| 28 | Do 25 and 27 again, but close the alert with its **X** | It slides away and does not come back on its own. `/sr rate` (no name) still opens that run. |
| 29 | Kill a dungeon boss during a run, then `/sr selftest` and `/sr debug` | The "events seen" row shows whether `ENCOUNTER_END` and `BOSS_KILL` are above 0. Either answer is fine; I need to know which. |
| 30 | (Needs 3+ players, optional) Rate a run of several players | Clicking a score on one card closes the previous card and opens this one, smoothly. The cards below do not jump. When everyone is rated the bar turns green and says "Everyone rated. Thank you!". |

## E. Main window and settings

| # | Do this | Expected |
|---|---|---|
| 31 | `/sr`, type part of a name in the search box | The list narrows as you type. |
| 32 | Click **Label: All**, choose **Trusted** | Only Trusted players remain; the button reads "Label: Trusted". Set it back to All. |
| 33 | Scroll the list (rate a few players first, or skip if the list is short) | Smooth scrolling. If the list is blank or broken: `/sr debug lists`, `/reload`, and tell me. |
| 34 | Esc > Options > AddOns > SquadRank | Seven controls. The fourth now reads "Offer to rate your squad when a group ends". |
| 35 | Untick "Show a toast when a rated player joins". Repeat step 17 | No toast. Tick it again. |
| 36 | Untick "Offer to rate your squad when a group ends". Repeat step 21 | No alert. Tick it again. |
| 37 | Set "Ratings needed for a label" to 1, reopen `/sr` | Players with one rating now show a label instead of "New". Set it back to 3. |
| 38 | `/reload`, reopen the settings | Your changes are still there. |

## F. Deleting data

| # | Do this | Expected |
|---|---|---|
| 39 | `/sr purge <name>` and confirm | Chat says "Deleted <name>". They are gone from `/sr`. |
| 40 | `/sr purge all` and confirm | Chat says all data deleted. The list is empty. Settings are unchanged. |
| 41 | `/sr rate Testdummy`, click **3**, paste this into the note box: `|TInterface\Icons\x:16|t hi |Hitem:1|h[x]|h` and press Enter. `/sr`, click Testdummy | The note shows as plain text `hi [x]`. No icon, no color, no link. |

## What I most need back

1. The full `/sr debug` text after step 10 and after step 29.
2. Any Lua error text.
3. How the motion feels: too fast, too slow, or right (steps 12, 14, 21, 23, 30). Screenshots of the rating
   window with a card open help a lot.
