extends MTBattleState
class_name MTCollectActionsState

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

func enter(battle: MTBattleController):
	battle.action_queue.clear()
	battle.pending_player_actions.clear()
	battle.waiting_for_player = false

	# Sammle Aktionen von den aktiven Monstern beider Teams
	for team in battle.teams:
		if team == null:
			continue
		var monster = team.get_active_monster()
		if monster == null or not monster.is_alive():
			continue

		# Null-Check für decision
		if monster.decision == null:
			DEBUG_LOG.error("CollectActionsState", "Monster %s hat keine Decision zugewiesen!" % monster.data.name)
			continue

		if monster.decision is MTPlayerDecision:
			battle.waiting_for_player = true
			battle.show_player_menu(monster)
		else:
			var action = monster.decision.decide(monster, battle)
			if action:
				# Initiative für Battle-Aktionen setzen
				if action.has_method("set_initiative"):
					action.set_initiative(monster.get_speed())
				battle.action_queue.append(action)

	# Falls kein Player im Kampf - direkt zu Resolve
	if not battle.waiting_for_player:
		battle.change_state(MTResolveActionsState.new())
