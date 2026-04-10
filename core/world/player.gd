extends CharacterBody2D
class_name MTPlayerController

@export var display_name: String = "Player"

func _ready() -> void:
	if display_name != "":
		var loop := Engine.get_main_loop()
		if loop != null and loop is SceneTree:
			var game = (loop as SceneTree).root.get_node_or_null("Game")
			if game != null:
				game.player_name = display_name
