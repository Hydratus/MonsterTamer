extends MTBattleState
class_name MTPlayerInputState

var monster: MTMonsterInstance

func _init(_monster: MTMonsterInstance):
	monster = _monster


func enter(battle: MTBattleController):
	battle.show_player_menu(monster)
