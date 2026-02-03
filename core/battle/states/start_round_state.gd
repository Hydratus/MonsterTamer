extends BattleState
class_name StartRoundState

func enter(battle):
	print("--- Round Start ---")
	if battle.scene != null and battle.scene.has_method("update_hud_with_active"):
		battle.scene.update_hud_with_active()
	var logger := Callable(battle, "log_message")

	# Verarbeite Round-Start-Effekte für beide aktiven Monster
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster == null or not monster.is_alive():
			continue

		for trait_effect in monster.passive_traits:
			if trait_effect.round_start_stages == 0:
				continue

			var delta: int = monster.modify_stat_stage(
				trait_effect.round_start_stat,
				trait_effect.round_start_stages
			)

			var stat_name: String = MonsterInstance.StatType.keys()[
				trait_effect.round_start_stat
			]

			var intended: int = trait_effect.round_start_stages
			var sign_prefix := "+" if intended > 0 else ""

			# ❌ Änderung nicht möglich (Limit erreicht)
			if delta == 0:
				logger.call(
					"%s tried to gain %s%d %s due to Trait \"%s\", but it failed!"
					% [
						monster.data.name,
						sign_prefix,
						abs(intended),
						stat_name,
						trait_effect.name
					]
				)
				continue

			# ✅ Änderung erfolgreich
			logger.call(
				"%s gains %s%d %s due to Trait \"%s\"."
				% [
					monster.data.name,
					sign_prefix,
					abs(delta),
					stat_name,
					trait_effect.name
				]
			)

	if battle.scene != null and battle.scene.message_box.current_action_messages.size() > 0:
		battle.scene.message_box.flush_action_messages()
		battle.scene.show_battle_messages()
		return

	battle.change_state(CollectActionsState.new())

func on_messages_completed(battle):
	battle.change_state(CollectActionsState.new())
