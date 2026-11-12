# Decisions and assumptions (v0.1)

Logged while building without stopping to ask. Newest at the bottom.

1. **Test runner.** busted could not be installed: it needs a C compiler (for luafilesystem and friends) and
   this machine has none. Tests run on LuaJIT (Lua 5.1 language level) through `spec/run.lua`, a small runner
   that implements the subset of the busted API the specs use. The spec files also run under real busted.
   luacheck uses `std = "lua51"`, so LuaJIT-only syntax would be flagged.
2. **Git identity.** No git user was configured. Set for this repository only: name "John", the account email.
3. **Sanitizer.** Our own Lua code strips escapes; `C_StringUtil.StripHyperlinks` is not used, so behaviour is
   the same in tests and in game. `||` (escaped pipe) is removed entirely.
4. **Read-only mode.** If the saved database has a newer schema than the addon, or a migration fails, the addon
   runs on a throwaway in-memory table and never assigns `SquadRankDB`, so the saved file stays untouched.
5. **Backup.** One backup (`SquadRankDB.backup`) is kept, taken before a migration, and only when the old
   database held data. "Purge all" removes it too.
6. **Names.** The second value of `UnitName` is stored as `suffix` exactly as returned (realm or surname).
   The addon never splits a combined name from the client. Text typed by the user after `/sr rate` is split
   at the first dash.
7. **No ESC-to-close.** Closing with Escape needs either a global frame name (breaks the one-global rule) or
   keyboard propagation calls that are restricted in combat. Windows close with their X button.
8. **Role required.** A rating needs a role; the form preselects group role, else last rated role, else DPS.
9. **Run end.** Leaving the group, entering another instance, or 5 minutes outside. A saved run older than
   4 hours is never resumed. Runs with no other member are discarded.
10. **Run prompt states.** `pending` until every member is rated (`done`) or the user clicks "Stop asking"
    (`skipped`). "Later" leaves it pending; `/sr rate` reopens the newest pending run.
11. **Extra file.** `Data/Session.lua` holds the "toast once per group" logic so it can be unit-tested; the
    plan had it inside `Track/Roster.lua`.
12. **Commits.** The pure data modules (database, players, ratings, runs, session) were written together and
    committed as "Steps 0-2"; step 4 therefore has no commit of its own. The TOC in the step 3 to 6 commits
    listed only the first 17 files (an edit silently did not apply); it was fixed in the step 8 commit.
    Only the head of `v0.1` is a loadable build.
13. **Reading in combat.** "All DB reads and writes out of combat" is applied to the UI too: windows do not
    open or refresh in combat, and slash commands that read data print a short message instead.
14. **Smoke test.** Because the game client cannot be run from here, `spec/smoke_spec.lua` loads every TOC
    file against a fake client (`spec/wowmock.lua`) and plays a session. The fake accepts any frame method,
    so it proves load order and our logic, not that Blizzard's templates look or behave as expected.
15. **ScrollBox safety valve.** Lists use ScrollBox when it can be created, otherwise a recycled-row list.
    `/sr debug lists` followed by `/reload` forces the simple list, in case ScrollBox creates but misbehaves.
16. **Toast for several players.** When more than one rated player is new at once (you join a formed group),
    one combined toast lists up to five of them with label and top tag.
17. **Typed names.** `/sr rate <name>` for a player never seen creates a name-keyed record at once. If it is
    never rated it is removed by pruning after 180 days. When that player is later seen in a group, the
    record is re-keyed to their GUID.
18. **Recent Allies scope.** The only use is a GUID lookup for a typed name. Nothing is imported from the list.
19. **Icon.** The four legacy PNG files were removed from the addon (kept in git history). The TOC points at a
    built-in icon whose name has not been checked in the Forever client.
20. **SAVED_VARIABLES_TOO_LARGE.** Handled with a log line and a chat warning only. Pruning (300 runs,
    50 ratings per player, unrated players after 180 days) is the real protection.

## 0.2.0: rating flow redesign (2026-11-11)

John asked for fewer clicks, rating at a convenient time (after the group breaks up) and smooth motion.

