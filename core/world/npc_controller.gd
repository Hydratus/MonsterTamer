extends CharacterBody2D
class_name NPCController

@export var npc_data: NPCData
@export var tile_layer_path: NodePath = NodePath("../Grass")
@export var anim_idle_prefix: String = "Idle"
@export var anim_walk_prefix: String = "Walk"
@export var anim_up: String = "Up"
@export var anim_down: String = "Down"
@export var anim_left: String = "Left"
@export var anim_right: String = "Right"

var _tile_layer
var _sprite
var _walk_index: int = 0
var _is_moving := false
var _has_battled := false
var _walk_paused := false
var _pause_after_step := false
var _walk_tween: Tween
var _spawn_cell: Vector2i = Vector2i.ZERO
var _last_facing: Vector2i = Vector2i(0, 1)
var _facing_locked := false
var _locked_facing: Vector2i = Vector2i(0, 1)
var _reserved_cell: Vector2i = Vector2i.ZERO
var _has_reserved_cell := false

func _ready() -> void:
	_tile_layer = get_node_or_null(tile_layer_path) as TileMapLayer
	_sprite = _find_first_animated_sprite(self)
	if _tile_layer != null:
		var local_pos: Vector2 = _tile_layer.to_local(global_position)
		_spawn_cell = _tile_layer.local_to_map(local_pos)
	_resolve_walk_path()
	if npc_data != null and npc_data.walk_enabled and npc_data.walk_path.size() > 0:
		_schedule_next_step()

func set_tile_layer(layer) -> void:
	_tile_layer = layer
	if _tile_layer != null:
		var local_pos: Vector2 = _tile_layer.to_local(global_position)
		_spawn_cell = _tile_layer.local_to_map(local_pos)
		_resolve_walk_path()

func _schedule_next_step() -> void:
	if _is_moving or _walk_paused:
		return
	var delay := 0.6
	if npc_data != null:
		delay = npc_data.walk_delay
	get_tree().create_timer(delay).timeout.connect(_move_next_step)

func _move_next_step() -> void:
	if _walk_paused:
		return
	if npc_data == null or npc_data.walk_path.is_empty():
		return
	_is_moving = true
	var cell: Vector2i = Vector2i(npc_data.walk_path[_walk_index])
	var current_cell := get_cell(_tile_layer)
	var dir := cell - current_cell
	if dir != Vector2i.ZERO:
		_last_facing = dir
	_play_walk_anim(dir)
	var target := _cell_to_world(cell)
	var delta := target - global_position
	if test_move(global_transform, delta):
		_is_moving = false
		_play_idle_anim(_last_facing)
		_schedule_next_step()
		return
	_reserved_cell = cell
	_has_reserved_cell = true
	_walk_index = (_walk_index + 1) % npc_data.walk_path.size()
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween()
	var duration: float = npc_data.walk_duration if npc_data != null else 0.25
	_walk_tween.tween_property(self, "global_position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk_tween.finished.connect(func():
		_is_moving = false
		_play_idle_anim(_get_idle_dir(dir))
		_has_reserved_cell = false
		if _pause_after_step:
			_walk_paused = true
			_pause_after_step = false
			return
		_schedule_next_step()
	)

func pause_walk() -> void:
	if _is_moving:
		_pause_after_step = true
		return
	_walk_paused = true
	_play_idle_anim(_get_idle_dir(_last_facing))
	_has_reserved_cell = false

func resume_walk() -> void:
	_walk_paused = false
	_pause_after_step = false
	_facing_locked = false
	if npc_data != null and npc_data.walk_enabled and npc_data.walk_path.size() > 0:
		_schedule_next_step()

func is_cell_reserved(cell: Vector2i) -> bool:
	return _has_reserved_cell and _reserved_cell == cell

