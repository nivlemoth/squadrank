# SquadRank 1.0.0: in-game test checklist

Run these in order on a WoW Forever character. Each step has what to type or do, and what should happen.
You need one other player (a friend or a second account) for steps 9 to 27.

**If anything goes wrong:** type `/sr debug`, click in the box, press Ctrl+A then Ctrl+C, and paste the text
back to me. If the window itself fails, type `/reload` and send the file
`WTF\Account\<ACCOUNT>\SavedVariables\SquadRank.lua` (the `SquadRankDebug` part).
To see Lua errors on screen, type `/console scriptErrors 1` once.

**Before you start:** ratings from 0.1.0 and 0.2.0 are kept: 1.0.0 reads them as is.

## A. Loading

| # | Do this | Expected |
|---|---|---|
| 1 | `/console scriptErrors 1` then `/reload` | No error window. Nothing printed by SquadRank (it is silent at load). |
| 2 | `/dump select(4, GetBuildInfo())` | `16001`. If it is another number, tell me: the TOC needs it. |
| 3 | Open the AddOn list (Esc > AddOns) | **SquadRank 1.0.0** is listed under the "Group" category and is not marked out of date. |
| 4 | Look at the edge of the minimap | A round SquadRank button (group icon in a gold ring). Hover it: a tooltip with three hints. **Left-click**: one window **fades in** with a sidebar (Rate, Players, Runs, Settings, About) and "by Nivlemoth" at the bottom left. Left-click again: it fades out. **Right-click**: the window opens on Settings. **Drag** it: it slides round the minimap; `/reload` keeps the spot. If the ring or the icon is missing, tell me (screenshot). |
| 4b | Click the addon button on the minimap (Addon Compartment) and pick SquadRank | The same window toggles. |
| 5 | `/sr help` | Six help lines are printed. |

## B. Debug and self-test

| # | Do this | Expected |
|---|---|---|
| 6 | `/sr selftest` | One line: `Self-test: N pass, 0 fail, M info`. Any number of fails other than 0 is worth sending me. Rows "animation groups", "role and checkmark atlases", "minimap button" and "flat look" should say PASS. |
| 7 | `/sr debug` | A window with a text box. It shows the addon version, `interface 16001`, counts, settings, the self-test rows and a log. No player names anywhere in it. |
| 8 | In that window click **Run self-test**, then **Refresh** | The self-test section updates with a new time. |

## C. Rating one player (needs a second player)

| # | Do this | Expected |
|---|---|---|
| 9 | Invite the other player to a party. Wait 2 seconds. `/sr` | The other player is in the list with reputation "New" and 0 ratings. No toast (you have not rated them). |
| 10 | In the party: `/sr selftest`, then `/sr debug` | Rows "group members can be identified" and "group member values are not secret" say PASS. "current run" says `group`. Note what "UnitName second value" says: I need that line. |
| 11 | Right-click the other player's party frame | The menu has "Rate in SquadRank" at the bottom. |
| 12 | Click it | The SquadRank window **fades in** on the **Rate** page. One card: role icon on the left, their name in class color, a grey line with role, level, class and reputation, and five colored score squares (1 red to 5 green) on the right. |
| 13 | Hover a score square | Tooltip such as "4: Good". The square lightens. |
| 14 | Click **4** | One click saves it: the square fills green-yellow and **pops**, a checkmark pops in, the bar at the top fills, and the card **slides open** to show 8 positive tags, then a note box with a "Negative tags..." link beside it. No chat line. |
| 15 | Click **Efficient**, click the role icon until it shows the healer cross, type a note, press Enter | The tag lights up green. The grey line now says Healer. Nothing else to click. |
| 16 | Click **Done**. `/sr`, click the player's row | The window fades out. Reopened, the Players page shows the player with a score bar. Clicking the row slides their **history drawer** in from the right: big "4.0", a Healer bar that grows, tag Efficient, then one rating with your note. Click another row: the drawer stays and its content changes. The cross slides it away. |
| 17 | Have the other player leave the party, then invite them again | A toast **slides down** near the top of the screen: their name, "New", "Rated once, score 4.0", "Healer 4.0 over 1 run", the tag, your note. It fades away after 8 seconds. |
| 18 | `/reload` while still grouped | No second toast. |
| 19 | Leave and re-form the group while you are in combat (hit a training dummy or a mob) | No toast during combat. It appears when combat ends. |
| 20 | `/sr rate <their name>` twice more, giving scores 5 and 5 | After the third rating the list shows "Trusted" in green. |

