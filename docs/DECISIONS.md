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
