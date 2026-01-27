extends BattleState
class_name BattleEndState

func enter(battle):
	print("=== Battle End ===")
	
	# Find winner and loser
	var winner: MonsterInstance = null
	var loser: MonsterInstance = null
	
	for monster in battle.participants:
		if monster.is_alive():
			winner = monster
		else:
			loser = monster
	
	# Award EXP to winner if there is a loser
	if winner != null and loser != null:
		print("\n--- EXP Rewards ---")
		winner.gain_exp(loser)
		print()
