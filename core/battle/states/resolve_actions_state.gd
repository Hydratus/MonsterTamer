extends BattleState
class_name ResolveActionsState

func enter(battle):
	for action in battle.action_queue:
		if action.actor.is_alive():
			action.execute()

	# 🔁 Alle Aktionen vorbei → Runde endet
	battle.change_state(EndRoundState.new())
