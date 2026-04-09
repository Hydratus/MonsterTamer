extends MTBattleState
class_name MTCheckEndState

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
			battle.change_state(MTBattleEndState.new())
			return
	
	# Wenn nicht, verarbeite besiegte aktive Monster
	var monster_switched = false
	var player_needs_switch = false
	for i in range(battle.teams.size()):
		var team = battle.teams[i]
		var active = team.get_active_monster()
		if active != null and not active.is_alive():
			# Monster wurde besiegt
			battle.log_message(TranslationServer.translate("%s was defeated!") % active.data.name)
			battle.scene.flush_action_messages()  # Speichere "wurde besiegt" Message

			if i == 0:
				# Spieler soll aktiv auswählen, welches Monster eingewechselt wird.
				player_needs_switch = true
				continue

			print("DEBUG: Wechsle Monster für Team %d - aktiv war %s (tot)" % [i, active.data.name])
			if team.switch_to_next_alive():
				var new_monster = team.get_active_monster()
				var team_name = TranslationServer.translate("Player") if i == 0 else TranslationServer.translate("Enemy")
				var switch_text = TranslationServer.translate("%s sent out %s!") % [team_name, new_monster.data.name]
				battle.log_message(switch_text)
				battle.scene.flush_action_messages()  # Speichere "sent out" Message
				print("--- %s ---" % switch_text)
				monster_switched = true
			else:
				print("DEBUG: Konnte nicht wechseln - Sicherheit aktiviert")
				battle.change_state(MTBattleEndState.new())
				return

	if player_needs_switch:
		if battle.scene != null:
			if battle.scene.message_box.message_queue.size() > 0:
				battle.scene.queue_message_step(func():
					battle.scene.show_forced_switch_menu(0)
				)
				battle.scene.show_battle_messages()
			else:
				battle.scene.show_forced_switch_menu(0)
		return
	
	# Zeige Messages wenn Monster gewechselt wurden
	if monster_switched:
		battle.scene.show_battle_messages()
	else:
		battle.change_state(MTCollectActionsState.new())

func on_messages_completed(battle):
	# Nach den Switch-Messages starte neue Runde
	battle.change_state(MTStartRoundState.new())
