extends Node

@export var starter_team: Array[MonsterData] = []

var _current_world

func _ready():
	add_to_group("world_manager")
	if Game.party.is_empty():
		for monster_data in starter_team:
			if monster_data == null:
				continue
			var instance := MonsterInstance.new(monster_data)
			instance.decision = PlayerDecision.new()
			Game.party.append(instance)
	if Game.get_item_count("lesser_healing_potion") == 0:
		Game.add_item("lesser_healing_potion", 3)
	if Game.get_item_count("lesser_binding_rune") == 0:
		Game.add_item("lesser_binding_rune", 10)

	change_world("res://scenes/world/hub_city.tscn")
	call_deferred("_center_window_on_primary_screen")

func change_world(scene_path: String, payload: Dictionary = {}) -> void:
	if _current_world != null:
		remove_child(_current_world)
		_current_world.queue_free()
		_current_world = null
	var packed := load(scene_path)
	if packed == null:
		push_error("Failed to load scene: %s" % scene_path)
		return
	var world: Node = packed.instantiate()
	add_child(world)
	_current_world = world
	# Fix: Use base type check by script path, not OverworldScene type
	if world.get_script() != null and world.get_script().resource_path == "res://core/world/overworld.gd":
		world.starter_team = starter_team
	if world.has_method("apply_world_payload"):
		world.apply_world_payload(payload)

func _center_window_on_primary_screen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		return
	var screen_index := 0
	var usable := DisplayServer.screen_get_usable_rect(screen_index)
	var screen_pos := usable.position
	var screen_size := usable.size
	var window_size := DisplayServer.window_get_size()
	var top_margin: int = 32
	if window_size.y >= screen_size.y:
		window_size.y = max(screen_size.y - top_margin, 1)
	if window_size.x > screen_size.x:
		window_size.x = max(screen_size.x - 8, 1)
	DisplayServer.window_set_size(window_size)
	var offset := Vector2i(int(round((screen_size.x - window_size.x) / 2.0)), top_margin)
	var target := screen_pos + offset
	DisplayServer.window_set_position(target)
