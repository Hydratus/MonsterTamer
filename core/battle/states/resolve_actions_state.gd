extends MTBattleState
class_name MTResolveActionsState

var current_action_index: int = 0

func enter(battle):
	battle.escape_resolved = false
	battle.forced_battle_result = -2
	battle.sort_action_queue()
	
	current_action_index = 0
	battle.clear_all_messages()
	
	# Starte die erste Action
	_execute_next_action(battle)
func _execute_next_action(battle):
	# Überprüfe ob alle Actions abgearbeitet wurden
	if current_action_index >= battle.action_queue.size():
		# Alle Actions fertig
		battle.action_queue.clear()
		_check_battle_end(battle)
		return
	
	var action = battle.action_queue[current_action_index]
	current_action_index += 1
	
	# Leere die Message-Queue für diese Action
	battle.clear_current_action_messages()
	
	# Überprüfe ob der Akteur noch lebt (nur für Actions mit actor Property)
	if "actor" in action and action.actor != null and not action.actor.is_alive():
		battle.log_message(TranslationServer.translate("%s cannot act because it has already been defeated!") % action.actor.data.name)
		battle.flush_action_messages()
		battle.show_battle_messages()
		return
	
	# Führe die Action aus
	if action.has_method("execute"):
		# Setze battle nur wenn die Property existiert (z.B. MTBattleAction)
		if "battle" in action:
			action.battle = battle
		action.execute(battle)
	
	# Kombiniere alle Messages dieser Action zu einer
	battle.flush_action_messages()
	
	# Zeige die Messages für diese Action
	battle.show_battle_messages()

func on_messages_completed(battle):
	# Wird aufgerufen wenn die Messages dieser Action fertig sind
	# Führe die nächste Action aus
	if battle.escape_resolved:
		battle.action_queue.clear()
		battle.change_state(MTBattleEndState.new())
		return
	_execute_next_action(battle)

func _check_battle_end(battle):
	var team_0_alive = battle.teams[0].has_alive_monsters()
	var team_1_alive = battle.teams[1].has_alive_monsters()
	
	if not team_0_alive or not team_1_alive:
		battle.change_state(MTBattleEndState.new())
	else:
		battle.change_state(MTEndRoundState.new())
