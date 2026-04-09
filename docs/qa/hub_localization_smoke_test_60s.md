# HUB Localization Smoke Test (60s)

Use this before commit for a quick HUB-only localization sanity pass.

## Setup (5s)

1. Language set to German.
2. Stand in HUB near one dialogue NPC and one item/battle NPC.

## Run (about 45s)

1. Talk to a normal HUB NPC once.
2. Trigger one item reward or battle-intro interaction.
3. Open pause menu and visit Team and Settings once.
4. Close menu and advance one queued message.

## Pass Criteria (about 10s)

- NPC dialogue appears in German.
- Reward/prompt lines are German (including item names when translated).
- Pause menu labels are German and stable.
- No mojibake and no English fallback prompt.

## Fail Fast Signals

- English NPC display name in HUB interaction text.
- English rune/item names in reward lines.
- Fallback prompt appears in English (Choose a dungeon).
- Corrupted characters (for example fÃ¼r).
