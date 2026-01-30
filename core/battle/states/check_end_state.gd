extends BattleState
class_name CheckEndState

func enter(battle):
	# Leere vorherige Messages
	battle.scene.message_box.clear_messages()
	
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
			# Monster wurde besiegt
			battle.log_message("%s wurde besiegt!" % active.data.name)
			battle.scene.message_box.flush_action_messages()  # Speichere "wurde besiegt" Message
			
			print("DEBUG: Wechsle Monster für Team %d - aktiv war %s (tot)" % [i, active.data.name])
			if team.switch_to_next_alive():
				var new_monster = team.get_active_monster()
				var team_name = "Player" if i == 0 else "Enemy"
				var switch_text = "%s sent out %s!" % [team_name, new_monster.data.name]
				battle.log_message(switch_text)
				battle.scene.message_box.flush_action_messages()  # Speichere "sent out" Message
				print("--- %s ---" % switch_text)
				monster_switched = true
			else:
				print("DEBUG: Konnte nicht wechseln - Sicherheit aktiviert")
				battle.change_state(BattleEndState.new())
				return
	
	# Zeige Messages wenn Monster gewechselt wurden
	if monster_switched:
		battle.scene.show_battle_messages()
	else:
		battle.change_state(CollectActionsState.new())

func on_messages_completed(battle):
	# Nach den Switch-Messages starte neue Runde
	battle.change_state(StartRoundState.new())