21. **One click per player.** A score click saves the rating at once; there is no Save button. Role, tags and
    note are optional and saved as they change. Reopening a run edits its ratings (as before). Rating a player
    outside a run starts a new rating each time the window opens; changes in that window edit it.
22. **Tags shown by score.** After a score, the card shows the 7 tags that fit it (positive for 3 to 5,
    negative for 1 and 2) and a link to the other 7. This keeps every open card the same height, so the cards
    below do not jump while you click down the list.
23. **Open-world groups are runs too.** Any group outside an instance becomes a run of kind "group", named
    after the zone. It is kept only if it lasted 5 minutes or more. If the group walks into a dungeon, the same
    run becomes the dungeon run. If a dungeon run ends while the group stays together, the group carries on as
    a new group run linked to it (`after`); that run is dropped when nobody new joined, so the same squad is
    not offered twice.
24. **Alert instead of a timed prompt.** The 45-second "Rate / Later" toast is replaced by a persistent alert
    that appears only when you are not in a group and not in combat, and has no timeout. Clicking it or
    closing it records `alertDismissedAt`; it then waits for runs that end later. Old runs stay in the Runs tab
    and under `/sr rate`. The alert covers runs that ended in the last 3 days.
25. **Several runs, one window.** The alert opens every run it stands for in one window, one section per run.
    "Skip all" marks them skipped (the old "Stop asking").
26. **No chat line per save.** The checkmark and progress bar on the card replace "Saved your rating for X".
27. **Combat.** The rating window hides when combat starts and fades back when it ends; the alert hides and
    returns too. DB writes stay out of combat as before.
28. **Motion.** Height, offset and alpha changes run on one OnUpdate frame that stops when idle
    (`UI/Anim.lua`). Pops and the alert pulse use Blizzard animation groups. If an animation API is missing,
    the UI still works without motion; `/sr selftest` reports it.
29. **Version 0.2.0.** Bumped so the AddOns list shows which build is loaded. No database change; schema stays 1.

## 0.3.0: one window, minimap button, new look (2026-11-11)

30. **One window.** John found three separate windows (list, history, rating) clunky. Everything now lives
    in one window with a sidebar: Rate, Players, Runs, Settings, About. Pages switch in place with a short
    slide and fade. A player's history is a drawer that slides in over the right of the Players page, so the
    list stays in view. The old `MainWindow`, `PlayerDetail` and `RateFrame` modules keep their public
    functions, so slash commands, menus and toasts did not change.
31. **Own flat look instead of Blizzard panel art.** Dark flat surfaces, hairline borders and one blue accent
    (the colour of the chat prefix), drawn with colour textures only. This looks the same on every client,
    needs no templates (several, such as `ScrollFrameTemplate`, are absent in Forever), and matches what
    current popular addons look like. The colours live in `UI.C` in `UI/Widgets.lua`.
32. **Smooth scrolling written by hand.** The rating cards and the history drawer use a plain ScrollFrame
    whose mouse wheel glides (0.22 s ease-out) with a slim draggable bar (`UI.SmoothScroll`). The player and
    run lists keep Blizzard's ScrollBox, which already scrolls smoothly and recycles rows.
33. **Minimap button by hand, no LibDBIcon.** Zero third-party libraries is a project rule, so the button is
    about 150 lines in `UI/MinimapButton.lua`: left-click opens SquadRank, right-click opens Settings, drag
    moves it round the minimap (angle saved in `settings.minimapAngle`). The border art is the classic minimap
    file textures; if Forever lacks them, the icon still shows without a ring. It can be hidden from Settings,
    Blizzard's options panel or `/sr minimap`. The Addon Compartment entry stays.
34. **Settings in the window too.** The Settings page edits the same saved table as Blizzard's panel, which
    reads that table live, so both always agree. New setting `minimapButton` (default on); Blizzard's panel
    gained that checkbox (8 controls).
