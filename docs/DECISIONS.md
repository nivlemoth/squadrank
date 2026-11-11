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
