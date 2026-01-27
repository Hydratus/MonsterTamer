extends BattleState
class_name EndRoundState

func enter(battle):
	print("--- Round End ---")

	# 🔁 Round-End-Hooks (Regeneration etc.)
	for monster in battle.participants:
		if monster.is_alive():
			monster.on_round_end()

	# 🏁 Prüfen ob Kampf vorbei
	for monster in battle.participants:
		if not monster.is_alive():
			battle.change_state(CheckEndState.new())
			return

	# 🔄 NÄCHSTE RUNDE STARTEN
	battle.change_state(StartRoundState.new())