35. **No Esc-to-close.** Esc closing needs either a named global frame in `UISpecialFrames` (a second
    global, against the rules) or taking keyboard input with `SetPropagateKeyboardInput`, which is restricted
    in combat. Safest option: the close cross, `/sr`, the minimap button and the compartment all toggle the
    window.
36. **Rate page by itself.** Opening the Rate page from the sidebar shows every group still waiting (up to 6,
    newest first), or an "All caught up" state. A count of players waiting shows on the Rate entry and as a
    pulsing gold dot on the minimap button.
37. **Author credit.** "by Nivlemoth" on the About page and at the foot of the sidebar, as John asked.
38. **Version 0.3.0.** No database change; schema stays 1. Two new settings keys get defaults on load.

## Localization (2026-11-12, no version bump)

39. **Own small locale engine, no library.** The project already had one `L` table and a "zero third-party
    libraries" rule, so `Locales/Locale.lua` (about 250 lines) extends it instead of adding AceLocale. English
    stays the complete base catalog; only the file for the client language runs, so the other nine cost
    load time but no lookups.
40. **Language = `GetLocale()` only.** Never realm, faction or OS. enGB uses enUS. Unknown codes use English.
    A developer override (`/sr debug locale <code>` + `/reload`) is stored in `settings.devLocale` and read
    from the raw SavedVariable at load (possible because the TOC has `LoadSavedVariablesFirst`). It only
    accepts four-letter codes and changes no rating data.
41. **Translations are checked before use.** Unknown keys, blank values, and values whose `%` placeholders
    or `|` escape codes differ from English are dropped (English shows) and counted in `/sr debug`. A
    missing English key shows the key name and is logged once; it never raises an error.
42. **No data migration.** Saved data already used language-independent IDs for roles, tags, reputation
    labels and run status, and filters compare IDs. Nothing stored was English display text, so no schema
    change, no backup, nothing to roll back. The 1.x importer's check for an unknown name now also accepts
    the client's localized `UNKNOWNOBJECT`, so a French 1.x file skips "Inconnu" the way an English one skips
    "Unknown".
43. **Plurals as key families.** Count strings use `_ONE/_FEW/_MANY/_OTHER` variants picked by CLDR rules
    (English-like, French/Portuguese 0-1, Russian three forms, Korean/Chinese none). This also fixes the
    English "1 ratings" in `/sr list` and "1 players" in the minimap tooltip. Strings with two counts use a
    colon form ("Groups: %d, players to rate: %d") so no language needs agreement for them. Seven keys the code no
    longer used were removed from the catalog; a few keys were renamed so `_ONE`/`_MANY` is reserved for
    plural forms.
44. **Long and non-Latin text.** Flat buttons, tag chips, sidebar entries, stat tiles, settings hints and the
    rating card subtitle now have fixed label widths: text that does not fit ends in "..." and the full text
    shows in a tooltip (`FontString:IsTruncated`). Small headings were upper-cased with `string.upper`, which
    only knows ASCII and would mangle "Ä" or Cyrillic; `UI.Caps` now leaves non-ASCII text as written. No
    fonts were changed: every SquadRank font object inherits Blizzard's base fonts, which Forever defines
    with Korean, Simplified Chinese, Traditional Chinese and Russian alphabets (Blizzard_Fonts_Shared).
45. **What stays English.** Product name, author name, the chat prefix, the developer debug report body and
    self-test row names (they are sent to the developer; the window, buttons and chat summary are
    translated), and slash command words.
46. **Locales and Forever.** Forever's UI source (`forever` @ 4cd0ab7) documents `GetLocale()` and ships
    font families for Korean, Chinese and Cyrillic, but it does not say which client languages Blizzard
    sells for Forever. SquadRank ships all ten catalogs; a language Forever does not offer simply never loads.

## Group types, bosses, quests, loot tag, support link (2026-11-12, still 0.9.0-beta)

47. **Seven group types, worked out on display.** `Runs.Category(run)` returns quest, world, dungeon, raid,
    worldraid, pvp or wpvp from fields the run already has (instance type) or gathers while grouped (raid
    group seen, PvP zone seen, quests recorded). Nothing is stored as a type, so runs saved before this
    change get a type too and no migration is needed. Priority for open-world groups: world PvP, then world
    raid, then questing, then open world.
