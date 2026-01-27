extends BattleState
class_name CheckEndState

func enter(battle):
	var alive = []
	for m in battle.participants:
		if m.is_alive():
			alive.append(m)

	if alive.size() <= 1:
		battle.change_state(BattleEndState.new())
	else:
		battle.change_state(CollectActionsState.new())
