extends OverworldScene
class_name DungeonScene

const EncounterEntryClass = preload("res://core/world/encounter_entry.gd")

@export var hub_scene_path: String = "res://scenes/world/hub_city.tscn"
@export var floor_count: int = 5
@export var current_floor: int = 1
@export var base_encounter_chance: float = 0.12

var _stairs_npc
var _boss_npc
var _npc_spawn_positions: Dictionary = {}
var _player_spawn_pos: Vector2
var _pending_floor_advance := false
var _pending_return_to_hub := false
var _boss_battle_pending := false
var _boss_battle_active := false

func _ready() -> void:
	super._ready()
	_player_spawn_pos = _player.global_position if _player != null else Vector2.ZERO
	_cache_special_npcs()
	_apply_floor_rules()

func apply_world_payload(payload: Dictionary) -> void:
	if payload.has("floor"):
		current_floor = int(payload["floor"])
	_apply_floor_rules()

func _handle_custom_npc_interaction(npc) -> bool:
	if npc == null or npc.npc_data == null:
		return false
	var interaction := npc.npc_data.interaction_id
	if interaction == "dungeon_stairs":
		_pending_floor_advance = true
		var prompt := npc.get_dialogue()
		if prompt == "":
			prompt = "Descend to the next floor?"
		_enqueue_message(prompt)
		return true
	if interaction == "dungeon_boss":
		_boss_battle_pending = true
		return false
	return false

func _handle_custom_message_closed() -> bool:
	if _pending_floor_advance:
		_pending_floor_advance = false
		_advance_floor()
		return true
	if _pending_return_to_hub:
		_pending_return_to_hub = false
		_request_world_change(hub_scene_path)
		return true
	return false

func _on_battle_finished(winner_team_index: int) -> void:
	super._on_battle_finished(winner_team_index)
	if _boss_battle_pending:
		_boss_battle_active = true
		_boss_battle_pending = false
	if winner_team_index == 1:
		_pending_return_to_hub = true
		_enqueue_message("You were defeated and return to the city.")
		return
	if _boss_battle_active and winner_team_index == 0:
		_boss_battle_active = false
		_pending_return_to_hub = true
		_enqueue_message("Boss defeated! Returning to the city.")

func _advance_floor() -> void:
	if current_floor < floor_count:
		current_floor += 1
		_apply_floor_rules()
		_reset_player_position()
		_enqueue_message("Floor %d" % current_floor)

func _apply_floor_rules() -> void:
	encounter_chance = base_encounter_chance + float(current_floor - 1) * 0.02
	_build_floor_encounters()
	_update_special_npcs()

func _build_floor_encounters() -> void:
	encounter_table.clear()
	var slime := load("res://data/monsters/slime/slime.tres") as MonsterData
	var wolf := load("res://data/monsters/wolf/wolf.tres") as MonsterData
	if slime != null:
		var slime_entry := EncounterEntryClass.new()
		slime_entry.monster = slime
		slime_entry.min_level = 2 + current_floor
		slime_entry.max_level = 4 + current_floor * 2
		slime_entry.weight = 10
		encounter_table.append(slime_entry)
	if wolf != null:
		var wolf_entry := EncounterEntryClass.new()
		wolf_entry.monster = wolf
		wolf_entry.min_level = 3 + current_floor
		wolf_entry.max_level = 5 + current_floor * 2
		wolf_entry.weight = 6
		encounter_table.append(wolf_entry)

func _cache_special_npcs() -> void:
	for npc in _npcs:
		if npc == null or npc.npc_data == null:
			continue
		_npc_spawn_positions[npc] = npc.global_position
		var interaction := npc.npc_data.interaction_id
		if interaction == "dungeon_stairs":
			_stairs_npc = npc
		elif interaction == "dungeon_boss":
			_boss_npc = npc

func _update_special_npcs() -> void:
	var stairs_active := current_floor < floor_count
	var boss_active := current_floor >= floor_count
	_set_npc_active(_stairs_npc, stairs_active)
	_set_npc_active(_boss_npc, boss_active)

func _set_npc_active(npc, active: bool) -> void:
	if npc == null:
		return
	npc.visible = active
	npc.set_process(active)
	npc.set_physics_process(active)
	if active:
		npc.global_position = _npc_spawn_positions.get(npc, npc.global_position)
	else:
		npc.global_position = Vector2(-10000, -10000)

func _reset_player_position() -> void:
	if _player == null:
		return
	_player.global_position = _player_spawn_pos
	_sync_cells()
