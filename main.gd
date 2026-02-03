extends Node

@export var starter_team: Array[MonsterData] = []

var overworld: Overworld

func _ready():
	if Game.party.is_empty():
		for monster_data in starter_team:
			if monster_data == null:
				continue
			var instance := MonsterInstance.new(monster_data)
			instance.decision = PlayerDecision.new()
			Game.party.append(instance)

	overworld = preload("res://scenes/world/overworld.tscn").instantiate()
	add_child(overworld)
	overworld.starter_team = starter_team