## D. "Rate your squad" after a group

| # | Do this | Expected |
|---|---|---|
| 21 | Stay grouped with the other player for **at least 5 minutes** anywhere outside a dungeon. Then leave the party | About 2 seconds later a small card **slides down** from the top of the screen: three role icons, "Rate your squad", "Group in <zone>, 1 to rate", with a slow gold pulse. It stays until you act. |
| 22 | Fight something while it is showing | It disappears in combat and slides back after the fight. |
| 23 | Click the card | It slides away and SquadRank opens on the **Rate** page. A section header "Group in <zone>  <date>  0/1 rated", then the card; cards **fade in one after another**. |
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
| 34 | Esc > Options > AddOns > SquadRank | 13 controls, including "Show the minimap button", "Warn when an avoided player joins" and "Play sounds". |
| 35 | Untick "Show a toast when a rated player joins". Repeat step 17 | No toast. Tick it again. |
| 36 | Untick "Offer to rate your squad when a group ends". Repeat step 21 | No alert. Tick it again. |
| 37 | Set "Ratings needed for a label" to 1, reopen `/sr` | Players with one rating now show a label instead of "New". Set it back to 3. |
| 38 | `/reload`, reopen the settings | Your changes are still there. |
| 38a | `/sr settings` | The window opens on **Settings**: four sections (Alerts, Reputation, Interface, Your data). The switches show the same values as Blizzard's panel. |
| 38b | Click the "Show the minimap button" switch | The knob **slides** and the minimap button disappears. Click again: it is back. `/sr minimap` does the same. |
| 38c | Click **+** next to "Ratings needed for a label" | The number pops and goes up. Open Esc > Options > AddOns > SquadRank: the slider shows the same number. Set it back to 3. |
| 38d | Click **About** in the sidebar | The page slides in: logo with a soft glow, "SquadRank", version, "by Nivlemoth", three feature cards and the commands. |
| 38e | Click through the sidebar entries quickly | Each page slides in, the blue marker on the left glides to the entry. No flicker, no Lua error. |
| 38f | Open Players, scroll the history drawer and the Rate page with the mouse wheel | Scrolling glides instead of jumping. The thin bar on the right can be dragged. |
| 38g | Leave the party with a group waiting to be rated (as in step 21), then look at the sidebar and the minimap | "Rate" has a gold number; the minimap button has a pulsing gold dot. Click Rate: the waiting groups are there. Rate them all: the number and the dot go away. |

## F. Deleting data

| # | Do this | Expected |
|---|---|---|
| 39 | `/sr purge <name>` and confirm | Chat says "Deleted <name>". They are gone from `/sr`. |
| 40 | `/sr purge all` and confirm | Chat says all data deleted. The list is empty. Settings are unchanged. |
| 41 | `/sr rate Testdummy`, click **3**, paste this into the note box: `|TInterface\Icons\x:16|t hi |Hitem:1|h[x]|h` and press Enter. `/sr`, click Testdummy | The note shows as plain text `hi [x]`. No icon, no color, no link. |

## G. Languages

