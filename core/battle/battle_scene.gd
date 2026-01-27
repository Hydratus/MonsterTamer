extends Node2D
class_name BattleScene

@onready var menu: BattleMenu = $BattleMenu

var battle: BattleController


func start_battle(monsters: Array[MonsterInstance]):
	battle = BattleController.new()
	battle.scene = self
	battle.start_battle(monsters)


func show_player_menu(monster: MonsterInstance):
	menu.show_attacks(monster)

	menu.action_selected.connect(func(attack: AttackData):
		menu.hide_menu()
		battle.submit_player_attack(monster, attack)
	, CONNECT_ONE_SHOT)