func get_next_target_cell() -> Vector2i:
	if _walk_paused:
		return Vector2i.ZERO
	if npc_data == null or not npc_data.walk_enabled or npc_data.walk_path.is_empty():
		return Vector2i.ZERO
	return Vector2i(npc_data.walk_path[_walk_index])

func _resolve_walk_path() -> void:
	if npc_data == null:
		return
	if not npc_data.walk_path_relative:
		return
	if npc_data.walk_path.is_empty():
		return
	var absolute: Array[Vector2i] = []
	for offset in npc_data.walk_path:
		absolute.append(_spawn_cell + offset)
	npc_data.walk_path = absolute
	npc_data.walk_path_relative = false

func _cell_to_world(cell: Vector2i) -> Vector2:
	if _tile_layer != null:
		return _tile_layer.to_global(_tile_layer.map_to_local(cell))
	return global_position

func get_cell(tile_layer) -> Vector2i:
	var layer: TileMapLayer = tile_layer if tile_layer != null else _tile_layer
	if layer != null:
		var local_pos := layer.to_local(global_position)
		return layer.local_to_map(local_pos)
	return Vector2i.ZERO

func face_towards(direction: Vector2i) -> void:
	if _sprite == null:
		return
	if direction != Vector2i.ZERO:
		_last_facing = direction
	var suffix := anim_down
	if direction == Vector2i(0, -1):
		suffix = anim_up
	elif direction == Vector2i(0, 1):
		suffix = anim_down
	elif direction == Vector2i(-1, 0):
		suffix = anim_left
	elif direction == Vector2i(1, 0):
		suffix = anim_right
	var anim_name := "%s %s" % [anim_idle_prefix, suffix]
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.play(anim_name)

func lock_facing(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return
	_facing_locked = true
	_locked_facing = direction
	_last_facing = direction
	_play_idle_anim(direction)

func _get_idle_dir(preferred: Vector2i) -> Vector2i:
	if _facing_locked:
		return _locked_facing
	return preferred

func _play_walk_anim(direction: Vector2i) -> void:
	_play_anim(anim_walk_prefix, direction)

func _play_idle_anim(direction: Vector2i) -> void:
	_play_anim(anim_idle_prefix, direction)

func _play_anim(prefix: String, direction: Vector2i) -> void:
	if _sprite == null:
		return
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
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim_name):
		if _sprite.animation != anim_name:
			_sprite.play(anim_name)

func can_battle() -> bool:
	if npc_data == null:
		return false
	if npc_data.team_entries.is_empty():
		return false
	if npc_data.battle_once and _has_battled:
		return false
	return true

func get_dialogue() -> String:
	if npc_data == null:
		return ""
	if _has_battled and npc_data.dialogue_after != "":
		return npc_data.dialogue_after
	return npc_data.dialogue_before

func build_team() -> Array:
	var team: Array = []
	if npc_data == null:
		return team
	var entries = npc_data.get("team_entries")
	if entries == null:
		return team
	for entry in entries:
		if entry == null:
			continue
		var monster_data: MonsterData = entry.get("monster_data") as MonsterData
		if monster_data == null:
			continue
		var data: MonsterData = monster_data.duplicate()
		var entry_level = entry.get("level")
		if entry_level != null and int(entry_level) > 0:
			data.level = int(entry_level)
		var instance: MonsterInstance = MonsterInstance.new(data)
		instance.decision = AIDecision.new()
		var attacks_override: Array = entry.get("attacks_override")
		if attacks_override != null and attacks_override.size() > 0:
			instance.attacks = attacks_override.duplicate()
		var traits_override: Array = entry.get("traits_override")
		if traits_override != null and traits_override.size() > 0:
			instance.passive_traits.clear()
			for trait_data in traits_override:
				if trait_data != null:
					instance.add_trait(trait_data)
			instance.clamp_resources()
		team.append(instance)
	return team

func on_battle_finished() -> void:
	_has_battled = true

func is_moving() -> bool:
	return _is_moving

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
