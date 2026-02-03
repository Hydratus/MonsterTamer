extends Node2D
class_name Overworld

@export var tile_size: int = 32
@export var grass_layer_path: NodePath = NodePath("Grass")
@export var dirt_layer_path: NodePath = NodePath("Dirt")
@export var player_path: NodePath = NodePath("CharacterBody2D")
@export var npc_path: NodePath = NodePath("NPC_1")
@export var player_sprite_path: NodePath = NodePath("")
@export var npc_sprite_path: NodePath = NodePath("")
@export var anim_idle_prefix: String = "Idle"
@export var anim_walk_prefix: String = "Walk"
@export var anim_up: String = "Up"
@export var anim_down: String = "Down"
@export var anim_left: String = "Left"
@export var anim_right: String = "Right"
@export var encounter_chance: float = 0.10
@export var encounter_table: Array[EncounterEntry] = []
@export var starter_team: Array[MonsterData] = []

var _grass_layer: TileMapLayer
var _dirt_layer: TileMapLayer
var _player: CharacterBody2D
var _npc: CharacterBody2D
var _player_sprite: AnimatedSprite2D
var _npc_sprite: AnimatedSprite2D
var _player_cell: Vector2i = Vector2i.ZERO
var _pending_cell: Vector2i = Vector2i.ZERO
var _npc_cell: Vector2i = Vector2i.ZERO
var _blocked_cells: Array[Vector2i] = []
var _message_layer: CanvasLayer
var _message_panel: PanelContainer
var _message_label: Label
var _message_visible := false
var _is_moving := false
var _target_position: Vector2
var _rng := RandomNumberGenerator.new()
var _battle_scene: Node2D
var _in_battle := false
var _last_facing: Vector2i = Vector2i(0, 1)

func _ready() -> void:
	_rng.randomize()
	_resolve_nodes()
	_resolve_tile_size()
	_sync_cells()
	_create_message_ui()
	_ensure_party()
	_ensure_encounters()

func _unhandled_input(event: InputEvent) -> void:
	if _in_battle or _is_moving:
		return
	if event.is_action_pressed("ui_accept"):
		_try_interact()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		var dir := _get_direction_input()
		if dir != Vector2i.ZERO:
			_try_move(dir)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _in_battle or _is_moving:
		return
	_update_npc_cell()
	var dir := _get_direction_input()
	if dir != Vector2i.ZERO:
		_try_move(dir)

func _resolve_nodes() -> void:
	_grass_layer = get_node_or_null(grass_layer_path) as TileMapLayer
	_dirt_layer = get_node_or_null(dirt_layer_path) as TileMapLayer
	_player = get_node_or_null(player_path) as CharacterBody2D
	_npc = get_node_or_null(npc_path) as CharacterBody2D

	if _grass_layer == null:
		_grass_layer = get_node_or_null("Grass") as TileMapLayer
	if _dirt_layer == null:
		_dirt_layer = get_node_or_null("Dirt") as TileMapLayer
	if _player == null:
		_player = _find_first_character_body(null)
	if _npc == null:
		_npc = _find_first_character_body(_player)
	if player_sprite_path != NodePath(""):
		_player_sprite = get_node_or_null(player_sprite_path) as AnimatedSprite2D
	elif _player != null:
		_player_sprite = _find_first_animated_sprite(_player)
	if npc_sprite_path != NodePath(""):
		_npc_sprite = get_node_or_null(npc_sprite_path) as AnimatedSprite2D
	elif _npc != null:
		_npc_sprite = _find_first_animated_sprite(_npc)

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
	_update_npc_cell()

func _create_message_ui() -> void:
	_message_layer = CanvasLayer.new()
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
	_message_layer.add_child(_message_panel)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_panel.add_child(_message_label)

	_message_panel.visible = false

