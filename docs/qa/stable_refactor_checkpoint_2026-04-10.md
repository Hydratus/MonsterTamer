# Stable Refactor Checkpoint (2026-04-10)

## Status
- Refactor/Hardening pass for Battle, UI, and World is in a stable diagnostic state.
- Last edited high-risk files compile clean in editor diagnostics.
- Remaining verification is runtime-focused (smoke runner and short manual pass).

## Scope Covered
- Battle flow hardening and adapter/bridge stabilization.
- Null-safe name/data access in battle actions and UI render paths.
- Pause/Item menu lifecycle and signal safety cleanup.
- World helper guard consistency (`Game` access through checked local refs).
- Dungeon/overworld interaction and reward paths made more defensive.
- Localization fallback key coverage updated for `Unknown` in both `de.po` and `en.po`.

## Key Files Touched (Representative)
- `core/battle/actions/attack_action.gd`
- `core/battle/actions/item_action.gd`
- `core/battle/actions/rest_action.gd`
- `core/battle/actions/escape_action.gd`
- `core/battle/actions/switch_action.gd`
- `core/battle/ui/battle_menu.gd`
- `core/battle/ui/battle_hud.gd`
- `core/battle/ui/battle_scene_adapter.gd`
- `ui/menus/pause_menu.gd`
- `ui/menus/item_menu.gd`
- `core/ui/monster_status_view_helper.gd`
- `core/world/overworld.gd`
- `core/world/dungeon_scene.gd`
- `core/world/dungeon_run_helper.gd`
- `core/world/dungeon_shop_ui_helper.gd`
- `core/world/dungeon_quest_helper.gd`
- `core/world/npc_controller.gd`

## Open Follow-up
1. Execute a short manual playtest for:
   - capture + forced switch
   - escape allowed/blocked cases
   - merchant buy + item usage
   - quest turn-in and rewards
2. Patch only if runtime regressions are observed.

## Validation Mode
- Selected mode: Manual release gate.
- Reason: Runner executions from VS Code crash the editor in this environment.
- Optional fallback: External script remains available in tools/run_battle_smoke_external.ps1.

## Quick Gate
- Use the fast gate checklist in docs/qa/battle_go_no_go_60s.md before release.

## Test Delta In This Checkpoint
- Added high-value battle smoke integrations in `core/battle/tests/battle_smoke_tests.gd`:
   - `player_item_submit_heals_self`
   - `player_action_gating_requires_all_human_inputs`
   - `perform_switch_updates_active_monster`

## Exit Criteria For This Checkpoint
- No new diagnostics in touched files.
- No unresolved high-severity runtime blockers reported from manual smoke.
- Any remaining work is feature work or non-critical polish.

## Manual Decision Log
- Date: 2026-04-10
- Tester: User
- Result: GO
- Notes: Manual go/no-go checklist completed successfully. All checks reported as successful.
