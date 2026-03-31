extends Node2D

const GAMEPAD_BTN_B := 1
const GAMEPAD_BTN_START := 7
const ITEM_DB = preload("res://core/items/item_db.gd")

const META_UNLOCK_OPTIONS: Array[Dictionary] = [
	{"id": "starting_gold", "name": "Start Gold +25", "cost": 20, "max_level": 3},
	{"id": "merchant_discount", "name": "Merchant Discount +10%", "cost": 25, "max_level": 3},
	{"id": "quest_boost", "name": "Quest Chance +5%", "cost": 30, "max_level": 2}
]

@export var tile_size: int = 32
@export var grass_layer_path: NodePath = NodePath("Grass")
@export var dirt_layer_path: NodePath = NodePath("Dirt")
@export var player_path: NodePath = NodePath("CharacterBody2D")
@export var player_sprite_path: NodePath = NodePath("")
@export var anim_idle_prefix: String = "Idle"
@export var anim_walk_prefix: String = "Walk"
@export var anim_run_prefix: String = "Run"
@export var walk_duration: float = 0.18
@export var run_speed_multiplier: float = 1.6
@export var anim_up: String = "Up"
@export var anim_down: String = "Down"
@export var anim_left: String = "Left"
@export var anim_right: String = "Right"
@export var encounter_chance: float = 0.10
@export var debug_logs: bool = false
@export var encounter_table: Array[MTEncounterEntry] = []
@export var starter_team: Array[MTMonsterData] = []
@export var dungeon_options: Array[Dictionary] = [
	{
		"name": "Test Dungeon (Cavern)",
		"scene": "res://scenes/world/dungeon_test.tscn",
		"payload": {
			"floor": 1,
			"floor_count": 5,
			"habitat": "cavern",
			"seed": 0,
			"base_encounter_chance": 0.05
		}
	},
	{
		"name": "Ruins Trial",
		"scene": "res://scenes/world/dungeon_test.tscn",
		"payload": {
			"floor": 1,
			"floor_count": 4,
			"habitat": "ruins",
			"seed": 1337,
			"base_encounter_chance": 0.14
		}
	},
	{
		"name": "Swamp Depths",
		"scene": "res://scenes/world/dungeon_test.tscn",
		"payload": {
			"floor": 1,
			"floor_count": 6,
			"habitat": "swamp",
			"seed": 98765,
			"base_encounter_chance": 0.18
		}
	}
]

var _grass_layer: TileMapLayer
var _dirt_layer: TileMapLayer
var _player: CharacterBody2D
var _player_sprite: AnimatedSprite2D
var _player_cell: Vector2i = Vector2i.ZERO
var _pending_cell: Vector2i = Vector2i.ZERO
var _message_layer: CanvasLayer
var _message_panel: PanelContainer
var _message_label: Label
var _message_visible := false
var _message_queue: Array[String] = []
var _scene_label_layer: CanvasLayer
var _scene_label: Label
var _is_moving := false
var _target_position: Vector2
var _rng := RandomNumberGenerator.new()
var _battle_scene: Node2D
var _in_battle := false
var _last_facing: Vector2i = Vector2i(0, 1)
var _walk_anim_lock: float = 0.0
const WALK_ANIM_LOCK_TIME := 0.12
var _last_running := false
var _npcs: Array = []
var _pending_npc_battle = null
var _active_npc = null
var _pause_menu
var _pause_menu_open := false
var _last_interaction_id: String = ""
var _last_interaction_npc = null
var _dungeon_menu_layer: CanvasLayer
var _dungeon_menu_panel: PanelContainer
var _dungeon_menu_title: Label
var _dungeon_menu_container: VBoxContainer
var _dungeon_menu_open := false
var _dungeon_menu_buttons: Array[Button] = []

func _log_debug(message: String) -> void:
	if debug_logs:
		print("[World] %s" % message)

func _ready() -> void:
	_rng.randomize()
	_ensure_run_action()
	_ensure_pause_action()
	_resolve_nodes()
	_resolve_tile_size()
	_sync_cells()
	_create_message_ui()
	_create_scene_label()
	_create_pause_menu()
	_create_dungeon_menu()
	_ensure_party()
	_ensure_encounters()

