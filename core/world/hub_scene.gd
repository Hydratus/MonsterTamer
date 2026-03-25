extends "res://core/world/overworld.gd"

func _ready() -> void:
	super._ready()
	encounter_chance = 0.0
	encounter_table.clear()
