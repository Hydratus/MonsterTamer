extends MTBattleState
class_name MTEndRoundState

func _has_defeated_active_monster(battle) -> bool:
	for team in battle.teams:
		if team == null:
			continue
		var monster = team.get_active_monster()
		if monster != null and not monster.is_alive():
			return true
	return false

func enter(battle):
	var logger := Callable(battle, "log_message")

	# 🔁 Round-End-Hooks (Regeneration etc.) für aktive Monster
	for team in battle.teams:
		if team == null:
			continue
		var monster = team.get_active_monster()
		if monster != null and monster.is_alive():
			monster.on_round_end(logger)

	if battle.has_pending_action_messages():
		battle.flush_action_messages()
		battle.show_battle_messages()
		return

	# 🏁 Prüfen ob aktive Monster besiegt wurden
	if _has_defeated_active_monster(battle):
		battle.change_state(MTCheckEndState.new())
		return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(MTStartRoundState.new())

func on_messages_completed(battle):
	# 🏁 Prüfen ob aktive Monster besiegt wurden
	if _has_defeated_active_monster(battle):
		battle.change_state(MTCheckEndState.new())
		return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(MTStartRoundState.new())
