# i18n Styleguide (DE)

This file defines translation conventions for the project.
Use it for all new `msgid`/`msgstr` entries in `i18n/de.po`.

## Scope

- UI labels
- Battle messages
- World/dungeon messages
- Item/attack/trait names and descriptions

## Core Rules

1. Keep placeholders unchanged.
- Example: `%s`, `%d`, `%%`, `\n` must stay exactly in place and order.

2. Keep gameplay abbreviations stable.
- Use: `HP`, `EN`, `STR`, `MAG`, `DEF`, `RES`, `SPD`

3. Use ASCII in German strings.
- Prefer: `ae`, `oe`, `ue`, `ss`
- Example: `zurueck`, `Schluessel`, `moeglich`

4. Use consistent punctuation style.
- Keep exclamation and period style from source where possible.
- Do not add/remove placeholder punctuation accidentally.

5. Translate player-facing text, keep technical keys untouched.
- Translate visible strings.
- Do not translate script/internal identifiers.

## Canonical Terms

Use these forms consistently:

- `Soul Essence` -> `Seelenessenz`
- `Run` -> `Run`
- `run gold` -> `Run-Gold`
- `items` -> `Gegenstaende`
- `trait` -> `Trait`
- `switch` (battle action) -> `Wechseln`
- `status` (menu entry) -> `Status`

## Preferred UI Wording

- `Hover: Attack` -> `Auswahl: Angriff`
- `No items.` -> `Keine Gegenstaende.`
- `Couldn\'t use!` -> `Konnte nicht verwendet werden!`

## Battle Message Guidelines

1. Keep monster/item names dynamic.
- Message templates should keep `%s` placeholders.

2. Keep short tactical feedback concise.
- Example: `Flucht fehlgeschlagen!`

3. Preserve combat readability.
- Avoid long, nested sentences in rapid battle logs.

## Resource Content (Moves/Traits)

When adding new move/trait resources (`data/moves`, `data/traits`):

1. Always add both name and description keys to PO files.
2. Keep naming punchy and descriptions one sentence when possible.
3. Reuse canonical terms and stat abbreviations.

## QA Checklist (Before Commit)

- Placeholder check:
  - `%s`, `%d`, `%%`, `\n` identical between `msgid` and `msgstr`
- Encoding check:
  - No mojibake (`â`, `Ã`, replacement glyphs)
- Terminology check:
  - Canonical terms from this file are used
- Runtime check:
  - No fallback English in changed screens/flows

## Suggested Quick Checks

- Search for mojibake in `i18n/de.po`
- Search for untranslated resource content strings
- Validate diagnostics in changed files
- Run the battle/menu verification flow in `docs/qa/i18n_runtime_checklist.md`
- Run the HUB-only verification flow in `docs/qa/hub_runtime_checklist.md`