func _unhandled_input(event: InputEvent) -> void:
	if _in_battle or _is_moving:
		return
	if _pause_menu_open:
		if _message_visible and (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
			_try_interact()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
			return
		if event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_cancel"):
			_close_pause_menu()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if _dungeon_menu_open:
		if event.is_action_pressed("ui_cancel"):
			_close_dungeon_menu()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if event.is_action_pressed("pause_menu"):
		if _message_visible:
			return
		_open_pause_menu()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _message_visible:
		if event.is_action_pressed("ui_accept"):
			_try_interact()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		_try_interact()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		_try_move(Vector2i(0, -1))
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_try_move(Vector2i(0, 1))
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_try_move(Vector2i(-1, 0))
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_try_move(Vector2i(1, 0))
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _message_visible:
		return
	if _pause_menu_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_menu"):
			_try_interact()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()


func _process(_delta: float) -> void:
	if _in_battle or _is_moving:
		return
	if _pause_menu_open:
		return
	if _dungeon_menu_open:
		return
	if _message_visible:
		return
	var dir := _get_direction_input()
	if dir != Vector2i.ZERO:
		_try_move(dir)
	else:
		if _walk_anim_lock > 0.0:
			_walk_anim_lock = max(0.0, _walk_anim_lock - _delta)
			_play_walk_anim(_last_facing)
		else:
			_play_idle_anim(_last_facing)

func _resolve_nodes() -> void:
	_grass_layer = get_node_or_null(grass_layer_path) as TileMapLayer
	_dirt_layer = get_node_or_null(dirt_layer_path) as TileMapLayer
	_player = get_node_or_null(player_path) as CharacterBody2D

	if _grass_layer == null:
		_grass_layer = get_node_or_null("Grass") as TileMapLayer
	if _dirt_layer == null:
		_dirt_layer = get_node_or_null("Dirt") as TileMapLayer
	if _player == null:
		_player = _find_first_character_body(null)
	if player_sprite_path != NodePath(""):
		_player_sprite = get_node_or_null(player_sprite_path) as AnimatedSprite2D
	elif _player != null:
		_player_sprite = _find_first_animated_sprite(_player)
	_collect_npcs()
	_assign_npc_tile_layers()

func _resolve_tile_size() -> void:
	if _grass_layer != null and _grass_layer.tile_set != null:
		var tile_set := _grass_layer.tile_set
		if tile_set.get_source_count() > 0:
			var source := tile_set.get_source(0)
			if source is TileSetAtlasSource:
				var atlas := source as TileSetAtlasSource
				if atlas.texture_region_size.x > 0:
					tile_size = atlas.texture_region_size.x

func _sync_cells() -> void:
	if _player != null:
		_player_cell = _world_to_cell(_get_player_ref_pos())

func _create_message_ui() -> void:
	_message_layer = CanvasLayer.new()
	_message_layer.layer = 11
	add_child(_message_layer)

	_message_panel = PanelContainer.new()
	_message_panel.anchor_left = 0.5
	_message_panel.anchor_top = 1.0
	_message_panel.anchor_right = 0.5
	_message_panel.anchor_bottom = 1.0
	_message_panel.offset_left = -160
	_message_panel.offset_top = -80
	_message_panel.offset_right = 160
	_message_panel.offset_bottom = -20
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 1, 1, 1)
	_message_panel.add_theme_stylebox_override("panel", panel_style)
	_message_layer.add_child(_message_panel)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_message_panel.add_child(_message_label)

	_message_panel.visible = false

func _create_scene_label() -> void:
	_scene_label_layer = CanvasLayer.new()
	_scene_label_layer.layer = 12
	add_child(_scene_label_layer)

	_scene_label = Label.new()
	_scene_label.text = "Scene: %s" % _get_scene_title()
	_scene_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scene_label.anchor_left = 0.5
	_scene_label.anchor_right = 0.5
	_scene_label.anchor_top = 0.0
	_scene_label.anchor_bottom = 0.0
	_scene_label.offset_left = -160
	_scene_label.offset_right = 160
	_scene_label.offset_top = 6
	_scene_label.offset_bottom = 28
	_scene_label_layer.add_child(_scene_label)

