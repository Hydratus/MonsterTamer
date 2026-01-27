extends BattleState
class_name BattleStartState

func enter(battle):
	print("=== Battle Start ===")
	battle.change_state(StartRoundState.new())
