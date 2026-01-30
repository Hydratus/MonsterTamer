extends BattleState
class_name ResolveActionsState

var current_action_index: int = 0

func enter(battle):
	# Sortiere die Actions nach Priorität
	battle.action_queue.sort_custom(func(a, b):
		# Priority vergleichen (höher = früher)
		if a.priority > b.priority:
			return true
		elif a.priority < b.priority:
			return false
		# Bei gleicher Priorität: Initiative vergleichen
		if a.initiative > b.initiative:
			return true
		else:
			return false
	)
	
	current_action_index = 0
	battle.scene.message_box.clear_messages()
	
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
	battle.scene.message_box.current_action_messages.clear()
	
	# Überprüfe ob der Akteur noch lebt (nur für Actions mit actor Property)
	if "actor" in action and action.actor != null and not action.actor.is_alive():
		battle.log_message("%s kann nicht angreifen, ist bereits besiegt!" % action.actor.data.name)
		battle.scene.message_box.flush_action_messages()
		battle.scene.show_battle_messages()
		return
	
	# Führe die Action aus
	if action.has_method("execute"):
		# Setze battle nur wenn die Property existiert (z.B. BattleAction)
		if "battle" in action:
			action.battle = battle
		action.execute(battle)
	
	# Kombiniere alle Messages dieser Action zu einer
	battle.scene.message_box.flush_action_messages()
	
	# Zeige die Messages für diese Action
	battle.scene.show_battle_messages()

func on_messages_completed(battle):
	# Wird aufgerufen wenn die Messages dieser Action fertig sind
	# Führe die nächste Action aus
	_execute_next_action(battle)

func _check_battle_end(battle):
	var team_0_alive = battle.teams[0].has_alive_monsters()
	var team_1_alive = battle.teams[1].has_alive_monsters()
	
	if not team_0_alive or not team_1_alive:
		battle.change_state(BattleEndState.new())
	else:
		battle.change_state(EndRoundState.new())
