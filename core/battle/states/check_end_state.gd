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
	for team in battle.teams:
		var active = team.get_active_monster()
		if active != null and not active.is_alive():
			print("DEBUG: Wechsle Monster für Team - aktiv war %s (tot)" % active.data.name)
			if team.switch_to_next_alive():
				var new_monster = team.get_active_monster()
				print("--- %s sent out %s! ---" % [team.get_active_monster().data.name, new_monster.data.name])
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
