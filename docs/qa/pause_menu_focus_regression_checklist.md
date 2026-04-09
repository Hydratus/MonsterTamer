# Pause Menu Focus Regression Checklist

Use this checklist after pause menu input, focus, or language-switch changes.

Need a very fast pre-commit check first?
- docs/qa/pause_menu_focus_smoke_test_60s.md

## Preconditions

1. Start in HUB or any overworld area where pause menu can open.
2. Keyboard controls active (`ui_accept` on space).
3. Optional: gamepad connected for D-Pad/A testing.
4. Open pause menu once before running scenarios.

## Scenario 1: Dropdown Open via Select Button

Goal: verify keyboard/gamepad select opens OptionButton dropdowns.

Steps:
1. Open pause menu.
2. Go to Settings -> Video.
3. Focus `Language`, `Window Mode`, and `Resolution` one by one.
4. Press select (`ui_accept`, usually space / gamepad A).

Expected:
- Focused dropdown opens without mouse.
- Item can be selected and applied.
- No focus loss to unrelated sidebar buttons.

## Scenario 2: Language Switch While Inside Settings

Goal: ensure no stale-focus errors after rebuilding localized UI.

Steps:
1. Open pause menu -> Settings -> Video.
2. Focus `Language` dropdown.
3. Switch between German and English.
4. Immediately press up/down several times.

Expected:
- No runtime error about previously freed instance.
- Focus remains within Settings controls.
- Labels update to selected language.

## Scenario 3: Continue Navigation After Language Change

Goal: verify navigation arrays are still valid after rebuild.

Steps:
1. After switching language, continue with:
- up/down through Video controls
- left/right to switch tabs
- back (`ui_cancel`) to sidebar
2. Enter Settings again and repeat once.

Expected:
- No dead focus target.
- No soft lock.
- No crash or error spam in output.

## Scenario 4: Team List Focus Safety

Goal: ensure team list navigation never targets freed buttons.

Steps:
1. Open Team section in pause menu.
2. Move focus through list with up/down.
3. Open one monster -> Status, then Back.
4. Open one monster -> Switch, then Back.

Expected:
- Focus returns to a valid team entry.
- Scroll follows focused entry.
- No freed-instance focus errors.

## Scenario 5: Team Sub-Menu Focus Safety

Goal: verify sub-navigation list remains stable.

Steps:
1. In Team options, navigate `Status` and `Switch` using up/down.
2. Open Status view, switch tabs, and return.
3. Open Switch view and cancel back.

Expected:
- Focus always lands on visible, interactable buttons.
- No invalid grab_focus calls.

## Scenario 6: Controls Tab Focus Safety

Goal: verify controls-page focus navigation remains valid.

Steps:
1. Open Settings -> Controls.
2. Move up/down through keyboard/controller mapping buttons.
3. Trigger one rebind prompt, then cancel.
4. Continue moving focus up/down.

Expected:
- Focus movement remains stable.
- No stale references in control button/header mapping.
- No runtime errors.

## Fast Failure Indicators

- `Cannot call method 'grab_focus' on a previously freed instance`.
- Focus disappears and cannot be recovered by navigation keys.
- Up/down input stops reacting while menu is still open.
- Dropdown only opens by mouse, not by select button.

## Quick Triage

1. Prune navigation arrays before indexing/focus calls.
2. Validate `is_instance_valid(...)` before `grab_focus()`.
3. Reset focus state after UI rebuild (language switch paths).
4. Retest in both keyboard and gamepad input modes.
