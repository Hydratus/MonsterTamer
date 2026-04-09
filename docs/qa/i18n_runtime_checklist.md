# i18n Runtime Checklist (Battle + Menus)

Use this checklist after localization changes to quickly validate visible in-game text.

## Test Setup

1. Set language to German in settings.
2. Start from a save/profile with access to:
- battle scene
- party with at least 2 monsters
- inventory with usable healing item
- at least one enemy encounter in overworld/dungeon
3. Keep dev console/output visible while testing.

## Scenario 1: Basic Attack Flow

Goal: confirm translated move names in live battle log.

Steps:
1. Enter a battle.
2. Select a translated move (example key: Drain Bite / Saugbiss).
3. Resolve one normal hit.
4. Resolve one miss (if possible) or repeat until miss text appears.

Expected:
- Battle log uses German move name (example: Saugbiss), not English key (Drain Bite).
- Messages are localized:
- "%s benutzt %s!"
- "%s setzt %s auf %s ein, aber es verfehlt!"

## Scenario 2: Not Enough Energy

Goal: verify low-energy message with localized move name.

Steps:
1. Reduce active monster EN below selected move cost.
2. Try to use that move.

Expected:
- Message appears in German.
- Embedded move name is localized.

## Scenario 3: Rest, Escape, Switch

Goal: verify core action text consistency.

Steps:
1. Use Rest once.
2. Attempt escape once.
3. Switch monster once.

Expected:
- Rest message is German.
- Escape attempt/result text is German.
- Switch text is German.
- No fallback English words in battle box.

## Scenario 4: Trait/Status Text in UI

Goal: verify trait and attack description localization in status views.

Steps:
1. Open battle/pause status view.
2. Open Attacks tab and inspect attack names + descriptions.
3. Open Traits tab and inspect trait names + descriptions.

Expected:
- Names/descriptions are German where translated.
- No raw English content like self, target, enemy in translated entries.

## Scenario 5: Learning Messages

Goal: verify learn notifications use localized names.

Steps:
1. Trigger level-up or scripted learn event.
2. Observe "learned attack" / "learned trait" message.

Expected:
- Template text is German.
- Learned attack/trait names are localized.

## Scenario 6: Item Usage (Battle + Overworld)

Goal: verify item-related text consistency in both contexts.

Steps:
1. Use a healing item in battle.
2. Use a healing item from pause menu on party monster.

Expected:
- Both messages are German.
- Item name is localized if translation exists.
- No "Couldn't use!" English fallback.

## Scenario 7: Forced Switch / KO Flow

Goal: verify forced replacement text path after KO.

Steps:
1. Let active player monster faint.
2. Use forced switch menu to pick replacement.

Expected:
- KO and replacement messages are German.
- Sent-out message uses localized format and no English fallback.

## Scenario 8: Edge Terms Sanity

Goal: verify canonical terminology from styleguide.

Check these terms in UI/messages:
- Seelenessenz
- Run-Gold
- Gegenstaende
- STR/MAG/DEF/RES/SPD/HP/EN

Expected:
- Same term forms are used consistently.

## Fast Failure Indicators

If any of these appears, localization wiring is incomplete:

- English move names in battle log despite translated key existing in de.po
- English words inside German descriptions (self, target, enemy)
- Mojibake characters in text (for example broken arrow glyphs)
- Placeholder mismatch (%s / %d count mismatch)

## Quick Triage

1. Check code path uses TranslationServer.translate or tr for displayed value.
2. Check exact msgid exists in i18n/de.po (including newline and punctuation).
3. Check for encoding/character corruption in po file.
4. Reload project/editor language resources and retest.

## HUB-Focused Pass

For a faster HUB-only validation pass, run:

- `docs/qa/hub_runtime_checklist.md`
- `docs/qa/hub_localization_smoke_test_60s.md` (quick 60s sanity pass)

## Battle-Focused Quick Pass

For a fast battle localization sanity check, run:

- `docs/qa/battle_i18n_smoke_test_60s.md`

## Pause Menu Focus Pass

For input/focus regression checks (especially after language-switch changes), run:

- `docs/qa/pause_menu_focus_regression_checklist.md`
- `docs/qa/pause_menu_focus_smoke_test_60s.md` (quick 60s sanity pass)
