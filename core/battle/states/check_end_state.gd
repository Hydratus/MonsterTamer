extends MTBattleState
class_name MTCheckEndState

func enter(battle):
	# Leere vorherige Messages
	battle.clear_all_messages()
	
	# Prüfe ob Kampf vorbei ist (ein Team hat keine lebenden Monster mehr)
	for i in range(battle.teams.size()):
		var team = battle.teams[i]
		if team == null:
			continue
		
		if not team.has_alive_monsters():
			battle.change_state(MTBattleEndState.new())
			return
	
	# Wenn nicht, verarbeite besiegte aktive Monster
	var monster_switched = false
	var player_needs_switch = false
	for i in range(battle.teams.size()):
		var team = battle.teams[i]
		if team == null:
			continue
		var active = team.get_active_monster()
		if active != null and not active.is_alive():
			# Monster wurde besiegt
			battle.log_message(TranslationServer.translate("%s was defeated!") % active.data.name)
			battle.flush_action_messages()  # Speichere "wurde besiegt" Message

			if i == 0:
				# Spieler soll aktiv auswählen, welches Monster eingewechselt wird.
				player_needs_switch = true
				continue

			if team.switch_to_next_alive():
				var new_monster = team.get_active_monster()
				var team_name = TranslationServer.translate("Player") if i == 0 else TranslationServer.translate("Enemy")
				var switch_text = TranslationServer.translate("%s sent out %s!") % [team_name, new_monster.data.name]
				battle.log_message(switch_text)
				battle.flush_action_messages()  # Speichere "sent out" Message
				monster_switched = true
			else:
				battle.change_state(MTBattleEndState.new())
				return

	if player_needs_switch:
		if battle.has_queued_messages():
			battle.queue_message_step(func():
				battle.show_forced_switch_menu(0)
			)
			battle.show_battle_messages()
		else:
			battle.show_forced_switch_menu(0)
		return
	
	# Zeige Messages wenn Monster gewechselt wurden
	if monster_switched:
		battle.show_battle_messages()
	else:
		battle.change_state(MTCollectActionsState.new())

func on_messages_completed(battle):
	# Nach den Switch-Messages starte neue Runde
	battle.change_state(MTStartRoundState.new())
