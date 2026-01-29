extends BattleState
class_name CheckEndState

func enter(battle):
	# Prüfe ob Kampf vorbei ist (ein Team hat keine lebenden Monster mehr)
	for i in range(battle.teams.size()):
		var team = battle.teams[i]
		var alive = team.get_alive_count()
		print("DEBUG: Team %d hat %d lebende Monster" % [i, alive])
		
		if not team.has_alive_monsters():
			print("Team %d hat keine lebenden Monster mehr - KAMPF VORBEI" % i)
			battle.change_state(BattleEndState.new())
			return
	
	# Wenn nicht, versuche das aktive Monster zu wechseln
	var monster_switched = false
	for i in range(battle.teams.size()):
		var team = battle.teams[i]
		var active = team.get_active_monster()
		if active != null and not active.is_alive():
			print("DEBUG: Wechsle Monster für Team %d - aktiv war %s (tot)" % [i, active.data.name])
			if team.switch_to_next_alive():
				var new_monster = team.get_active_monster()
				var team_name = "Player" if i == 0 else "Enemy"
				print("--- %s sent out %s! ---" % [team_name, new_monster.data.name])
				monster_switched = true
			else:
				print("DEBUG: Konnte nicht wechseln - Sicherheit aktiviert")
				battle.change_state(BattleEndState.new())
				return
	
	# Kampf geht weiter - neue Runde starten
	if monster_switched:
		battle.change_state(StartRoundState.new())
	else:
		battle.change_state(CollectActionsState.new())
