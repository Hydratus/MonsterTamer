extends MTBattleState
class_name MTStartRoundState

func enter(battle):
	print("--- Round Start ---")
	if battle.scene != null and battle.scene.has_method("update_hud_with_active"):
		battle.scene.update_hud_with_active()
	var logger := Callable(battle, "log_message")

	var ordered_entries := _get_round_start_entries(battle)
	for entry in ordered_entries:
		var monster: MTMonsterInstance = entry.monster
		for trait_effect in monster.passive_traits:
			if trait_effect == null:
				continue
			var message_count_before := 0
			if battle.scene != null and battle.scene.message_box != null:
				message_count_before = battle.scene.message_box.current_action_messages.size()

			_apply_round_start_trait(logger, monster, trait_effect)

			if battle.scene == null or battle.scene.message_box == null:
				continue
			if battle.scene.message_box.current_action_messages.size() > message_count_before:
				battle.scene.flush_action_messages()

	if battle.scene != null and battle.scene.message_box.current_action_messages.size() > 0:
		battle.scene.flush_action_messages()
		battle.scene.show_battle_messages()
		return

	battle.change_state(MTCollectActionsState.new())

func on_messages_completed(battle):
	battle.change_state(MTCollectActionsState.new())

func _get_round_start_entries(battle) -> Array:
	var entries: Array = []
	for team_index in range(battle.teams.size()):
		var team = battle.teams[team_index]
		if team == null:
			continue
		var monster = team.get_active_monster()
		if monster == null or not monster.is_alive():
			continue
		entries.append({
			"monster": monster,
			"team_index": team_index,
			"initiative": monster.get_speed()
		})

	entries.sort_custom(func(a, b):
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		return a.team_index < b.team_index
	)
	return entries

func _apply_round_start_trait(logger: Callable, monster: MTMonsterInstance, trait_effect: MTTraitData) -> void:
	for stat_modifier in trait_effect.round_start_stat_stage_modifiers:
		if stat_modifier == null or stat_modifier.stage_change == 0:
			continue

		var delta: int = monster.modify_stat_stage(
			stat_modifier.stat,
			stat_modifier.stage_change
		)

		var stat_name: String = MTMonsterInstance.StatType.keys()[stat_modifier.stat]
		var intended: int = stat_modifier.stage_change
		var sign_prefix := "+" if intended > 0 else ""

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
