extends BattleState
class_name ResolveActionsState

func enter(battle):
	# Führe alle eingeplanten Aktionen mit Prioritäts-Sortierung aus
	battle.resolve_actions()
	
	# Nach allen Aktionen → Runde endet
	battle.change_state(EndRoundState.new())
