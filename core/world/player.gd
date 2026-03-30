extends CharacterBody2D
class_name MTPlayerController

@export var display_name: String = "Player"

func _ready() -> void:
	if display_name != "":
		Game.player_name = display_name
