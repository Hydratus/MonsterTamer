extends BattleState
class_name BattleEndState

func enter(battle):
	print("=== Battle End ===")
	
	# Bekomme die Teams
	var team1 = battle.teams[0]
	var team2 = battle.teams[1]
	
	# Bekomme das aktive Monster jedes Teams
	var monster1 = team1.get_active_monster()
	var monster2 = team2.get_active_monster()
	
	# Bestimme Gewinner und Verlierer
	var winner: MonsterInstance = null
	var loser: MonsterInstance = null
	
	if team2 != null and not team2.has_alive_monsters():
		# Team 1 gewinnt
		winner = monster1
		loser = monster2
	elif team1 != null and not team1.has_alive_monsters():
		# Team 2 gewinnt
		winner = monster2
		loser = monster1
	
	# EXP werden bereits in ResolveActionsState verteilt
	# Hier nur noch sicherstellen, dass alles korrekt dokumentiert wird
	print("Battle ended!")