func _create_dungeon_menu() -> void:
	_dungeon_menu_layer = CanvasLayer.new()
	_dungeon_menu_layer.layer = 13
	add_child(_dungeon_menu_layer)

	_dungeon_menu_panel = PanelContainer.new()
	_dungeon_menu_panel.anchor_left = 0.5
	_dungeon_menu_panel.anchor_top = 0.5
	_dungeon_menu_panel.anchor_right = 0.5
	_dungeon_menu_panel.anchor_bottom = 0.5
	_dungeon_menu_panel.offset_left = -180
	_dungeon_menu_panel.offset_top = -110
	_dungeon_menu_panel.offset_right = 180
	_dungeon_menu_panel.offset_bottom = 110
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 1, 1, 1)
	_dungeon_menu_panel.add_theme_stylebox_override("panel", panel_style)
	_dungeon_menu_layer.add_child(_dungeon_menu_panel)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	_dungeon_menu_panel.add_child(outer)

	_dungeon_menu_title = Label.new()
	_dungeon_menu_title.text = "Choose a dungeon"
	_dungeon_menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dungeon_menu_title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	outer.add_child(_dungeon_menu_title)

	_dungeon_menu_container = VBoxContainer.new()
	_dungeon_menu_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dungeon_menu_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dungeon_menu_container.add_theme_constant_override("separation", 4)
	outer.add_child(_dungeon_menu_container)

	_rebuild_dungeon_buttons()
	_dungeon_menu_panel.visible = false

