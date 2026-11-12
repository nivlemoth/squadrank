# Localizing SquadRank

SquadRank shows its interface in the language of the WoW client (`GetLocale()`). English is the
complete, authoritative catalog; every other language is checked against it and falls back to it.
No libraries, no downloads, no network: all catalogs ship in `Locales/`.

## How it works

| File | Role |
|---|---|
| `Locales/Locale.lua` | The engine: picks the language, checks translations, resolves plurals, provides `ns.L`. Loaded right after `Core/Init.lua`. |
| `Locales/enUS.lua` | English. Every key the code uses is defined here. Writes into `ns.Locale.base`. |
| `Locales/<code>.lua` | One language. Calls `ns.Locale.Register("<code>", function(L) ... end)`. Only the file matching the client language runs its function. |

Order in `SquadRank.toc`: `Locale.lua`, `enUS.lua`, then every other locale file, all before any code that
shows text. A test enforces this.

Supported codes: `enUS` (also used for `enGB`), `deDE`, `frFR`, `esES`, `esMX`, `ptBR`, `itIT`, `ruRU`, `koKR`,
`zhCN`, `zhTW`. Any other code uses English.

## Fallback

Lookup order for `L.KEY`: the client language's string, then English, then the key itself.

- **Unknown locale** (or `GetLocale` missing): English.
- **Missing translation:** English for that string only.
- **Empty or blank translation:** rejected, English shows instead. A label is never blank.
- **Translation whose placeholders or escape codes differ from English:** rejected, English shows instead.
  This prevents a translation from crashing `string.format` or breaking colours.
- **Key unknown to English:** rejected (usually a typo in a locale file).
- **Key missing from English** (a code bug): the key name shows as the label, nothing crashes, and it is logged
  once as `[LOCALE] missing key ...` in `/sr debug`.

`/sr debug` has a `locale:` line: client language, language in use, and how many strings were translated,
rejected and missing. It never prints the strings themselves.

## Add or change a string

1. Add or edit the key in `Locales/enUS.lua`. Use a stable, meaningful name (`BTN_DONE`, `RATE_NOTE_HINT`,
   `TAG_fair_loot`). Never reuse a key for a different meaning; make a new key instead.
2. Use it in code as `L.KEY` (or `ns.Locale.Count("FAMILY", n, ...)` for counts, see below).
3. Add the translation to every `Locales/<code>.lua`. If you can't translate it, leave it out: English
   shows, and the completeness test tells you which keys are missing.
4. Run `bash tools/check.sh`.

Changing the English meaning of a key? Rename the key, so old translations don't silently keep the old meaning.

## Add a language

1. Copy `Locales/deDE.lua` to `Locales/<code>.lua` and change the code in `Register`.
2. Translate every value. Keep the keys.
3. Add the code to `Locale.SUPPORTED` in `Locales/Locale.lua`, and a plural rule to `RULES` if the language
   does not follow English (one / other).
4. List the file in `SquadRank.toc` after `Locales\enUS.lua`, and add the code to `CODES` in
   `spec/l10n_spec.lua`.
5. Optionally add `## Notes-<code>: ...` to the TOC.

## Placeholders and markup

- Keep every `%s`, `%d`, `%.1f` exactly as in English, **in the same order**. WoW's Lua 5.1 has no positional
  arguments (`%1$s`), so if your word order needs a different order, rephrase. A colon form often helps:
  `"Groups: %d, players to rate: %d"`.
- Keep WoW escape codes (`|c...|r`, `|T...|t`, `|H...|h`, `|n`) in the same order. A literal pipe is `||`.
- `\n` line breaks may be added or removed freely.
- Keep slash commands and their words (`/sr rate`, `purge`, `all`, `off`) untranslated: they are what the
  player must type. Translate only the explanation.
- Never translate `SquadRank` (product name) or `Nivlemoth` (author). Keys in `Locale.NEUTRAL` (product name,
  author, chat prefix, layout-only formats such as `%d/%d`) need no translation.
- Keep labels short. Buttons, chips and column headers have fixed widths; longer text is cut with "..." and
  the full text shows in a tooltip, but short is better.

