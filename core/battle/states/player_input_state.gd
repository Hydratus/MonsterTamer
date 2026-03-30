extends MTBattleState
class_name MTPlayerInputState

var monster: MTMonsterInstance

func _init(_monster: MTMonsterInstance):
	monster = _monster


func enter(battle: MTBattleController):
	print("Waiting for player input...")
	battle.scene.show_player_menu(monster)
