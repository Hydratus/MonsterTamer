extends MTBattleState
class_name MTBattleStartState

func enter(battle):
	battle.update_hud_with_active()

	battle.log_message(TranslationServer.translate("A battle begins!"))
	battle.flush_action_messages()

	var player_active = battle.get_active_monster(0)
	var enemy_active = battle.get_active_monster(1)

	if player_active != null:
		battle.log_message(TranslationServer.translate("Player uses %s") % player_active.data.name)
		battle.flush_action_messages()

	if enemy_active != null:
		battle.log_message(TranslationServer.translate("Enemy uses %s") % enemy_active.data.name)
		battle.flush_action_messages()

	if battle.has_queued_messages():
		battle.show_battle_messages()
		return

	battle.change_state(MTStartRoundState.new())

func on_messages_completed(battle):
	battle.change_state(MTStartRoundState.new())