| # | Do this | Expected |
|---|---|---|
| 42 | `/sr debug` | A line `locale: client enUS, using enUS; 0 translated, 0 rejected, 0 missing keys` (your client's code). |
| 43 | `/sr debug locale deDE`, then `/reload`, then `/sr` | Chat says the override is set. After the reload the window is in German: "Bewerten", "Spieler", "Gruppen", "Einstellungen", "Info". Class and zone names stay in your client language. |
| 44 | In German, open Players, rate someone, click a tag, filter by **Merkmal** | Everything works as in English. Long labels end in "..." and show in full on hover; nothing overflows its button. |
| 45 | `/sr debug` | `locale: client enUS, using deDE (developer override deDE); N translated, 0 rejected, 0 missing keys`. |
| 46 | `/sr debug locale ruRU`, `/reload`, open every page | Cyrillic text shows (not boxes). Section headings are not broken. |
| 47 | `/sr debug locale off`, `/reload` | Back to your client language. Your ratings, tags and notes are exactly as before. |
| 48 | (If you have a Korean or Chinese client) open every page | Text shows with the client's font. On a Latin client with the override, boxes are expected (font limit). |

## H. Group types, bosses, quests

| # | Do this | Expected |
|---|---|---|
| 49 | Group with someone and quest together for 5+ minutes: progress an objective, turn in a quest. Leave the group | The alert appears. `/sr` > **Runs**: the group shows a gold **Questing** label and "Questing in <zone>". Hover it: the quest you turned in under "Quests completed", others under "Quests progressed", and the duration. |
| 50 | Do a dungeon and kill a boss or two | The run shows a blue **Dungeon** label. Hovering lists the bosses by name. On the Rate page the section header says "Dungeon  ·  2 bosses". |
| 51 | (If possible) a raid group outside an instance, a battleground, or a group in a PvP zone | World raid / PvP / World PvP labels. A battleground gives no alert and shows as Skipped. |
| 52 | Runs page: click **Type: All**, pick Dungeon | Only dungeon runs remain. Set it back to All. |
| 53 | Rate someone, open the card: tags | 8 positive tags including "Led the group well"; "Negative tags..." next to the note box shows 8 including "Needed off-spec loot". |
| 54 | About page, click the coffee link, Ctrl+C, paste it in a browser | The link selects itself, cannot be edited, and pastes as buymeacoffee.com/nivlemoth. |
| 55 | `/sr selftest`, `/sr debug` after 49-50 | "events seen" shows QUEST_TURNED_IN and QUEST_WATCH_UPDATE above 0. Send me the line. |

## I. Avoid list, stats, sharing, sounds

| # | Do this | Expected |
|---|---|---|
| 56 | Right-click a party member's frame | Under "Rate in SquadRank": "Add to avoid list". Click it: chat says they are on your avoid list. |
| 57 | Hover that player | Their tooltip has a red line "SquadRank: on your avoid list". Hover someone you rated (not avoided): "SquadRank: <label>, 4.0 from 1 rating". |
| 58 | Leave the group, invite them again | A red toast "A player on your avoid list joined your group" with the raid-warning sound. |
| 59 | `/sr` > Players > **Label: All** > Avoid | Only avoided players, with a red "Avoid" label. Open one: the drawer shows Avoid in red and a **Don't avoid** button. Click it. |
| 60 | Sidebar > **Stats** | Four totals, three lists (names open the history drawer), bars by group type that grow in. |
| 61 | Settings > Your data > turn on "Allow sharing player summaries". Open a player, click **Share** (top right of the drawer) | A box with one line, already selected: Ctrl+C, paste in chat. No notes, no colours. |
| 62 | Enter a dungeon and leave within a minute, then leave the group | No alert. The run is in the Runs tab as Skipped. |
| 63 | Wipe on a boss | Runs tab tooltip shows "1 wipe" for that run. |
| 64 | Settings > Play sounds off; repeat step 58 | The warning shows with no sound. |
| 65 | `/sr selftest` | "TooltipDataProcessor.AddTooltipPostCall" and "PlaySound" rows PASS; `/sr debug` notes show "tooltip: ok". |

## What I most need back

1. The full `/sr debug` text after step 10 and after step 29.
2. Any Lua error text.
3. How the motion feels: too fast, too slow, or right (steps 4, 12, 14, 16, 21, 23, 30, 38e). Screenshots of
   the Rate page with a card open, the Players page with the drawer open, and the minimap button help a lot.
