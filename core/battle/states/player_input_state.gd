extends BattleState
class_name PlayerInputState

var monster: MonsterInstance

func _init(_monster: MonsterInstance):
	monster = _monster


func enter(battle: BattleController):
	print("Waiting for player input...")
	battle.scene.show_player_menu(monster)
