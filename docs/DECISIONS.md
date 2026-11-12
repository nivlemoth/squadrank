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
