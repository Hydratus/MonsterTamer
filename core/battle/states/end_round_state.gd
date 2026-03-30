extends MTBattleState
class_name MTEndRoundState

func enter(battle):
	print("--- Round End ---")
	var logger := Callable(battle, "log_message")

	# 🔁 Round-End-Hooks (Regeneration etc.) für aktive Monster
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster != null and monster.is_alive():
			monster.on_round_end(logger)

	if battle.scene != null and battle.scene.message_box.current_action_messages.size() > 0:
		battle.scene.message_box.flush_action_messages()
		battle.scene.show_battle_messages()
		return

	# 🏁 Prüfen ob aktive Monster besiegt wurden
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster != null and not monster.is_alive():
			battle.change_state(MTCheckEndState.new())
			return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(MTStartRoundState.new())

func on_messages_completed(battle):
	# 🏁 Prüfen ob aktive Monster besiegt wurden
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster != null and not monster.is_alive():
			battle.change_state(MTCheckEndState.new())
			return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(MTStartRoundState.new())