func _try_move(direction: Vector2i) -> void:
	_update_npc_cell()
	_last_facing = direction
	_play_walk_anim(direction)
	var next_cell := _player_cell + direction
	if not _is_cell_walkable(next_cell):
		return
	if _blocked_cells.has(next_cell):
		return

	_pending_cell = next_cell
	_target_position = _get_player_target_pos(next_cell)
	_is_moving = true
	var tween := create_tween()
	tween.tween_property(_player, "global_position", _target_position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_step_finished)

func _on_step_finished() -> void:
	_is_moving = false
	_player_cell = _pending_cell
	_play_idle_anim(_last_facing)
	if _in_battle:
		return
	if _is_grass_cell(_player_cell) and _rng.randf() <= encounter_chance:
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

func _try_interact() -> void:
	_update_npc_cell()
	if _message_visible:
		_message_panel.visible = false
		_message_visible = false
		return

	if _player_cell.distance_to(_npc_cell) <= 1:
		_message_label.text = "Hello! Stay safe in the tall grass."
		_message_panel.visible = true
		_message_visible = true

func _update_npc_cell() -> void:
	if _npc == null:
		return
	var ref_pos := _npc.global_position
	if _npc_sprite != null:
		ref_pos = _npc_sprite.global_position
	_npc_cell = _world_to_cell(ref_pos)
	_blocked_cells.clear()
	_blocked_cells.append(_npc_cell)

func _ensure_party() -> void:
	if Game.party.size() > 0:
		return
	for monster_data in starter_team:
		if monster_data == null:
			continue
		var instance := MonsterInstance.new(monster_data)
		instance.decision = PlayerDecision.new()
		Game.party.append(instance)

func _ensure_encounters() -> void:
	if not encounter_table.is_empty():
		return
	var slime := load("res://data/monsters/slime/slime.tres") as MonsterData
	var wolf := load("res://data/monsters/wolf/wolf.tres") as MonsterData
	if slime != null:
		var slime_entry := EncounterEntry.new()
		slime_entry.monster = slime
		slime_entry.min_level = 2
		slime_entry.max_level = 6
		slime_entry.weight = 10
		encounter_table.append(slime_entry)
	if wolf != null:
		var wolf_entry := EncounterEntry.new()
		wolf_entry.monster = wolf
		wolf_entry.min_level = 4
		wolf_entry.max_level = 8
		wolf_entry.weight = 5
		encounter_table.append(wolf_entry)

func _start_random_battle() -> void:
	var enemy_team: Array[MonsterInstance] = _build_enemy_team()
	if enemy_team.is_empty():
		return

	_in_battle = true
	_battle_scene = preload("res://scenes/battle_scene.tscn").instantiate()
	_battle_scene.auto_start = false
	add_child(_battle_scene)
	_battle_scene.battle_finished.connect(_on_battle_finished)
	var player_team: Array[MonsterInstance] = []
	for monster in Game.party:
		if monster == null:
			continue
		player_team.append(monster)
	_battle_scene.start_battle(player_team, enemy_team)

func _build_enemy_team() -> Array[MonsterInstance]:
	var entries := encounter_table.filter(func(e): return e != null and e.weight > 0 and e.monster != null)
	if entries.is_empty():
		return []

	var total_weight := 0
	for e in entries:
		total_weight += e.weight

	var roll := _rng.randi_range(1, total_weight)
	var chosen: EncounterEntry = entries[0]
	var running := 0
	for e in entries:
		running += e.weight
		if roll <= running:
			chosen = e
			break

	var level := _rng.randi_range(chosen.min_level, chosen.max_level)
	var enemy_data := chosen.monster.duplicate()
	enemy_data.level = level

	var enemy := MonsterInstance.new(enemy_data)
	enemy.decision = AIDecision.new()
	return [enemy]

func _on_battle_finished(_winner_team_index: int) -> void:
	_in_battle = false
	if _battle_scene != null:
		_battle_scene.queue_free()
		_battle_scene = null
