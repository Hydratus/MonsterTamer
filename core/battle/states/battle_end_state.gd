extends MTBattleState
class_name MTBattleEndState

func enter(battle):
	# Verstecke das Menu
	battle.hide_ui()
	
	# Bekomme die Teams
	var team1 = battle.teams[0]
	var team2 = battle.teams[1]
	
	# Bestimme Gewinnerteam
	var winner_team_index := -1
	if battle.forced_battle_result != -2:
		winner_team_index = battle.forced_battle_result
	
	if winner_team_index == -1 and team2 != null and not team2.has_alive_monsters():
		# Team 1 gewinnt
		winner_team_index = 0
	elif winner_team_index == -1 and team1 != null and not team1.has_alive_monsters():
		# Team 2 gewinnt
		winner_team_index = 1
	
	# EXP werden bereits in MTResolveActionsState verteilt
	# Hier nur noch sicherstellen, dass alles korrekt dokumentiert wird
	battle.finish_battle(winner_team_index)
