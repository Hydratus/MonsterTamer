extends BattleState
class_name EndRoundState

func enter(battle):
	print("--- Round End ---")

	# 🔁 Round-End-Hooks (Regeneration etc.) für aktive Monster
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster != null and monster.is_alive():
			monster.on_round_end()

	# 🏁 Prüfen ob aktive Monster besiegt wurden
	for team in battle.teams:
		var monster = team.get_active_monster()
		if monster != null and not monster.is_alive():
			battle.change_state(CheckEndState.new())
			return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(StartRoundState.new())
