extends Node

@export var monster_a: MonsterData
@export var monster_b: MonsterData

var battle: BattleController

func _ready():
	var battle_scene = preload("res://scenes/battle_scene.tscn").instantiate()
	add_child(battle_scene)

	var player = MonsterInstance.new(monster_a)
	var enemy = MonsterInstance.new(monster_b)
	
	#enemy.evasion_modifier = 2.5   # 250 % Ausweichchance

	player.decision = PlayerDecision.new()
	enemy.decision = AIDecision.new()

	var monsters: Array[MonsterInstance] = [player, enemy]
	battle_scene.start_battle(monsters)