## Plurals

Count strings come in families: `KEY_ONE`, `KEY_FEW`, `KEY_MANY`, `KEY_OTHER`, all with the same placeholders.
The code calls `ns.Locale.Count("KEY", n, ...)`, which picks the form for `n`:

| Language | Forms used |
|---|---|
| English, German, Spanish, Italian | `_ONE` (n = 1), `_OTHER` |
| French, Portuguese (Brazil) | `_ONE` (n = 0 or 1), `_OTHER` |
| Russian | `_ONE` (1, 21, 31...), `_FEW` (2-4, 22-24...), `_MANY` (0, 5-20, 25-30...) |
| Korean, Chinese | `_OTHER` only |

Where a count is exactly 1 the code sometimes uses a separate key with no number at all (`FMT_RATED_ONCE`,
`RATE_HEADLINE_SINGLE`, `DETAIL_AVG_SINGLE`), so English can say "Rated once".

## Stable IDs versus labels

Saved data never contains translated text. Roles (`tank`, `healer`, `dps`), tags (`role_good`, `fair_loot`,
...), reputation labels (`new`, `trusted`, `mixed`, `caution`) and run status (`pending`, `done`, `skipped`)
are stored and compared as these IDs. Filters store the ID too. The label is looked up only when drawing:
`L["TAG_" .. id]`, `L["ROLE_" .. role]`, `L["LABEL_" .. label]`. Changing the client language changes what you
see, never what is saved. Player names, realm names and notes are user content and are never translated.

## Test another language

- **Automated:** `bash tools/check.sh`. `spec/l10n_spec.lua` loads every catalog, checks it is complete, that
  every placeholder and escape code matches English, that every plural form exists for counts 0 to 130, and
  that bad translations fall back. `spec/smoke_spec.lua` plays a session in every language.
- **In game (developer only):** `/sr debug locale deDE`, then `/reload`. SquadRank's own text switches;
  Blizzard's (class names, zone names) stays in the client language. `/sr debug locale off` and `/reload` to go
  back. Korean and Chinese text needs a client with those fonts: on a Latin-alphabet client they may show as
  boxes. That is a font limit of the test, not a bug.

## Translation status

| Code | Language | Status |
|---|---|---|
| enUS | English | Source |
| deDE | German | Machine-assisted, **needs native-speaker review** |
| frFR | French | Machine-assisted, **needs native-speaker review** |
| esES | Spanish (Spain) | Machine-assisted, **needs native-speaker review** |
| esMX | Spanish (Latin America) | Derived from esES with regional terms (calificar, calabozo, computadora), **needs review** |
| ptBR | Portuguese (Brazil) | Machine-assisted, **needs native-speaker review** |
| itIT | Italian | Machine-assisted, **needs native-speaker review** |
| ruRU | Russian | Machine-assisted, **needs native-speaker review** (plural forms especially) |
| koKR | Korean | Machine-assisted, **needs native-speaker review** |
| zhCN | Simplified Chinese | Machine-assisted, **needs native-speaker review** |
| zhTW | Traditional Chinese | Machine-assisted, **needs native-speaker review** |

No translation has been reviewed by a native speaker yet. Role names follow Blizzard's usual in-game terms
for each language (for example Heiler, Soigneur, Sanador, Curador, Guaritore, Лекарь, 치유 전담, 治疗); please
correct them to match the Forever client if it differs.

Points reviewers should look at first:
- Tag names (`TAG_*`): they must read as **how the player did in this run**, not as a judgement of the person
  overall. Reputation labels (`LABEL_*`) are the overall summary.
- `SET_RECENT`: should match Blizzard's own name for the Recent Allies list in that language.
- Gendered wording: German, French, Spanish, Portuguese, Italian and Russian use the masculine form for
  "player" and adjectives (for example "Nuevo", "Tóxico", "Toxique"). Russian `CONFIRM_PURGE_PLAYER` uses
  "него".
- Width: German and Russian labels are the longest; check buttons and tag chips for "..." cut-offs.
