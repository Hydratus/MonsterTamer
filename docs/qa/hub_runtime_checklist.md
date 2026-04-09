# HUB Runtime Checklist (Localization)

Use this focused checklist to validate HUB-area localization quickly.

Need a very fast pre-commit check first?
- docs/qa/hub_localization_smoke_test_60s.md

## Preconditions

1. Language is set to German.
2. You are in the HUB area (`hub_city`).
3. At least one test NPC is present and interactable.
4. Message box and pause menu can be opened.

## Scenario 1: Guild Guide Prompt

Goal: Verify dungeon entry prompt localization.

Steps:
1. Talk to the Guild Guide NPC.
2. Trigger the dungeon selection interaction.

Expected:
- NPC display name is localized.
- Dialogue is localized (for example: `Bereit fuer den Test-Dungeon?`).
- Fallback prompt is localized (`Waehle einen Dungeon`) if no dialogue text is present.

## Scenario 2: NPC Item Reward Text

Goal: Verify reward lines and item names are localized.

Steps:
1. Interact with item-giving NPC (for example Test NPC 2).
2. Receive one or more items.

Expected:
- Intro dialogue is localized (for example: `Hier fuer dich:`).
- Reward lines are localized:
- `%s erhalten.`
- `%s x%d erhalten.`
- Item names inside reward lines are localized (no English rune names).

## Scenario 3: NPC Battle Intro in HUB

Goal: Verify NPC display name and battle pre-text localization.

Steps:
1. Interact with an NPC that starts a battle.
2. Observe pre-battle dialogue and battle header text.

Expected:
- Pre-battle dialogue is localized.
- NPC enemy name in battle UI uses localized display name.
- No English fallback in opening battle lines.

## Scenario 4: Pause Menu in HUB

Goal: Verify pause/menu labels while in HUB context.

Steps:
1. Open pause menu in HUB.
2. Navigate through Team, Inventory, Settings.

Expected:
- Menu entries are localized.
- No mixed-language labels.

## Scenario 5: HUB Message Queue

Goal: Verify queued messages remain localized across multiple interactions.

Steps:
1. Trigger two to three interactions in sequence (dialogue + item reward + battle trigger).
2. Advance message queue with interact key.

Expected:
- Every queued line remains German.
- No mojibake or broken glyphs in messages.

## Fast Failure Indicators

- English NPC display name in HUB dialogue.
- English item/rune names in reward lines.
- English fallback prompt (`Choose a dungeon`).
- Corrupted text (for example `fÃ¼r`, broken arrows/glyphs).

## Quick Triage if Something Fails

1. Check source resource text in `data/npc/*.tres`.
2. Verify matching `msgid` exists in `i18n/de.po` exactly (same punctuation/newlines).
3. Confirm runtime path uses `TranslationServer.translate(...)` / `tr(...)`.
4. Reload project/editor and retest.
