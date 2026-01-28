extends BattleState
class_name ResolveActionsState

func enter(battle):
	for action in battle.action_queue:
		if action.actor.is_alive():
			action.execute()
			
			# Prüfe sofort nach jeder Aktion, ob ein Monster besiegt wurde
			for team in battle.teams:
				var active = team.get_active_monster()
				if active != null and not active.is_alive():
					# Dieses Monster wurde besiegt - verteile sofort EXP
					var opponent_team = null
					for i in range(battle.teams.size()):
						if battle.teams[i] != team:
							opponent_team = battle.teams[i]
							break
					
					if opponent_team != null:
						var alive_opponents = opponent_team.get_alive_monsters()
						if alive_opponents.size() > 0:
							print("\n--- %s defeated! EXP Rewards ---" % active.data.name)
							# Verteile EXP auf alle Gegner, die gegen dieses Monster gekämpft haben
							var contributors = active.opponents_fought.filter(func(m): return m in alive_opponents)
							if contributors.is_empty():
								# Fallback: Alle alive opponents bekommen EXP
								contributors = alive_opponents
							active.gain_exp(active, contributors)
							print()

	# 🔁 Alle Aktionen vorbei → Runde endet
	battle.change_state(EndRoundState.new())
