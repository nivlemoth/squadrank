#!/usr/bin/env bash
# Format, lint and test. Run from anywhere: bash tools/check.sh
# Override tool paths with STYLUA, LUACHECK, LUA if they are not where this machine has them.
set -e
cd "$(dirname "$0")/.."

WINGET="$HOME/AppData/Local/Microsoft/WinGet/Packages"
STYLUA="${STYLUA:-$(command -v stylua || echo "$WINGET/JohnnyMorganz.StyLua_Microsoft.Winget.Source_8wekyb3d8bbwe/stylua.exe")}"
LUACHECK="${LUACHECK:-$(command -v luacheck || echo "$HOME/bin/luacheck.exe")}"
LUA="${LUA:-$(command -v busted || command -v luajit || echo "$HOME/AppData/Local/Programs/LuaJIT/bin/luajit.exe")}"

echo "== stylua"
"$STYLUA" Core Data Track UI Locales Integrations spec .luacheckrc

echo "== luacheck"
"$LUACHECK" . --no-color -q

echo "== tests"
case "$LUA" in
*busted*) "$LUA" spec ;;
*) "$LUA" spec/run.lua ;;
esac
