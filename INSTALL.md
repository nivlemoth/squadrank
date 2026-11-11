# Installing SquadRank 0.1.0 (WoW Forever)

## Install

1. Close World of Warcraft, or be at the character selection screen.
2. Find the Forever AddOns folder. It is inside your World of Warcraft install folder:

   ```
   World of Warcraft\_forever_\Interface\AddOns
   ```

   The `_forever_` name is the expected one but has not been confirmed on your machine. Look for the
   folder next to `_retail_` and `_classic_era_` that belongs to Forever. If `Interface\AddOns` does not exist
   inside it yet, create both folders.
3. Copy the whole `SquadRank` folder into `AddOns`, so that this file exists:

   ```
   ...\Interface\AddOns\SquadRank\SquadRank.toc
   ```

   The folder must be named exactly `SquadRank`.
4. Start the game. On the character selection screen click **AddOns** and check that SquadRank is listed and ticked.

From this project folder, one command does the copy (edit the destination path first):

```
robocopy "Z:\CZ\WoW Addons\SquadRank" "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\SquadRank" /MIR /XD .git spec tools docs .release /XF *.md .luacheckrc stylua.toml .pkgmeta
```

`/MIR` makes the destination an exact copy and removes files there that are no longer in the project.
Your saved data is not in that folder, so it is safe.

## What the game needs

Only these are loaded by the game: `SquadRank.toc` and the folders `Core`, `Data`, `Track`, `UI`, `Locales`,
`Integrations`. Everything else (docs, tests, tools) is ignored by the client.

## Update

Copy the folder again over the old one (or rerun the robocopy command), then type `/reload` in game.

## Where your data lives

```
World of Warcraft\_forever_\WTF\Account\<ACCOUNT>\SavedVariables\SquadRank.lua
```

It holds two tables: `SquadRankDB` (players, ratings, runs, settings) and `SquadRankDebug` (the last debug
report). The file is written when you log out or `/reload`, not while you play. Copy it somewhere to back it up.

## Uninstall

Delete the `SquadRank` folder from `AddOns`. To remove your data too, delete the `SquadRank.lua` file above.

## First check

Type `/sr selftest`, then `/sr debug`. Then follow `TESTING.md`.
