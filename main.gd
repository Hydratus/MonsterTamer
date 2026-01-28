extends Node

@export var player_monster_1: MonsterData
@export var player_monster_2: MonsterData
@export var enemy_monster_1: MonsterData
@export var enemy_monster_2: MonsterData

var battle: BattleController

func _ready():
	var battle_scene = preload("res://scenes/battle_scene.tscn").instantiate()
	add_child(battle_scene)

	# Erstelle Player Team mit 2 Monstern
	var team1: Array[MonsterInstance] = []
	if player_monster_1 != null:
		var monster1 = MonsterInstance.new(player_monster_1)
		monster1.decision = PlayerDecision.new()
		team1.append(monster1)
	if player_monster_2 != null:
		var monster2 = MonsterInstance.new(player_monster_2)
		monster2.decision = PlayerDecision.new()
		team1.append(monster2)
	
	# Erstelle Enemy Team mit 2 Monstern
	var team2: Array[MonsterInstance] = []
	if enemy_monster_1 != null:
		var monster1 = MonsterInstance.new(enemy_monster_1)
		monster1.decision = AIDecision.new()
		team2.append(monster1)
	if enemy_monster_2 != null:
		var monster2 = MonsterInstance.new(enemy_monster_2)
		monster2.decision = AIDecision.new()
		team2.append(monster2)
	
	# Starte Kampf mit beiden Teams
	if team1.size() > 0 and team2.size() > 0:
		battle_scene.start_battle(team1, team2)
