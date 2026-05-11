# Status Effects

Status effects are now implemented as timed ailments on `MTMonsterInstance` and can be applied by attacks.

## Implemented Effects

- `burn`:
  - End of round: loses `6%` max HP.
  - Outgoing physical damage: `-15%`.
- `wet`:
  - Incoming fire damage: `+25%`.
  - Incoming electric damage: `+20%`.
  - Outgoing fire damage: `-15%`.
- `poison`:
  - End of round: loses `8%` max HP.
- `bleed`:
  - End of round: loses `5%` max HP.
- `cursed`:
  - End of round: loses `4%` max HP.
  - Cannot receive healing (including lifesteal and trait HP regen).
- `blind`:
  - Accuracy multiplier: `0.70`.
- `daze`:
  - Accuracy multiplier: `0.85`.
  - `20%` chance to lose action before execution.
- `silence`:
  - Cannot use status-type attacks.
- `root`:
  - Speed multiplier: `0.80`.
- `bind`:
  - Speed multiplier: `0.85`.
  - Accuracy multiplier: `0.90`.
- `sleep`:
  - Cannot act.
- `freeze`:
  - `75%` chance to lose action.
  - On successful action attempt, freeze is removed.
- `paralyze`:
  - Speed multiplier: `0.75`.
  - `30%` chance to lose action.
- `fear`:
  - `25%` chance to lose action.
- `stagger`:
  - Skips next action, then removed immediately.
- `cleanse`:
  - Removes all current negative status ailments from target.

## Attack Data Fields

Added to `MTAttackData`:

- `status_effect` (enum int, `MTStatusAilment.Type`)
- `status_chance` (`0.0..1.0`)
- `status_duration` (rounds, `0` = default duration)
- `status_target_self` (if `true`, apply to actor)

## Runtime Integration

- Status application: `MTAttackAction._apply_status_package()`
- Pre-action skip checks: `MTResolveActionsState._execute_next_action()` via `monster.process_pre_action_status()`
- End-round DOT + duration ticking: `MTMonsterInstance.on_round_end()`
- Damage modifiers from status: `MTDamageCalculator.calculate_damage()`
- Status display in menu: `MTMonsterStatusViewHelper.add_title()`
