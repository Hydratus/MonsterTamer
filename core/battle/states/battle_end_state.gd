extends BattleState
class_name BattleEndState

func enter(battle):
	print("=== Battle End ===")
	
	# Verstecke das Menu
	if battle.scene != null and battle.scene.has_method("hide_ui"):
		battle.scene.hide_ui()
	
	# Bekomme die Teams
	var team1 = battle.teams[0]
	var team2 = battle.teams[1]
	
	# Bekomme das aktive Monster jedes Teams
	var monster1 = team1.get_active_monster()
	var monster2 = team2.get_active_monster()
	
	# Bestimme Gewinner und Verlierer
	var winner: MonsterInstance = null
	var loser: MonsterInstance = null
	var winner_team_index := -1
	
	if team2 != null and not team2.has_alive_monsters():
		# Team 1 gewinnt
		winner = monster1
		loser = monster2
		winner_team_index = 0
	elif team1 != null and not team1.has_alive_monsters():
		# Team 2 gewinnt
		winner = monster2
		loser = monster1
		winner_team_index = 1
	
	# EXP werden bereits in ResolveActionsState verteilt
	# Hier nur noch sicherstellen, dass alles korrekt dokumentiert wird
	print("Battle ended!")
	if battle.scene != null and battle.scene.has_method("on_battle_finished"):
		battle.scene.on_battle_finished(winner_team_index)