48. **World PvP** means the group was in a zone whose `C_PvP.GetZonePVPInfo()` type is "combat" or "arena".
    War Mode alone is not enough: a War Mode questing group is still questing. **World raid** means a raid
    group outside an instance (world bosses, raid questing).
49. **Battlegrounds and arenas are now tracked** (instance types "pvp" and "arena"). A battleground holds
    up to 40 strangers, so its run is stored with prompt "skipped": no alert, still rateable from the Runs
    tab. Arenas prompt like dungeons. Battleground members are recorded as players like any other group;
    unrated ones are pruned by the existing 180-day rule.
50. **Quests by ID.** `QUEST_TURNED_IN` marks a quest completed, `QUEST_WATCH_UPDATE` marks it progressed,
    both only while a run is open. The title from `C_QuestLog.GetTitleForQuestID` is kept as a fallback
    and looked up again when shown (so it follows the client language when cached). Capped at 40 quests and
    30 bosses per run.
51. **Bosses with names.** `ENCOUNTER_END` (success only) and `BOSS_KILL` both report a boss; the encounter
    ID makes each boss count once per run, whichever event arrives. `bossKills` stays as the count for old
    code and old runs.
52. **Combat.** These events fire in combat, when the database must not be written. They wait in a small
    in-memory queue (60 items) and are applied with the next run check out of combat.
53. **Loot tag.** New negative tag "Needed off-spec loot" next to "Ninja looted", and a positive "Led the group
    well" so both sides keep the same count (8 and 8). The two rows of tag chips are now full; the
    "Negative/Positive tags..." link moved next to the note box, so the card height is unchanged.
54. **Support link.** The About page shows `buymeacoffee.com/nivlemoth` in a read-only text box that selects
    itself on click for Ctrl+C. Addons cannot open web pages and SquadRank makes no network calls, so copy
    and paste is the only option. The link is not translated.

## Avoid list, stats, sharing, wipes, sounds, short visits (2026-11-12, still 0.9.0-beta)

55. **Avoid list = a flag on the player** (`rec.avoid = true`), never a label string. Set from the player list
    menu, the history drawer or the party frame's right-click menu (which saves the player first). When an
    avoided player joins, a red toast with the raid-warning sound appears, even if join toasts are off
    (own setting, default on). They are listed under the "Avoid" option of the Label filter and on the
    Stats page. Group-finder applicants are **not** checked: Forever's group finder (VanillaStyle) applicant
    API is not verified, so this is left out rather than guessed.
56. **Tooltip line.** Hovering a player you rated adds one line (label, average, count) or the red avoid
    warning, via `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit)`. Never in combat (no
    database reads in combat), never for unknown players, never creates a record (`Players.Lookup`).
    Setting "Show SquadRank in player tooltips", default on.
57. **Short visits.** A dungeon or raid run shorter than `minRunMinutes` (default 3, 0 to 30) is stored with
    prompt "skipped": it stays in the Runs tab and can be rated there, but no alert. Open-world groups keep
    their own 5-minute rule.
58. **Stats page** (new sidebar entry): totals (groups, hours, bosses, quests), most grouped with, highest
    rated (2+ ratings), the avoid list, and groups by type. Computed on display by `Data/Stats.lua` (pure,
    unit-tested); nothing new is saved.
59. **Sharing is opt-in** (setting off by default). The Share link in the history drawer offers one plain
    line to copy into chat: name, label, average, count, role averages and up to three tags. Notes are never
    included, colour and escape codes are stripped. Nothing is sent by the addon itself.
60. **Wipes.** `ENCOUNTER_END` with success 0 adds a wipe to the current run, queued like bosses. Shown in
    the run summary and tooltip.
61. **Sounds** use Blizzard sound kits (`SOUNDKIT.IG_PLAYER_INVITE` for the rating alert, `TELL_MESSAGE`
    for join toasts, `RAID_WARNING` for avoid warnings), one setting for all (default on).