func _rebuild_dungeon_buttons() -> void:
	_dungeon_menu_buttons.clear()
	for child in _dungeon_menu_container.get_children():
		child.queue_free()

	var essence_text := "Soul Essence: %d" % int(Game.soul_essence if Game != null else 0)
	var essence_label := Label.new()
	essence_label.text = essence_text
	essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0, 1.0))
	_dungeon_menu_container.add_child(essence_label)

	for unlock_def in META_UNLOCK_OPTIONS:
		var unlock_id := str(unlock_def.get("id", ""))
		var max_level: int = int(unlock_def.get("max_level", 1))
		var current_level: int = 0
		if Game != null:
			current_level = Game.get_meta_unlock_level(unlock_id)
		var unlock_button := Button.new()
		if current_level >= max_level:
			unlock_button.text = "%s [MAX]" % str(unlock_def.get("name", unlock_id))
			unlock_button.disabled = true
		else:
			unlock_button.text = "%s (Cost: %d SE) [Lv %d/%d]" % [
				str(unlock_def.get("name", unlock_id)),
				int(unlock_def.get("cost", 0)),
				current_level,
				max_level
			]
			unlock_button.pressed.connect(_on_meta_unlock_button_pressed.bind(unlock_id, int(unlock_def.get("cost", 0)), max_level))
		unlock_button.focus_mode = Control.FOCUS_ALL
		_dungeon_menu_container.add_child(unlock_button)
		_dungeon_menu_buttons.append(unlock_button)

	var spacer := HSeparator.new()
	_dungeon_menu_container.add_child(spacer)

	if dungeon_options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No dungeons available"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_dungeon_menu_container.add_child(empty_label)
		return

	for i in range(dungeon_options.size()):
		var option := dungeon_options[i]
		var name_text := str(option.get("name", "Dungeon"))
		var button := Button.new()
		button.text = name_text
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_dungeon_button_pressed.bind(i))
		_dungeon_menu_container.add_child(button)
		_dungeon_menu_buttons.append(button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_ALL
	cancel_button.pressed.connect(_close_dungeon_menu)
	_dungeon_menu_container.add_child(cancel_button)
	_dungeon_menu_buttons.append(cancel_button)

func _on_meta_unlock_button_pressed(unlock_id: String, cost: int, max_level: int) -> void:
	if Game == null:
		_enqueue_message("Meta unlock failed: Game singleton missing.")
		return
	if Game.buy_meta_unlock(unlock_id, cost, max_level):
		_enqueue_message("Unlocked %s. Soul Essence left: %d" % [unlock_id, Game.soul_essence])
		_rebuild_dungeon_buttons()
		if _dungeon_menu_buttons.size() > 0:
			_dungeon_menu_buttons[0].grab_focus()
		return
	var current_level: int = Game.get_meta_unlock_level(unlock_id)
	if current_level >= max_level:
		_enqueue_message("%s is already at max level." % unlock_id)
	else:
		_enqueue_message("Not enough Soul Essence for %s (Cost: %d)." % [unlock_id, cost])

func _open_dungeon_menu(title: String) -> void:
	if _dungeon_menu_panel == null or _dungeon_menu_panel.get_parent() == null:
		_create_dungeon_menu()
	_dungeon_menu_title.text = title
	_rebuild_dungeon_buttons()
	if _dungeon_menu_layer != null:
		_dungeon_menu_layer.visible = true
	_dungeon_menu_panel.visible = true
	_dungeon_menu_open = true
	_pause_npc_walks()
	_last_interaction_id = ""
	_last_interaction_npc = null
	if _dungeon_menu_buttons.size() > 0:
		_dungeon_menu_buttons[0].grab_focus()

func _close_dungeon_menu() -> void:
	_dungeon_menu_open = false
	if _dungeon_menu_panel != null:
		_dungeon_menu_panel.visible = false
	_resume_npc_walks()
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()

func _on_dungeon_button_pressed(index: int) -> void:
	if index < 0 or index >= dungeon_options.size():
		return
	var option := dungeon_options[index]
	var scene_path := str(option.get("scene", ""))
	if scene_path == "":
		return
	var payload: Dictionary = {}
	if option.has("payload") and option["payload"] is Dictionary:
		payload = option["payload"]
	_log_debug("[DungeonMenu] selected=%s scene=%s payload=%s" % [
		str(option.get("name", "Dungeon")), scene_path, str(payload)])
	if Game != null:
		Game.flags["dungeon_run_active"] = false
	_close_dungeon_menu()
	_request_world_change(scene_path, payload)

func _get_scene_title() -> String:
	var path := get_scene_file_path()
	if path == "":
		return name
	var parts := path.split("/")
	var file_name := parts[parts.size() - 1]
	return file_name.replace(".tscn", "")

func _try_move(direction: Vector2i) -> void:
	_last_facing = direction
	var running := _is_run_pressed()
	_last_running = running
	_play_move_anim(direction, running)
	_walk_anim_lock = WALK_ANIM_LOCK_TIME
	var next_cell := _player_cell + direction
	if not _is_cell_walkable(next_cell):
		return
	if _is_cell_reserved_by_npc(next_cell):
		return
	if _player != null:
		var target_pos := _get_player_target_pos(next_cell)
		var delta := target_pos - _player.global_position
		if _player.test_move(_player.global_transform, delta):
			return

	_pending_cell = next_cell
	_target_position = _get_player_target_pos(next_cell)
	_is_moving = true
	var tween := create_tween()
	var duration := walk_duration
	if running:
		duration = walk_duration / run_speed_multiplier
	tween.tween_property(_player, "global_position", _target_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_step_finished)

func _on_step_finished() -> void:
	_is_moving = false
	_player_cell = _pending_cell
	if _walk_anim_lock > 0.0:
		_play_move_anim(_last_facing, _last_running)
	elif _get_direction_input() == Vector2i.ZERO:
		_play_idle_anim(_last_facing)
	if _in_battle:
		return
	if _is_grass_cell(_player_cell) and _rng.randf() < encounter_chance:
		_play_idle_anim(_last_facing)
		_start_random_battle()

func _cell_to_world(cell: Vector2i) -> Vector2:
	if _grass_layer != null:
		return _grass_layer.to_global(_grass_layer.map_to_local(cell))
	return Vector2(cell.x * tile_size + tile_size * 0.5, cell.y * tile_size + tile_size * 0.5)

func _get_player_ref_pos() -> Vector2:
	if _player_sprite != null:
		return _player_sprite.global_position
	return _player.global_position

func _get_player_target_pos(cell: Vector2i) -> Vector2:
	var target_sprite_pos := _cell_to_world(cell)
	if _player_sprite == null:
		return target_sprite_pos
	var offset := _player_sprite.global_position - _player.global_position
	return target_sprite_pos - offset

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	if _grass_layer != null:
		var local_pos := _grass_layer.to_local(world_pos)
		return _grass_layer.local_to_map(local_pos)
	return Vector2i(round(world_pos.x / tile_size), round(world_pos.y / tile_size))

func _is_cell_in_bounds(cell: Vector2i) -> bool:
	var rect := _get_used_rect()
	if rect.size == Vector2i.ZERO:
		return true
	return rect.has_point(cell)

func _is_cell_walkable(cell: Vector2i) -> bool:
	if _grass_layer == null and _dirt_layer == null:
		return true
	if _has_tile(_grass_layer, cell):
		return true
	if _has_tile(_dirt_layer, cell):
		return true
	return false

func _has_tile(layer: TileMapLayer, cell: Vector2i) -> bool:
	if layer == null:
		return false
	return layer.get_cell_source_id(cell) != -1

func _is_grass_cell(cell: Vector2i) -> bool:
	if _grass_layer == null:
		return false
	return _grass_layer.get_cell_source_id(cell) != -1

func _get_used_rect() -> Rect2i:
	var rect := Rect2i()
	var has_rect := false
	if _grass_layer != null:
		rect = _grass_layer.get_used_rect()
		has_rect = rect.size != Vector2i.ZERO
	if _dirt_layer != null:
		var dirt_rect := _dirt_layer.get_used_rect()
		if has_rect:
			rect = rect.merge(dirt_rect)
		else:
			rect = dirt_rect
			has_rect = rect.size != Vector2i.ZERO
	return rect

func _find_first_character_body(exclude: CharacterBody2D) -> CharacterBody2D:
	for child in get_children():
		if child is CharacterBody2D and child != exclude:
			return child
	return null

func _find_first_animated_sprite(root: Node) -> AnimatedSprite2D:
	if root == null:
		return null
	for child in root.get_children():
		if child is AnimatedSprite2D:
			return child
		var nested := _find_first_animated_sprite(child)
		if nested != null:
			return nested
	return null

func _get_direction_input() -> Vector2i:
	if Input.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO

func _play_walk_anim(direction: Vector2i) -> void:
	_play_anim(anim_walk_prefix, direction)

func _play_move_anim(direction: Vector2i, running: bool) -> void:
	if running:
		if _play_anim_if_exists(anim_run_prefix, direction):
			return
	_play_anim(anim_walk_prefix, direction)

func _play_idle_anim(direction: Vector2i) -> void:
	_play_anim(anim_idle_prefix, direction)

func _play_anim(prefix: String, direction: Vector2i) -> void:
	if _player_sprite == null:
		return
	var suffix := anim_down
	if direction == Vector2i(0, -1):
		suffix = anim_up
	elif direction == Vector2i(0, 1):
		suffix = anim_down
	elif direction == Vector2i(-1, 0):
		suffix = anim_left
	elif direction == Vector2i(1, 0):
		suffix = anim_right
	var anim_name := "%s %s" % [prefix, suffix]
	if _player_sprite.sprite_frames != null and _player_sprite.sprite_frames.has_animation(anim_name):
		if _player_sprite.animation != anim_name:
			_player_sprite.play(anim_name)

func _play_anim_if_exists(prefix: String, direction: Vector2i) -> bool:
	if _player_sprite == null:
		return false
	var dir := direction
	if dir == Vector2i.ZERO:
		dir = Vector2i(0, 1)
	var suffix := anim_down
	if dir == Vector2i(0, -1):
		suffix = anim_up
	elif dir == Vector2i(0, 1):
		suffix = anim_down
	elif dir == Vector2i(-1, 0):
		suffix = anim_left
	elif dir == Vector2i(1, 0):
		suffix = anim_right
	var anim_name := "%s %s" % [prefix, suffix]
	if _player_sprite.sprite_frames != null and _player_sprite.sprite_frames.has_animation(anim_name):
		if _player_sprite.animation != anim_name:
			_player_sprite.play(anim_name)
		return true
	return false

func _is_run_pressed() -> bool:
	return Input.is_action_pressed("run")

func _ensure_run_action() -> void:
	if not InputMap.has_action("run"):
		InputMap.add_action("run")

func _ensure_pause_action() -> void:
	if not InputMap.has_action("pause_menu"):
		InputMap.add_action("pause_menu")

func _create_pause_menu() -> void:
	var scene := preload("res://ui/menus/pause_menu.tscn")
	_pause_menu = scene.instantiate()
	add_child(_pause_menu)
	_pause_menu.closed.connect(_on_pause_menu_closed)
	if _pause_menu.has_signal("item_used_message"):
		_pause_menu.item_used_message.connect(_show_message)
	_pause_menu.visible = false

func _open_pause_menu() -> void:
	if _pause_menu == null:
		return
	_pause_menu_open = true
	_pause_menu.open(Game.party)

func _close_pause_menu() -> void:
	if _pause_menu == null:
		return
	_pause_menu_open = false
	_pause_menu.close()

func _on_pause_menu_closed() -> void:
	_pause_menu_open = false

func _try_interact() -> void:
	if _message_visible:
		_message_panel.visible = false
		_message_visible = false
		if not _message_queue.is_empty():
			_show_next_message()
			return
		if _handle_custom_message_closed():
			return
		if _pause_menu_open and _pause_menu != null:
			if _pause_menu.has_method("set_overlay_message_active"):
				_pause_menu.set_overlay_message_active(false)
		if _pending_npc_battle != null:
			var pending_npc = _pending_npc_battle
			_pending_npc_battle = null
			_start_npc_battle(pending_npc)
		else:
			_resume_npc_walks()
		return

	var npc = _get_npc_in_front()
	if npc != null:
		if npc.is_moving():
			return
		if npc.npc_data != null and npc.npc_data.interaction_id != "":
			_last_interaction_id = npc.npc_data.interaction_id
			_last_interaction_npc = npc
			if npc.npc_data != null and npc.npc_data.interaction_id == "dungeon_select":
				var prompt: String = npc.get_dialogue()
				if prompt == "":
					prompt = "Choose a dungeon"
				_message_label.text = prompt
				_message_panel.visible = true
				_message_visible = true
				_open_dungeon_menu(prompt)
				return
		if _handle_custom_npc_interaction(npc):
			return
		var dialogue = npc.get_dialogue()
		var face_dir: Vector2i = _player_cell - npc.get_cell(_grass_layer)
		npc.face_towards(face_dir)
		npc.lock_facing(face_dir)
		if npc.can_give_items():
			npc.give_items()
			_enqueue_message(dialogue)
			var amount: int = int(max(npc.npc_data.give_item_amount, 1))
			for item_id in npc.npc_data.give_item_ids:
				if item_id == "":
					continue
				var item_data: MTItemData = ITEM_DB.new().get_item(item_id)
				var item_name: String = item_id
				if item_data != null:
					item_name = item_data.name
				var line := "Received %s." % item_name
				if amount > 1:
					line = "Received %s x%d." % [item_name, amount]
				_enqueue_message(line)
			return
		if npc.can_battle():
			_pending_npc_battle = npc
		_enqueue_message(dialogue)
		if dialogue == "" and _pending_npc_battle != null:
			var pending_npc2 = _pending_npc_battle
			_pending_npc_battle = null
			_start_npc_battle(pending_npc2)

func _handle_custom_npc_interaction(_npc) -> bool:
	return false

func _handle_custom_message_closed() -> bool:
	return false

func _request_world_change(scene_path: String, payload: Dictionary = {}) -> void:
	var manager := get_tree().get_first_node_in_group("world_manager")
	if manager == null:
		manager = get_tree().current_scene
	if manager != null and manager.has_method("change_world"):
		manager.change_world(scene_path, payload)
		return
	var parent := get_parent()
	while parent != null:
		if parent.has_method("change_world"):
			parent.change_world(scene_path, payload)
			return
		parent = parent.get_parent()
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_error("World change failed: %s" % scene_path)

func _ensure_party() -> void:
	if Game.party.size() > 0:
		return
	for monster_data in starter_team:
		if monster_data == null:
			continue
		var instance := MTMonsterInstance.new(monster_data)
		instance.decision = MTPlayerDecision.new()
		Game.party.append(instance)

func _ensure_encounters() -> void:
	if not encounter_table.is_empty():
		return
	var slime := load("res://data/monsters/slime/slime.tres") as MTMonsterData
	var wolf := load("res://data/monsters/wolf/wolf.tres") as MTMonsterData
	if slime != null:
		var slime_entry := MTEncounterEntry.new()
		slime_entry.monster = slime
		slime_entry.min_level = 2
		slime_entry.max_level = 6
		slime_entry.weight = 10
		encounter_table.append(slime_entry)
	if wolf != null:
		var wolf_entry := MTEncounterEntry.new()
		wolf_entry.monster = wolf
		wolf_entry.min_level = 4
		wolf_entry.max_level = 8
		wolf_entry.weight = 5
		encounter_table.append(wolf_entry)

func _start_random_battle() -> void:
	var enemy_team: Array[MTMonsterInstance] = _build_enemy_team()
	if enemy_team.is_empty():
		return
	_pause_npc_walks()

	_in_battle = true
	_battle_scene = preload("res://scenes/battle_scene.tscn").instantiate()
	_battle_scene.auto_start = false
	add_child(_battle_scene)
	_battle_scene.battle_finished.connect(_on_battle_finished)
	_battle_scene.capture_allowed = true
	_battle_scene.escape_allowed = true
	_battle_scene.player_soulbinder_name = Game.player_name
	_battle_scene.enemy_soulbinder_name = "Wild"
	var player_team: Array[MTMonsterInstance] = []
	for monster in Game.party:
		if monster == null:
			continue
		player_team.append(monster)
	_battle_scene.start_battle(player_team, enemy_team)

func _build_enemy_team() -> Array[MTMonsterInstance]:
	var entries := encounter_table.filter(func(e): return e != null and e.weight > 0 and e.monster != null)
	if entries.is_empty():
		return []

	var total_weight := 0
	for e in entries:
		total_weight += e.weight

	var roll := _rng.randi_range(1, total_weight)
	var chosen: MTEncounterEntry = entries[0]
	var running := 0
	for e in entries:
		running += e.weight
		if roll <= running:
			chosen = e
			break

	var level := _rng.randi_range(chosen.min_level, chosen.max_level)
	var enemy_data := chosen.monster.duplicate()
	enemy_data.level = level

	var enemy := MTMonsterInstance.new(enemy_data)
	enemy.decision = MTAIDecision.new()
	return [enemy]

func _on_battle_finished(_winner_team_index: int) -> void:
	_in_battle = false
	if _active_npc != null:
		_active_npc.on_battle_finished()
		_active_npc = null
	if _battle_scene != null:
		_battle_scene.queue_free()
		_battle_scene = null
	_resume_npc_walks()

func _start_npc_battle(npc) -> void:
	if npc == null:
		return
	var enemy_raw = npc.build_team()
	var enemy_team: Array[MTMonsterInstance] = []
	for m in enemy_raw:
		if m == null:
			continue
		enemy_team.append(m)
	if enemy_team.is_empty():
		return
	_pause_npc_walks()

	_active_npc = npc
	_in_battle = true
	_battle_scene = preload("res://scenes/battle_scene.tscn").instantiate()
	_battle_scene.auto_start = false
	add_child(_battle_scene)
	_battle_scene.battle_finished.connect(_on_battle_finished)
	_battle_scene.capture_allowed = false
	_battle_scene.escape_allowed = false
	_battle_scene.player_soulbinder_name = Game.player_name
	var npc_name: String = "NPC"
	if npc.npc_data != null and npc.npc_data.display_name != "":
		npc_name = npc.npc_data.display_name
	_battle_scene.enemy_soulbinder_name = npc_name
	var player_team: Array[MTMonsterInstance] = []
	for monster in Game.party:
		if monster == null:
			continue
		player_team.append(monster)
	_battle_scene.start_battle(player_team, enemy_team)

func _show_message(text: String) -> void:
	_enqueue_message(text)

func _enqueue_message(text: String) -> void:
	if text == "":
		return
	_message_queue.append(text)
	if not _message_visible:
		_show_next_message()

func _show_next_message() -> void:
	if _message_queue.is_empty():
		return
	var next_text: String = _message_queue.pop_front()
	_message_label.text = next_text
	_message_panel.visible = true
	_message_visible = true
	_pause_npc_walks()
	if _pause_menu_open and _pause_menu != null:
		if _pause_menu.has_method("set_overlay_message_active"):
			_pause_menu.set_overlay_message_active(true)

func _pause_npc_walks() -> void:
	for npc in _npcs:
		if npc != null:
			npc.pause_walk()

func _resume_npc_walks() -> void:
	for npc in _npcs:
		if npc != null:
			npc.resume_walk()

func _get_npc_in_front():
	if _npcs.is_empty():
		return null
	var target_cell := _player_cell + _last_facing
	for npc in _npcs:
		if npc == null:
			continue
		if npc.get_cell(_grass_layer) == target_cell:
			return npc
	return null

func _collect_npcs() -> void:
	_npcs.clear()
	_find_npcs_recursive(self)

func _find_npcs_recursive(root: Node) -> void:
	for child in root.get_children():
		if child is MTNPCController:
			_npcs.append(child)
		_find_npcs_recursive(child)

func _assign_npc_tile_layers() -> void:
	for npc in _npcs:
		if npc != null:
			npc.set_tile_layer(_grass_layer)


func _is_cell_reserved_by_npc(cell: Vector2i) -> bool:
	for npc in _npcs:
		if npc == null:
			continue
		if npc.get_cell(_grass_layer) == cell:
			return true
		if npc.is_cell_reserved(cell):
			return true
		var next_cell: Vector2i = npc.get_next_target_cell()
		if next_cell != Vector2i.ZERO and next_cell == cell:
			return true
	return false
