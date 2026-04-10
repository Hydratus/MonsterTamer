extends Node

@export var starter_team: Array[MTMonsterData] = []
@export var debug_world_logs := false

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

var _current_world

func _log_world(message: String) -> void:
	DEBUG_LOG.debug(debug_world_logs, "World", message)

func _ready():
	add_to_group("world_manager")
	if Game.party.is_empty():
		for monster_data in starter_team:
			if monster_data == null:
				continue
			var instance := MTMonsterInstance.new(monster_data)
			instance.decision = MTPlayerDecision.new()
			if not Game.add_to_party(instance):
				DEBUG_LOG.error("World", "Failed to add starter monster to party")
				break
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
		DEBUG_LOG.error("World", "Failed to load scene: %s" % scene_path)
		return
	var world: Node = packed.instantiate()

	# Safety-net: if the dungeon scene is instantiated with the base overworld
	# script, force-assign the dedicated dungeon script before _ready runs.
	var world_script = world.get_script()
	var script_path := "<none>"
	if world_script != null and world_script is Script:
		script_path = (world_script as Script).resource_path
	if scene_path == "res://scenes/world/dungeon_test.tscn" and script_path == "res://core/world/overworld.gd":
		var dungeon_script := load("res://core/world/dungeon_scene.gd")
		if dungeon_script != null:
			world.set_script(dungeon_script)
			world_script = world.get_script()
			if world_script != null and world_script is Script:
				script_path = (world_script as Script).resource_path
			_log_world("forced dungeon script=%s" % [script_path])
		else:
			DEBUG_LOG.error("World", "Failed to load forced dungeon script")

	add_child(world)
	_current_world = world
	world_script = world.get_script()
	script_path = "<none>"
	if world_script != null and world_script is Script:
		script_path = (world_script as Script).resource_path
	_log_world("change_world path=%s node=%s script=%s" % [scene_path, world.name, script_path])
	for prop in world.get_property_list():
		if str(prop.name) == "starter_team":
			world.set("starter_team", starter_team)
			break
	if world.has_method("apply_world_payload"):
		_log_world("apply_world_payload payload=%s" % [str(payload)])
		world.apply_world_payload(payload)
	else:
		_log_world("apply_world_payload missing on node=%s" % [world.name])

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
