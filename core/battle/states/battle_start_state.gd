extends MTBattleState
class_name MTBattleStartState

func enter(battle):
	print("=== Battle Start ===")
	if battle.scene != null and battle.scene.has_method("update_hud_with_active"):
		battle.scene.update_hud_with_active()

	battle.log_message(TranslationServer.translate("A battle begins!"))
	if battle.scene != null:
		battle.scene.flush_action_messages()

	var player_active = battle.get_active_monster(0)
	var enemy_active = battle.get_active_monster(1)

	if player_active != null:
		battle.log_message(TranslationServer.translate("Player uses %s") % player_active.data.name)
		if battle.scene != null:
			battle.scene.flush_action_messages()

	if enemy_active != null:
		battle.log_message(TranslationServer.translate("Enemy uses %s") % enemy_active.data.name)
		if battle.scene != null:
			battle.scene.flush_action_messages()

	if battle.scene != null and battle.scene.message_box.message_queue.size() > 0:
		battle.scene.show_battle_messages()
		return

	battle.change_state(MTStartRoundState.new())

func on_messages_completed(battle):
	battle.change_state(MTStartRoundState.new())
