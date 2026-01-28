extends BattleState
class_name CollectActionsState

func enter(battle: BattleController):
	battle.action_queue.clear()
	battle.pending_player_actions.clear()
	battle.waiting_for_player = false

	# Sammle Aktionen von den aktiven Monstern beider Teams
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster == null or not monster.is_alive():
			continue

		# Null-Check für decision
		if monster.decision == null:
			push_error("Monster %s hat keine Decision zugewiesen!" % monster.data.name)
			continue

		if monster.decision is PlayerDecision:
			battle.waiting_for_player = true
			battle.scene.show_player_menu(monster)
		else:
			var action = monster.decision.decide(monster, battle)
			if action:
				battle.action_queue.append(action)

	# Falls kein Player im Kampf
	if not battle.waiting_for_player:
		battle.sort_actions()
		battle.change_state(ResolveActionsState.new())
