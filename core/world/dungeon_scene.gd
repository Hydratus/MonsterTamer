extends "res://core/world/overworld.gd"

const EncounterEntryClass = preload("res://core/world/encounter_entry.gd")
const NPCDataClass = preload("res://core/world/npc_data.gd")
const NPCMonsterEntryClass = preload("res://core/world/npc_monster_entry.gd")
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")
const STAIRS_NPC_DATA = preload("res://data/npc/NPCDungeonStairs.tres")
const BOSS_NPC_DATA = preload("res://data/npc/NPCDungeonBoss.tres")

const ROOM_TYPE_START := "start"
const ROOM_TYPE_EXIT := "exit"
const ROOM_TYPE_ELITE := "elite"
const ROOM_TYPE_EVENT := "event"
const ROOM_TYPE_NORMAL := "normal"

enum FLOOR_GOAL_TYPE {
	OPEN,		# Stairs immediately accessible
	ELITE,		# Must defeat elite
	KEY,			# Must find key
	PUZZLE		# Must activate 3 switches
}

enum QUEST_TYPE {
	ITEM_DELIVERY,		# Deliver item to NPC
	MONSTER_HUNT,		# Defeat N monsters
	THIEF_AMBUSH			# Combat with thief
}

@export var hub_scene_path: String = "res://scenes/world/hub_city.tscn"
@export var habitat: String = "cavern"
@export var floor_count: int = 5
@export var current_floor: int = 1
@export var base_encounter_chance: float = 0.12

@export var map_width: int = 48
@export var map_height: int = 32
@export var min_room_count: int = 7
@export var max_room_count: int = 11
@export var min_room_size: int = 4
@export var max_room_size: int = 9
@export var generation_seed: int = 0

@export var battle_npc_min: int = 1
@export var battle_npc_max: int = 3
@export var item_npc_min: int = 1
@export var item_npc_max: int = 2
@export var mimic_spawn_chance: float = 0.06
@export var mimic_min_floor: int = 2
@export var boss_team_size: int = 5
@export var item_reward_pool: Array[String] = [
	"lesser_healing_potion",
	"lesser_normal_binding_rune",
	"lesser_fire_binding_rune",
	"lesser_water_binding_rune"
]

# Floor Goal probabilities (should sum to 100)
@export var goal_prob_open: int = 50
@export var goal_prob_elite: int = 30
@export var goal_prob_key: int = 10
@export var goal_prob_puzzle: int = 10

# Quest System
@export var quest_spawn_chance: float = 0.30
@export var quest_reward_xp: int = 50
@export var quest_reward_gold: int = 25
@export var quest_reward_soul_essence: int = 1

# Run economy
@export var run_start_gold: int = 40
@export var wild_battle_gold: int = 6
@export var elite_battle_gold: int = 28
@export var mimic_battle_gold: int = 16
@export var boss_battle_gold: int = 75
@export var elite_battle_soul_essence: int = 2
@export var boss_battle_soul_essence: int = 8

# Merchant stock (uses run gold)
@export var merchant_shop_items: Array[String] = [
	"lesser_healing_potion",
	"lesser_normal_binding_rune",
	"lesser_fire_binding_rune",
	"lesser_water_binding_rune",
	"secret_key"
]
@export var merchant_shop_prices: Array[int] = [18, 26, 30, 30, 35]

# Dungeon Event Objects
@export var event_object_spawn_chance: float = 0.30
@export var loose_item_max_count: int = 3
@export var secret_vault_spawn_chance: float = 0.25

# Floor tile: source 0, atlas (0,0)  first tile in the shared TileSet.
@export var floor_tile_source_id: int = 0
@export var floor_tile_atlas: Vector2i = Vector2i(0, 0)

# Saved RNG seed so apply_world_payload re-generates the identical layout
# instead of creating a brand-new one.
var _layout_seed: int = 0

var _stairs_npc
var _boss_npc
var _npc_spawn_positions: Dictionary = {}
var _disabled_static_npcs: Array = []
var _dynamic_npcs: Array = []
var _floor_cells: Array[Vector2i] = []
var _room_rects: Array[Rect2i] = []
var _player_spawn_cell: Vector2i = Vector2i.ZERO
var _pending_floor_advance := false
var _pending_return_to_hub := false
var _boss_battle_active := false
var _room_cells_lookup: Dictionary = {}
var _corridor_cells_lookup: Dictionary = {}
var _room_type_by_index: Dictionary = {}
var _room_index_by_cell: Dictionary = {}
var _visited_room_indices: Dictionary = {}
var _elite_room_index: int = -1
var _event_room_index: int = -1
var _elite_cleared_this_floor := false
var _payload_applied := false

# Floor Goal System
var _current_floor_goal: int = FLOOR_GOAL_TYPE.OPEN
var _floor_goal_state: Dictionary = {}
var _switches_total: int = 0
var _switches_activated: int = 0
var _key_found_this_floor := false

# Quest System
var _active_quest: Dictionary = {}
var _has_quest_this_floor := false
var _quest_npc
var _quest_item_npc
var _merchant_shop_index: int = 0
var _merchant_shop_layer: CanvasLayer
var _merchant_shop_panel: PanelContainer
var _merchant_shop_title: Label
var _merchant_shop_list: VBoxContainer
var _merchant_shop_status: Label
var _merchant_shop_close_button: Button
var _merchant_shop_buttons: Array[Button] = []
var _merchant_shop_open := false
var _currency_hud_layer: CanvasLayer
var _currency_hud_label: Label
var _last_gold_display: int = -1
var _last_essence_display: int = -1

#  Life-cycle 

func _log_dungeon(message: String) -> void:
	_log_debug(message)

func _ready() -> void:
	_log_dungeon("[Dungeon] _ready() floor=%d  seed=%d" % [current_floor, generation_seed])
	super._ready()
	_create_merchant_shop_ui()
	_create_currency_hud()
	_update_currency_hud(true)
	_log_dungeon("[Dungeon] grass=%s  dirt=%s  player=%s  npcs=%d" % [
		str(_grass_layer), str(_dirt_layer), str(_player), _npcs.size()])
	_cache_special_npcs()
	_log_dungeon("[Dungeon] stairs=%s  boss=%s" % [str(_stairs_npc), str(_boss_npc)])
	call_deferred("_ensure_initial_floor_generation")
	_log_dungeon("[Dungeon] _ready() done")

func _process(delta: float) -> void:
	if _merchant_shop_open:
		_update_currency_hud(false)
		return
	super._process(delta)
	_update_currency_hud(false)

func _unhandled_input(event: InputEvent) -> void:
	if _merchant_shop_open:
		if event.is_action_pressed("ui_cancel"):
			_close_merchant_shop()
			var viewport := get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()
		return
	super._unhandled_input(event)

func _ensure_initial_floor_generation() -> void:
	if _payload_applied:
		return
	if _floor_cells.is_empty():
		_apply_floor_rules(false)

func apply_world_payload(payload: Dictionary) -> void:
	_payload_applied = true
	var need_regen := false
	if payload.has("floor"):
		var new_floor := int(payload["floor"])
		if new_floor != current_floor:
			current_floor = new_floor
			_layout_seed = 0  # new floor  new random layout
			need_regen = true
	if payload.has("floor_count"):
		floor_count = int(payload["floor_count"])
		need_regen = true
	if payload.has("habitat"):
		habitat = str(payload["habitat"])
		need_regen = true
	if payload.has("base_encounter_chance"):
		base_encounter_chance = clamp(float(payload["base_encounter_chance"]), 0.0, 1.0)
		need_regen = true
	elif payload.has("encounter_chance"):
		# Alias for convenience in inspector payload dictionaries.
		base_encounter_chance = clamp(float(payload["encounter_chance"]), 0.0, 1.0)
		need_regen = true
	if payload.has("seed"):
		generation_seed = int(payload["seed"])
		_layout_seed = 0
		need_regen = true
	# Only regenerate when the floor is still empty (first-time entry when _ready
	# already ran) or when the payload actually requests a different setup.
	if _floor_cells.is_empty() or need_regen:
		_apply_floor_rules(false)

#  Walkability overrides 
# Dungeon floors live on the Dirt layer; empty cells = impassable walls.

func _is_cell_walkable(cell: Vector2i) -> bool:
	if _dirt_layer == null:
		return false
	return _has_tile(_dirt_layer, cell)

func _is_grass_cell(cell: Vector2i) -> bool:
	# Random encounters fire on every floor cell in the dungeon.
	if _dirt_layer == null:
		return false
	return _has_tile(_dirt_layer, cell)

#  NPC interaction hooks 

func _handle_custom_npc_interaction(npc) -> bool:
	if npc == null or npc.npc_data == null:
		return false
	var interaction: String = str(npc.npc_data.interaction_id)
	if interaction == "dungeon_stairs" and current_floor < floor_count:
		# Check if floor goal is satisfied
		var goal_satisfied: bool = _is_floor_goal_satisfied()
		if not goal_satisfied:
			_enqueue_message(_get_goal_blocked_message())
			return true
		_pending_floor_advance = true
		var prompt: String = str(npc.get_dialogue())
		if prompt == "":
			prompt = "Descend to floor %d?" % (current_floor + 1)
		_enqueue_message(prompt)
		return true
	if interaction == "dungeon_boss" and current_floor >= floor_count:
		_boss_battle_active = true
		return false
	
	# Handle puzzle switches
	if interaction.begins_with("dungeon_switch_"):
		return _handle_puzzle_switch_interaction(npc, interaction)
	
	# Handle key
	if interaction == "dungeon_key":
		return _handle_key_interaction(npc)
	if interaction == "dungeon_quest_delivery_item":
		return _handle_quest_delivery_item(npc)
	
	# Handle quest NPCs
	if interaction == "dungeon_quest_delivery":
		return _handle_quest_delivery(npc)
	if interaction == "dungeon_quest_hunt":
		return _handle_quest_hunt(npc)
	if interaction == "dungeon_quest_thief":
		return _handle_quest_thief(npc)
	
	# Handle event objects + loose items
	if interaction.begins_with("dungeon_loose_item"):
		return _handle_loose_item(npc)
	if interaction == "dungeon_healing_spring":
		return _handle_healing_spring(npc)
	if interaction == "dungeon_gold_stash":
		return _handle_gold_stash(npc)
	if interaction == "dungeon_essence_cache":
		return _handle_essence_cache(npc)
	if interaction == "dungeon_status_trap":
		return _handle_status_trap(npc)
	if interaction == "dungeon_merchant_cache":
		return _handle_merchant_shop(npc)
	if interaction == "dungeon_monster_egg":
		return _handle_monster_egg(npc)
	if interaction == "dungeon_cursed_altar":
		return _handle_cursed_altar(npc)
	if interaction == "dungeon_secret_vault":
		return _handle_secret_vault(npc)
	
	return false

func _handle_custom_message_closed() -> bool:
	if _pending_floor_advance:
		_pending_floor_advance = false
		_advance_floor()
		return true
	if _pending_return_to_hub:
		_pending_return_to_hub = false
		_finish_dungeon_run()
		_request_world_change(hub_scene_path)
		return true
	return false

func _on_step_finished() -> void:
	_is_moving = false
	_player_cell = _pending_cell
	if _walk_anim_lock > 0.0:
		_play_move_anim(_last_facing, _last_running)
	elif _get_direction_input() == Vector2i.ZERO:
		_play_idle_anim(_last_facing)
	if _in_battle:
		return
	if _handle_room_entry_trigger():
		return
	if _is_grass_cell(_player_cell) and _rng.randf() < encounter_chance:
		_play_idle_anim(_last_facing)
		_start_random_battle()

func _on_battle_finished(winner_team_index: int) -> void:
	var finished_interaction := ""
	if _active_npc != null and _active_npc.npc_data != null:
		finished_interaction = str(_active_npc.npc_data.interaction_id)
	super._on_battle_finished(winner_team_index)
	_award_battle_rewards(winner_team_index, finished_interaction)
	if winner_team_index == 0 and finished_interaction == "elite_pack":
		_elite_cleared_this_floor = true
		_enqueue_message("Elite pack defeated. The path to the stairs is now open.")
		if Game != null:
			Game.add_soul_essence(elite_battle_soul_essence)
			_enqueue_message("Soul Essence +%d" % elite_battle_soul_essence)
	
	if winner_team_index == 0 and finished_interaction == "dungeon_quest_thief":
		_active_quest["completed"] = true
		if _quest_npc != null:
			_set_npc_active(_quest_npc, false, Vector2i.ZERO)
		_enqueue_message("Quest Complete: You defeated the thief!")
		_award_quest_rewards()
		_log_dungeon("[Dungeon] quest completed type=thief")
	
	# Track monster kills for hunt quests
	if winner_team_index == 0 and finished_interaction == "" and _active_quest.get("quest_type", -1) == QUEST_TYPE.MONSTER_HUNT:
		if _active_quest.get("accepted", false) and not _active_quest.get("completed", false):
			_active_quest["monsters_killed"] += 1
			var killed: int = _active_quest.get("monsters_killed", 0)
			var needed: int = _active_quest.get("monsters_needed", 2)
			if killed >= needed:
				_active_quest["ready_to_turn_in"] = true
				_enqueue_message("Hunt complete. Return to the hunter for your reward.")
				_log_dungeon("[Dungeon] quest hunt ready_to_turn_in kills=%d" % killed)
	
	if winner_team_index == 1:
		_boss_battle_active = false
		_pending_return_to_hub = true
		_enqueue_message("You were defeated. Returning to the city.")
		return
	if _boss_battle_active and winner_team_index == 0:
		_boss_battle_active = false
		_pending_return_to_hub = true
		if Game != null:
			Game.add_soul_essence(boss_battle_soul_essence)
			_enqueue_message("Soul Essence +%d" % boss_battle_soul_essence)
		_enqueue_message("Boss defeated! Returning to the city.")

#  Floor advancement 

func _advance_floor() -> void:
	if current_floor >= floor_count:
		return
	current_floor += 1
	_layout_seed = 0  # fresh layout per floor
	_apply_floor_rules(true)
	_enqueue_message("Floor %d / %d" % [current_floor, floor_count])

func _apply_floor_rules(reset_player: bool) -> void:
	current_floor = clamp(current_floor, 1, max(floor_count, 1))
	floor_count = max(floor_count, 1)
	_start_dungeon_run_if_needed()
	if base_encounter_chance <= 0.0:
		# Explicitly allow encounter-free dungeons via payload/inspector.
		encounter_chance = 0.0
	else:
		encounter_chance = clamp(
			base_encounter_chance + float(current_floor - 1) * 0.015, 0.0, 0.35)
	_log_dungeon("[Dungeon] encounter base=%s effective=%s floor=%d" % [
		str(base_encounter_chance), str(encounter_chance), current_floor])
	_check_monster_egg_hatch()
	_generate_floor_layout()
	_assign_floor_goals()
	_assign_room_roles()
	_apply_layout_to_tilemaps()
	_build_floor_encounters()
	_update_special_npcs()
	_spawn_floor_npcs()
	_maybe_spawn_quest_npc()
	if reset_player or _player != null:
		_reset_player_position()

func _start_random_battle() -> void:
	# Hard safety-net: when encounter chance is configured to zero, no random
	# battles are allowed to start in dungeon floors.
	if base_encounter_chance <= 0.0 or encounter_chance <= 0.0:
		return
	_log_dungeon("[Dungeon] encounter source=wild floor=%d chance=%s" % [current_floor, str(encounter_chance)])
	super._start_random_battle()

func _start_npc_battle(npc) -> void:
	if npc == null or npc.npc_data == null:
		super._start_npc_battle(npc)
		return
	var interaction := str(npc.npc_data.interaction_id)
	if interaction == "elite_pack":
		_log_dungeon("[Dungeon] encounter source=elite room=%d" % _elite_room_index)
	elif interaction == "mimic_pack":
		_log_dungeon("[Dungeon] encounter source=mimic")
	else:
		_log_dungeon("[Dungeon] encounter source=npc id=%s" % interaction)
	super._start_npc_battle(npc)

#  Encounter table 

func _build_floor_encounters() -> void:
	encounter_table.clear()
	var monster_paths := _get_habitat_monster_paths()
	var weights := _get_habitat_weights()
	for i in range(monster_paths.size()):
		var monster := load(monster_paths[i]) as MTMonsterData
		if monster == null:
			continue
		var entry := EncounterEntryClass.new()
		entry.monster = monster
		entry.min_level = max(1, current_floor * 2 - 1 + i)
		entry.max_level = entry.min_level + 2 + int(current_floor / 2.0)
		entry.weight = int(weights[i]) if i < weights.size() else 5
		encounter_table.append(entry)

	if encounter_table.is_empty():
		var fallback := load("res://data/monsters/slime/slime.tres") as MTMonsterData
		if fallback != null:
			var e := EncounterEntryClass.new()
			e.monster = fallback
			e.min_level = max(1, current_floor)
			e.max_level = e.min_level + 2
			e.weight = 10
			encounter_table.append(e)

#  NPC caching 

func _cache_special_npcs() -> void:
	_stairs_npc = null
	_boss_npc = null
	_disabled_static_npcs.clear()

	# Enforce canonical dungeon NPC data on the static slots.
	for npc in _npcs:
		if npc == null:
			continue
		if npc.name == "NPC_1":
			npc.npc_data = STAIRS_NPC_DATA
		if npc.name == "NPC_2":
			npc.npc_data = BOSS_NPC_DATA

	for npc in _npcs:
		if npc == null or npc.npc_data == null:
			continue
		_npc_spawn_positions[npc] = npc.global_position
		var interaction: String = str(npc.npc_data.interaction_id)
		if interaction == "dungeon_stairs":
			if _stairs_npc == null:
				_stairs_npc = npc
			else:
				_disable_static_npc(npc)
		elif interaction == "dungeon_boss":
			if _boss_npc == null:
				_boss_npc = npc
			else:
				_disable_static_npc(npc)
		else:
			_disable_static_npc(npc)

func _disable_static_npc(npc) -> void:
	if npc == null:
		return
	npc.visible = false
	npc.set_process(false)
	npc.set_physics_process(false)
	npc.global_position = Vector2(-10000, -10000)
	_disabled_static_npcs.append(npc)

#  Special NPC placement 

func _update_special_npcs() -> void:
	if _room_rects.is_empty():
		_log_dungeon("[Dungeon] _update_special_npcs: no rooms  skipping")
		return

	var start_cell := _room_center(_room_rects[0])
	# Stairs / boss are placed in the farthest room from the player's spawn.
	var far_room := _room_rects[_get_farthest_room_index(0)]
	var far_cell := _room_center(far_room)
	_player_spawn_cell = start_cell

	_log_dungeon("[Dungeon] spawn=%s  stairs/boss=%s  world=%s" % [
		str(start_cell), str(far_cell), str(_cell_to_world(far_cell))])

	if current_floor < floor_count:
		_set_npc_active(_stairs_npc, true, far_cell)
		_set_npc_active(_boss_npc, false, Vector2i.ZERO)
	else:
		_set_npc_active(_stairs_npc, false, Vector2i.ZERO)
		_prepare_boss_npc()
		_set_npc_active(_boss_npc, true, far_cell)

func _set_npc_active(npc, active: bool, cell: Vector2i) -> void:
	if npc == null:
		return
	npc.visible = active
	npc.set_process(active)
	npc.set_physics_process(active)
	if active:
		npc.global_position = _cell_to_world(cell)
		if npc.npc_data != null:
			if npc.npc_data.interaction_id == "dungeon_stairs":
				npc.modulate = Color(0.6, 0.9, 1.0, 1.0)   # blue tint
			elif npc.npc_data.interaction_id == "dungeon_boss":
				npc.modulate = Color(1.0, 0.5, 0.5, 1.0)   # red tint
			else:
				npc.modulate = Color(1, 1, 1, 1)
		if npc.has_method("set_tile_layer"):
			npc.set_tile_layer(_grass_layer)
	else:
		npc.global_position = Vector2(-10000, -10000)

func _prepare_boss_npc() -> void:
	if _boss_npc == null or _boss_npc.npc_data == null:
		return
	var boss_data: MTNPCData = _boss_npc.npc_data.duplicate(true) as MTNPCData
	if boss_data == null:
		return
	boss_data.battle_once = true
	var upgraded_entries: Array[MTNPCMonsterEntry] = []
	for entry in boss_data.team_entries:
		if entry == null:
			continue
		var upgraded_entry: MTNPCMonsterEntry = entry.duplicate(true) as MTNPCMonsterEntry
		if upgraded_entry == null:
			continue
		upgraded_entry.level = max(int(upgraded_entry.level), 6 + current_floor * 2)
		if upgraded_entry.monster_data == null:
			upgraded_entry.monster_data = _pick_monster_for_habitat()
		upgraded_entries.append(upgraded_entry)

	var target_team_size: int = max(1, boss_team_size)
	while upgraded_entries.size() < target_team_size:
		var extra := NPCMonsterEntryClass.new()
		extra.monster_data = _pick_monster_for_habitat()
		extra.level = max(8, current_floor * 2 + 4 + _rng.randi_range(0, 2))
		upgraded_entries.append(extra)

	if upgraded_entries.size() > target_team_size:
		upgraded_entries = upgraded_entries.slice(0, target_team_size)
	boss_data.team_entries = upgraded_entries
	_log_dungeon("[Dungeon] boss team prepared size=%d" % boss_data.team_entries.size())
	_boss_npc.npc_data = boss_data

#  Dynamic NPC spawning 

func _spawn_floor_npcs() -> void:
	_clear_dynamic_npcs()
	if _floor_cells.size() < 8:
		return

	var valid_spawn_cells := 0
	for cell in _floor_cells:
		if _is_safe_npc_spawn_cell(cell) and not _is_chokepoint_cell(cell):
			valid_spawn_cells += 1
	_log_dungeon("[Dungeon] npc_spawn candidates=%d floor_cells=%d rooms=%d corridors=%d" % [
		valid_spawn_cells, _floor_cells.size(), _room_cells_lookup.size(), _corridor_cells_lookup.size()])

	var reserved: Dictionary = {}
	reserved[_player_spawn_cell] = true
	if _stairs_npc != null and _stairs_npc.visible:
		reserved[_world_to_cell(_stairs_npc.global_position)] = true
	if _boss_npc != null and _boss_npc.visible:
		reserved[_world_to_cell(_boss_npc.global_position)] = true
	_spawn_elite_room_npc(reserved)
	_spawn_mimic_npc(reserved)
	_spawn_puzzle_switches(reserved)
	_spawn_key_npc(reserved)
	_spawn_event_object(reserved)
	_spawn_loose_items(reserved)
	_spawn_secret_vault(reserved)

func _spawn_event_object(reserved: Dictionary) -> void:
	if current_floor >= floor_count:
		return
	if _rng.randf() > clamp(event_object_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		return
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		return
	reserved[cell] = true
	# Pick one of 7 event types with equal weight
	var event_type := _rng.randi_range(0, 6)
	var event_data: MTNPCData
	match event_type:
		0: event_data = _create_healing_spring_npc_data()
		1: event_data = _create_gold_stash_npc_data()
		2: event_data = _create_essence_cache_npc_data()
		3: event_data = _create_status_trap_npc_data()
		4: event_data = _create_merchant_cache_npc_data()
		5: event_data = _create_monster_egg_npc_data()
		_: event_data = _create_cursed_altar_npc_data()
	_spawn_dynamic_npc(cell, event_data)
	_log_dungeon("[Dungeon] event object spawned type=%d cell=%s" % [event_type, str(cell)])

func _spawn_loose_items(reserved: Dictionary) -> void:
	var count: int = _rng.randi_range(0, loose_item_max_count)
	for _i in range(count):
		var room_index: int = _pick_normal_room_index()
		if room_index < 0:
			break
		var cell := _pick_cell_in_room(room_index, reserved)
		if cell == Vector2i(-1, -1):
			continue
		reserved[cell] = true
		var item_id := _pick_or_create_random_item()
		_spawn_dynamic_npc(cell, _create_loose_item_npc_data(item_id))
	if count > 0:
		_log_dungeon("[Dungeon] loose items spawned count=%d" % count)

func _spawn_secret_vault(reserved: Dictionary) -> void:
	if current_floor >= floor_count:
		return
	if _rng.randf() > clamp(secret_vault_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		return
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		return
	reserved[cell] = true
	_spawn_dynamic_npc(cell, _create_secret_vault_npc_data())
	_log_dungeon("[Dungeon] secret vault spawned cell=%s" % str(cell))

func _spawn_elite_room_npc(reserved: Dictionary) -> void:
	if _current_floor_goal != FLOOR_GOAL_TYPE.ELITE:
		_elite_cleared_this_floor = true
		return
	if current_floor >= floor_count:
		_elite_cleared_this_floor = true
		_log_dungeon("[Dungeon] elite disabled on boss floor")
		return
	if _elite_room_index < 0 or _elite_room_index >= _room_rects.size():
		_elite_cleared_this_floor = true
		return
	var cell := _pick_cell_in_room(_elite_room_index, reserved)
	if cell == Vector2i(-1, -1):
		_elite_cleared_this_floor = true
		_log_dungeon("[Dungeon] elite room has no valid spawn cell; unlocking stairs")
		return
	reserved[cell] = true
	_spawn_dynamic_npc(cell, _create_elite_npc_data())
	_elite_cleared_this_floor = false

func _spawn_mimic_npc(reserved: Dictionary) -> void:
	if current_floor < mimic_min_floor:
		return
	if _rng.randf() > clamp(mimic_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		return
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		return
	reserved[cell] = true
	_spawn_dynamic_npc(cell, _create_mimic_npc_data())
	_log_dungeon("[Dungeon] mimic spawned room=%d cell=%s" % [room_index, str(cell)])

func _spawn_puzzle_switches(reserved: Dictionary) -> void:
	if _current_floor_goal != FLOOR_GOAL_TYPE.PUZZLE:
		return
	if _switches_total <= 0:
		return
	
	# Spawn _switches_total switches (typically 3) in different rooms
	for i in range(_switches_total):
		var room_index: int = _pick_normal_room_index()
		if room_index < 0:
			_log_dungeon("[Dungeon] puzzle: no valid room for switch %d" % (i + 1))
			continue
		var cell := _pick_cell_in_room(room_index, reserved)
		if cell == Vector2i(-1, -1):
			_log_dungeon("[Dungeon] puzzle: no valid cell in room %d for switch %d" % [room_index, i + 1])
			continue
		reserved[cell] = true
		var switch_data := _create_puzzle_switch_npc_data(i + 1)
		_spawn_dynamic_npc(cell, switch_data)
		_log_dungeon("[Dungeon] puzzle switch %d spawned at cell=%s" % [i + 1, str(cell)])

func _spawn_key_npc(reserved: Dictionary) -> void:
	if _current_floor_goal != FLOOR_GOAL_TYPE.KEY:
		return
	
	# Pick a random normal room for the key
	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		_log_dungeon("[Dungeon] key: no valid room found")
		return
	
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		_log_dungeon("[Dungeon] key: no valid cell in room %d" % room_index)
		return
	
	reserved[cell] = true
	_spawn_dynamic_npc(cell, _create_key_npc_data())
	_log_dungeon("[Dungeon] key spawned at cell=%s in room=%d" % [str(cell), room_index])

func _pick_normal_room_index() -> int:
	var candidates: Array[int] = []
	for i in range(_room_rects.size()):
		var room_type := str(_room_type_by_index.get(i, ROOM_TYPE_NORMAL))
		if room_type != ROOM_TYPE_NORMAL:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	return int(candidates[_rng.randi_range(0, candidates.size() - 1)])

func _pick_cell_in_room(room_index: int, reserved: Dictionary) -> Vector2i:
	if room_index < 0 or room_index >= _room_rects.size():
		return Vector2i(-1, -1)
	var room := _room_rects[room_index]
	var candidates: Array[Vector2i] = []
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			var cell := Vector2i(x, y)
			if reserved.has(cell):
				continue
			if not _is_safe_npc_spawn_cell(cell):
				continue
			if _is_chokepoint_cell(cell):
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _spawn_dynamic_npc(cell: Vector2i, npc_data: MTNPCData) -> void:
	var template = _stairs_npc if _stairs_npc != null else _boss_npc
	if template == null:
		return
	var npc = template.duplicate()
	npc.name = "FloorNPC_%d" % (_dynamic_npcs.size() + 1)
	npc.npc_data = npc_data
	npc.visible = true
	npc.set_process(true)
	npc.set_physics_process(true)
	add_child(npc)
	npc.global_position = _cell_to_world(cell)
	if npc.npc_data != null:
		var interaction := str(npc.npc_data.interaction_id)
		if interaction == "elite_pack":
			npc.modulate = Color(1.0, 0.8, 0.5, 1.0)
		elif interaction == "mimic_pack":
			npc.modulate = Color(0.8, 1.0, 0.7, 1.0)
	if npc.has_method("set_tile_layer"):
		npc.set_tile_layer(_grass_layer)
	_dynamic_npcs.append(npc)
	_npcs.append(npc)

func _clear_dynamic_npcs() -> void:
	for npc in _dynamic_npcs:
		if npc == null:
			continue
		_npcs.erase(npc)
		npc.queue_free()
	_dynamic_npcs.clear()

func _create_battle_npc_data(index: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Wanderer %d" % index
	data.dialogue_before = "The dungeon belongs to the strongest."
	data.battle_once = true
	data.walk_enabled = false
	var team_size := 1 if current_floor < 3 else 2
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = _pick_monster_for_habitat()
		entry.level = max(2, current_floor * 2 + _rng.randi_range(0, 2))
		data.team_entries.append(entry)
	return data

func _create_item_npc_data(index: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Explorer %d" % index
	data.dialogue_before = "Found this on this floor. Take it."
	data.gives_items = true
	data.give_item_amount = 1
	data.battle_once = true
	data.walk_enabled = false
	if not item_reward_pool.is_empty():
		var item_id := item_reward_pool[_rng.randi_range(0, item_reward_pool.size() - 1)]
		data.give_item_ids = [item_id]
	return data

func _create_elite_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Elite"
	data.dialogue_before = "A concentrated pack of wild monsters surrounds you."
	data.dialogue_after = "The elite pack has been defeated."
	data.interaction_id = "elite_pack"
	data.battle_once = true
	data.walk_enabled = false
	var team_size: int = min(5, 1 + int(current_floor / 5.0))
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = _pick_monster_for_habitat()
		entry.level = max(3, current_floor * 2 + 3 + _rng.randi_range(0, 2))
		data.team_entries.append(entry)
	return data

func _create_mimic_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Mimic"
	data.dialogue_before = "A lonely chest twitches... it was bait!"
	data.dialogue_after = "The mimic vanishes into the shadows."
	data.interaction_id = "mimic_pack"
	data.battle_once = true
	data.walk_enabled = false
	var team_size := 1 if current_floor < 4 else 2
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = _pick_monster_for_habitat()
		entry.level = max(4, current_floor * 2 + 4 + _rng.randi_range(0, 3))
		data.team_entries.append(entry)
	return data

func _create_puzzle_switch_npc_data(switch_number: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Switch %d" % switch_number
	data.dialogue_before = "You activate the switch. A mechanism clicks into place."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_switch_%d" % switch_number
	data.battle_once = false
	data.walk_enabled = false
	# Switches have no team - they are just interactive objects
	return data

func _create_key_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Glowing Key"
	data.dialogue_before = "You pick up the ancient key. It glows with power."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_key"
	data.battle_once = false
	data.walk_enabled = false
	# Key has no team - it is just an interactive item
	return data

func _create_healing_spring_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Healing Spring"
	data.dialogue_before = "A bubbling spring glows with restorative energy. (Restores HP and Energy once)"
	data.dialogue_after = ""
	data.interaction_id = "dungeon_healing_spring"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_gold_stash_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Gold Chest"
	data.dialogue_before = "A dusty chest rests here, filled with coins!"
	data.dialogue_after = ""
	data.interaction_id = "dungeon_gold_stash"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_essence_cache_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Soul Essence Cache"
	data.dialogue_before = "A crystalline orb pulses with condensed Soul Essence."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_essence_cache"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_status_trap_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Suspicious Rune"
	data.dialogue_before = "Strange runes glow on the floor here... (Possible trap!)"
	data.dialogue_after = ""
	data.interaction_id = "dungeon_status_trap"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_merchant_cache_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Hidden Merchant Cache"
	data.dialogue_before = "A small supply cache has been left behind by a passing merchant."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_merchant_cache"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_monster_egg_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Monster Egg"
	data.dialogue_before = "A warm egg rests here. Something stirs inside..."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_monster_egg"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_cursed_altar_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Cursed Altar"
	data.dialogue_before = "A dark altar radiates power. Risk your team's health for rewards?"
	data.dialogue_after = ""
	data.interaction_id = "dungeon_cursed_altar"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_loose_item_npc_data(item_id: String) -> MTNPCData:
	var data := NPCDataClass.new()
	var item_data: MTItemData = ITEM_DB_CLASS.new().get_item(item_id)
	data.display_name = item_data.name if item_data != null else item_id
	data.dialogue_before = "You find %s lying on the ground." % (item_data.name if item_data != null else item_id)
	data.dialogue_after = ""
	data.interaction_id = "dungeon_loose_item:" + item_id
	data.battle_once = false
	data.walk_enabled = false
	return data

func _create_secret_vault_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Secret Vault"
	data.dialogue_before = "A heavy iron vault. This requires a Secret Key to open."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_secret_vault"
	data.battle_once = false
	data.walk_enabled = false
	return data



func _pick_monster_for_habitat() -> MTMonsterData:
	var paths := _get_habitat_monster_paths()
	if paths.is_empty():
		return load("res://data/monsters/slime/slime.tres") as MTMonsterData
	var path := paths[_rng.randi_range(0, paths.size() - 1)]
	var result := load(path) as MTMonsterData
	if result != null:
		return result
	return load("res://data/monsters/slime/slime.tres") as MTMonsterData

func _pick_free_floor_cell(reserved: Dictionary) -> Vector2i:
	if _floor_cells.is_empty():
		return Vector2i(-1, -1)
	for _i in range(200):
		var cell := _floor_cells[_rng.randi_range(0, _floor_cells.size() - 1)]
		if reserved.has(cell):
			continue
		if not _is_safe_npc_spawn_cell(cell):
			continue
		if _is_chokepoint_cell(cell):
			continue
		return cell
	return Vector2i(-1, -1)

func _is_safe_npc_spawn_cell(cell: Vector2i) -> bool:
	# NPCs may only spawn inside rooms, never in corridors.
	if not _room_cells_lookup.has(cell):
		return false

	# Keep at least one tile distance from corridors so passages stay open.
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var n := cell + Vector2i(x, y)
			if _corridor_cells_lookup.has(n):
				return false
	return true

func _is_chokepoint_cell(cell: Vector2i) -> bool:
	var n := 0
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _has_tile(_dirt_layer, cell + dir):
			n += 1
	return n <= 1

#  Layout generation 

func _generate_floor_layout() -> void:
	if generation_seed > 0:
		_rng.seed = int(generation_seed + current_floor * 104729)
	elif _layout_seed > 0:
		# Reuse the saved seed so that calling _apply_floor_rules a second time
		# (from apply_world_payload) produces the exact same layout.
		_rng.seed = _layout_seed
	else:
		_rng.randomize()
		_layout_seed = _rng.seed  # remember for stable re-generation

	_room_rects.clear()
	_room_cells_lookup.clear()
	_corridor_cells_lookup.clear()
	_room_type_by_index.clear()
	_room_index_by_cell.clear()
	_visited_room_indices.clear()
	_elite_room_index = -1
	_event_room_index = -1
	_elite_cleared_this_floor = false
	_reset_floor_quest_state()
	_log_dungeon("[Dungeon] generating floor %d/%d  seed=%d" % [current_floor, floor_count, _rng.seed])

	var carved := {}
	var target_rooms := _rng.randi_range(min_room_count, max_room_count)
	var attempts := target_rooms * 24

	for _i in range(attempts):
		if _room_rects.size() >= target_rooms:
			break
		var room_w := _rng.randi_range(min_room_size, max_room_size)
		var room_h := _rng.randi_range(min_room_size, max_room_size)
		var room_x := _rng.randi_range(2, max(2, map_width - room_w - 3))
		var room_y := _rng.randi_range(2, max(2, map_height - room_h - 3))
		var room := Rect2i(room_x, room_y, room_w, room_h)
		if _room_intersects_existing(room):
			continue
		_room_rects.append(room)
		_carve_room(room, carved)

	if _room_rects.is_empty():
		var fx: int = max(2, int(map_width / 2.0) - 3)
		var fy: int = max(2, int(map_height / 2.0) - 3)
		var fallback := Rect2i(fx, fy, 6, 6)
		_room_rects.append(fallback)
		_carve_room(fallback, carved)

	for i in range(1, _room_rects.size()):
		_carve_corridor(_room_center(_room_rects[i - 1]), _room_center(_room_rects[i]), carved)
	_build_room_index_lookup()

	_floor_cells.clear()
	for cell_key in carved.keys():
		_floor_cells.append(cell_key)
	_log_dungeon("[Dungeon] %d rooms  %d floor cells" % [_room_rects.size(), _floor_cells.size()])

#  Tile-map painting 
#
# Strategy:
#    Grass layer is wiped completely (removes hub-city tiles).
#    Floor cells are painted onto the Dirt layer (z_index 1 = clearly visible).
#    Wall areas are intentionally left empty; the engine's background colour
#     shows through, giving the classic dark-dungeon look that is visually
#     distinct from the hub-city.
#
# _is_cell_walkable (overridden above) checks the Dirt layer, so only
# explicitly painted cells are passable.
#
func _apply_layout_to_tilemaps() -> void:
	_log_dungeon("[Dungeon] _apply_layout_to_tilemaps  cells=%d" % _floor_cells.size())
	if _grass_layer == null or _dirt_layer == null:
		_log_dungeon("[Dungeon] ERROR: tile layer is null  aborting")
		return

	# Resolve a visible floor tile first. If the exported atlas is blank,
	# fallback to a sampled tile that is already used in the scene's Dirt layer.
	var paint_source_id := floor_tile_source_id
	var paint_atlas := floor_tile_atlas
	var sampled := _sample_existing_floor_tile()
	if sampled.has("source_id") and int(sampled["source_id"]) >= 0:
		paint_source_id = int(sampled["source_id"])
		paint_atlas = sampled["atlas"] as Vector2i

	# Wipe both layers so no hub-city tiles survive.
	_grass_layer.clear()
	_dirt_layer.clear()

	# Paint floor tiles onto Dirt only.
	for cell in _floor_cells:
		_dirt_layer.set_cell(cell, paint_source_id, paint_atlas)

	_log_dungeon("[Dungeon] painted %d floor tiles (src=%d  atlas=%s)" % [
		_floor_cells.size(), paint_source_id, str(paint_atlas)])

func _sample_existing_floor_tile() -> Dictionary:
	if _dirt_layer == null:
		return {}
	var used := _dirt_layer.get_used_cells()
	if used.is_empty():
		return {}
	for cell in used:
		var src := _dirt_layer.get_cell_source_id(cell)
		if src < 0:
			continue
		var atlas := _dirt_layer.get_cell_atlas_coords(cell)
		if atlas == Vector2i(-1, -1):
			continue
		return {"source_id": src, "atlas": atlas}
	return {}

#  Geometry helpers 

func _room_intersects_existing(candidate: Rect2i) -> bool:
	for room in _room_rects:
		var expanded := Rect2i(room.position - Vector2i.ONE, room.size + Vector2i(2, 2))
		if expanded.intersects(candidate):
			return true
	return false

func _carve_room(room: Rect2i, carved: Dictionary) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			var cell := Vector2i(x, y)
			carved[cell] = true
			_room_cells_lookup[cell] = true
			if _corridor_cells_lookup.has(cell):
				_corridor_cells_lookup.erase(cell)

func _carve_corridor(start: Vector2i, target: Vector2i, carved: Dictionary) -> void:
	var current := start
	while current.x != target.x:
		carved[current] = true
		if not _room_cells_lookup.has(current):
			_corridor_cells_lookup[current] = true
		current.x += 1 if target.x > current.x else -1
	while current.y != target.y:
		carved[current] = true
		if not _room_cells_lookup.has(current):
			_corridor_cells_lookup[current] = true
		current.y += 1 if target.y > current.y else -1
	carved[target] = true
	if not _room_cells_lookup.has(target):
		_corridor_cells_lookup[target] = true

func _room_center(room: Rect2i) -> Vector2i:
	return Vector2i(
		room.position.x + int(room.size.x / 2.0),
		room.position.y + int(room.size.y / 2.0))

func _build_room_index_lookup() -> void:
	_room_index_by_cell.clear()
	for i in range(_room_rects.size()):
		var room := _room_rects[i]
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				_room_index_by_cell[Vector2i(x, y)] = i

func _assign_room_roles() -> void:
	_room_type_by_index.clear()
	if _room_rects.is_empty():
		return
	for i in range(_room_rects.size()):
		_room_type_by_index[i] = ROOM_TYPE_NORMAL

	var start_index := 0
	var exit_index := _get_farthest_room_index(start_index)
	_room_type_by_index[start_index] = ROOM_TYPE_START
	_room_type_by_index[exit_index] = ROOM_TYPE_EXIT

	var candidates: Array[int] = []
	for i in range(_room_rects.size()):
		if i == start_index or i == exit_index:
			continue
		candidates.append(i)
	if candidates.is_empty():
		_log_dungeon("[Dungeon] room roles: only start/exit available")
		return

	candidates.sort_custom(func(a: int, b: int):
		return _room_distance(start_index, a) > _room_distance(start_index, b))

	_elite_room_index = -1
	if current_floor < floor_count and _current_floor_goal == FLOOR_GOAL_TYPE.ELITE:
		_elite_room_index = candidates[0]
		_room_type_by_index[_elite_room_index] = ROOM_TYPE_ELITE

	_log_dungeon("[Dungeon] room roles start=%d exit=%d elite=%d" % [
		start_index, exit_index, _elite_room_index])

func _assign_floor_goals() -> void:
	# Reset goal state
	_floor_goal_state.clear()
	_switches_total = 0
	_switches_activated = 0
	_key_found_this_floor = false
	_elite_cleared_this_floor = true

	# Boss floor has no stair objective events (key/switch/elite).
	if current_floor >= floor_count:
		_current_floor_goal = FLOOR_GOAL_TYPE.OPEN
		_log_dungeon("[Dungeon] floor goal=OPEN (boss floor)")
		return
	
	# Assign goal based on probabilities (50% open, 30% elite, 10% key, 10% puzzle)
	var roll: int = _rng.randi_range(0, 99)
	var cumulative: int = 0
	
	# Open (50%)
	if roll < cumulative + goal_prob_open:
		_current_floor_goal = FLOOR_GOAL_TYPE.OPEN
		_log_dungeon("[Dungeon] floor goal=OPEN")
		return
	cumulative += goal_prob_open
	
	# Elite (30%)
	if roll < cumulative + goal_prob_elite:
		_current_floor_goal = FLOOR_GOAL_TYPE.ELITE
		_log_dungeon("[Dungeon] floor goal=ELITE")
		return
	cumulative += goal_prob_elite
	
	# Key (10%)
	if roll < cumulative + goal_prob_key:
		_current_floor_goal = FLOOR_GOAL_TYPE.KEY
		_floor_goal_state["key_found"] = false
		_log_dungeon("[Dungeon] floor goal=KEY")
		return
	cumulative += goal_prob_key
	
	# Puzzle (10%) - default fallthrough
	_current_floor_goal = FLOOR_GOAL_TYPE.PUZZLE
	_switches_total = 3
	_switches_activated = 0
	_floor_goal_state["switches_activated"] = 0
	_floor_goal_state["switches_total"] = 3
	_log_dungeon("[Dungeon] floor goal=PUZZLE switches_total=3")

func _get_farthest_room_index(origin_index: int) -> int:
	if _room_rects.is_empty():
		return 0
	var oi: int = clampi(origin_index, 0, _room_rects.size() - 1)
	var origin: Vector2i = _room_center(_room_rects[oi])
	var best_index: int = oi
	var best_dist: int = -1
	for i in range(_room_rects.size()):
		var center := _room_center(_room_rects[i])
		var dist: int = abs(center.x - origin.x) + abs(center.y - origin.y)
		if dist > best_dist:
			best_dist = dist
			best_index = i
	return best_index

func _room_distance(a_index: int, b_index: int) -> int:
	if a_index < 0 or a_index >= _room_rects.size():
		return 0
	if b_index < 0 or b_index >= _room_rects.size():
		return 0
	var a := _room_center(_room_rects[a_index])
	var b := _room_center(_room_rects[b_index])
	return abs(a.x - b.x) + abs(a.y - b.y)

func _handle_room_entry_trigger() -> bool:
	if _player == null:
		return false
	if _room_index_by_cell.is_empty():
		return false
	if not _room_index_by_cell.has(_player_cell):
		return false
	var room_index: int = int(_room_index_by_cell[_player_cell])
	if _visited_room_indices.has(room_index):
		return false
	_visited_room_indices[room_index] = true

	var room_type := str(_room_type_by_index.get(room_index, ROOM_TYPE_NORMAL))
	if room_type == ROOM_TYPE_ELITE:
		_enqueue_message("An elite presence fills this room.")
		return true
	return false

func _handle_loose_item(npc) -> bool:
	if npc == null or npc.npc_data == null:
		return true
	var interaction: String = str(npc.npc_data.interaction_id)
	var parts := interaction.split(":")
	var item_id := "lesser_healing_potion"
	if parts.size() >= 2:
		item_id = parts[1]
	if Game != null:
		Game.add_item(item_id, 1)
	var item_data: MTItemData = ITEM_DB_CLASS.new().get_item(item_id)
	var item_name := item_data.name if item_data != null else item_id
	_set_npc_active(npc, false, Vector2i.ZERO)
	_enqueue_message("You picked up %s!" % item_name)
	return true

func _handle_healing_spring(npc) -> bool:
	var healed := _heal_party_percent(0.40)
	var energized := _restore_party_energy_percent(0.40)
	_set_npc_active(npc, false, Vector2i.ZERO)
	_enqueue_message("Healing Spring: Your team is refreshed. (%d healed, %d recharged)" % [healed, energized])
	_log_dungeon("[Dungeon] healing spring used healed=%d energized=%d" % [healed, energized])
	return true

func _handle_gold_stash(npc) -> bool:
	var amount := 10 + current_floor * 3
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_run_gold(amount)
	_enqueue_message("You found a gold stash! Gold +%d" % amount)
	_log_dungeon("[Dungeon] gold stash amount=%d" % amount)
	return true

func _handle_essence_cache(npc) -> bool:
	var amount := 1 + int(current_floor / 10.0)
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_soul_essence(amount)
	_enqueue_message("Soul Essence Cache: You absorb the power. Soul Essence +%d" % amount)
	_log_dungeon("[Dungeon] essence cache amount=%d" % amount)
	return true

func _handle_status_trap(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game == null or Game.party.is_empty():
		_enqueue_message("A trap springs! But there is nothing to harm.")
		return true
	for monster in Game.party:
		if monster == null:
			continue
		var m := monster as MTMonsterInstance
		if m == null or m.hp <= 0:
			continue
		var damage := int(ceil(m.get_max_hp() * 0.25))
		m.hp = max(1, m.hp - damage)
		var mname := m.data.name if m.data != null else "Monster"
		_enqueue_message("It's a trap! %s lost %d HP!" % [mname, damage])
		_log_dungeon("[Dungeon] status trap triggered hp_lost=%d" % damage)
		break
	return true

func _handle_monster_egg(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_item("monster_egg", 1)
	_enqueue_message("You found a Monster Egg! It will hatch on the next floor.")
	_log_dungeon("[Dungeon] monster egg picked up")
	return true

func _handle_cursed_altar(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game == null:
		_enqueue_message("The altar pulses with dark energy, but nothing happens.")
		return true
	var total_lost := 0
	for monster in Game.party:
		if monster == null:
			continue
		var m := monster as MTMonsterInstance
		if m == null or m.hp <= 0:
			continue
		var damage := int(ceil(m.get_max_hp() * 0.30))
		m.hp = max(1, m.hp - damage)
		total_lost += damage
	var gold_gain := 10 + current_floor * 2
	Game.add_soul_essence(1)
	Game.add_run_gold(gold_gain)
	_enqueue_message("Cursed Altar: Your team suffers %d total damage... Soul Essence +1, Gold +%d." % [total_lost, gold_gain])
	_log_dungeon("[Dungeon] cursed altar used hp_lost=%d gold=%d" % [total_lost, gold_gain])
	return true

func _handle_secret_vault(npc) -> bool:
	if Game == null or Game.get_item_count("secret_key") <= 0:
		_enqueue_message("Locked. You need a Secret Key to open this vault.")
		return true
	Game.remove_item("secret_key", 1)
	_set_npc_active(npc, false, Vector2i.ZERO)
	# Vault rewards: 1 random item + gold + soul essence
	var item_id := _pick_or_create_random_item()
	if Game != null:
		Game.add_item(item_id, 1)
	var gold := 20 + current_floor * 4
	if Game != null:
		Game.add_run_gold(gold)
		Game.add_soul_essence(2)
	_enqueue_message("Secret Vault opened! Found items, Gold +%d, and Soul Essence +2!" % gold)
	_log_dungeon("[Dungeon] secret vault opened gold=%d" % gold)
	return true

func _check_monster_egg_hatch() -> void:
	if Game == null or Game.get_item_count("monster_egg") <= 0:
		return
	if Game.party.size() >= 6:
		_enqueue_message("Your egg is ready to hatch, but your team is full!")
		return
	Game.remove_item("monster_egg", 1)
	var monster_data := _pick_monster_for_habitat()
	if monster_data == null:
		return
	var new_monster := MTMonsterInstance.new(monster_data)
	new_monster.level = max(1, current_floor - 1)
	new_monster._recalculate_stats()
	new_monster.hp = new_monster.get_max_hp()
	Game.party.append(new_monster)
	_enqueue_message("Your Monster Egg hatched! %s joined your team!" % monster_data.name)
	_log_dungeon("[Dungeon] monster egg hatched monster=%s level=%d" % [monster_data.name, new_monster.level])

#  Floor Goal System 

func _is_floor_goal_satisfied() -> bool:
	match _current_floor_goal:
		FLOOR_GOAL_TYPE.OPEN:
			return true
		FLOOR_GOAL_TYPE.ELITE:
			return _elite_cleared_this_floor
		FLOOR_GOAL_TYPE.KEY:
			return _key_found_this_floor
		FLOOR_GOAL_TYPE.PUZZLE:
			return _switches_activated >= _switches_total
		_:
			return true

func _get_goal_blocked_message() -> String:
	match _current_floor_goal:
		FLOOR_GOAL_TYPE.ELITE:
			return "A powerful presence blocks your descent. Defeat the elite room first."
		FLOOR_GOAL_TYPE.KEY:
			return "The stairs are sealed. You must find the key on this floor."
		FLOOR_GOAL_TYPE.PUZZLE:
			return "The stairs are sealed. You must activate all 3 switches (%d/%d)." % [_switches_activated, _switches_total]
		_:
			return "You cannot proceed."

func _handle_puzzle_switch_interaction(npc, interaction: String) -> bool:
	# Parse switch number from interaction_id "dungeon_switch_1" -> 1
	var parts := interaction.split("_")
	if parts.size() < 3:
		return false
	var switch_num: int = int(parts[-1])
	
	# Mark this switch as activated and remove NPC from map
	_switches_activated += 1
	_set_npc_active(npc, false, Vector2i.ZERO)
	
	var progress_msg := "Switch %d activated! (%d/%d)" % [switch_num, _switches_activated, _switches_total]
	_enqueue_message(progress_msg)
	_log_dungeon("[Dungeon] puzzle switch %d activated progress=%d/%d" % [switch_num, _switches_activated, _switches_total])
	
	# Check if all switches are activated
	if _switches_activated >= _switches_total:
		_enqueue_message("All switches activated! The stairs are now open.")
		_log_dungeon("[Dungeon] puzzle completed all switches activated")
	
	return true

#  Quest System 

func _maybe_spawn_quest_npc() -> void:
	if _has_quest_this_floor:
		return
	if current_floor >= floor_count:
		return
	var effective_spawn_chance: float = _get_effective_quest_spawn_chance()
	if _rng.randf() > effective_spawn_chance:
		return
	
	# Pick a random normal room for the quest NPC
	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		return
	
	var reserved: Dictionary = {}
	reserved[_player_spawn_cell] = true
	if _stairs_npc != null and _stairs_npc.visible:
		reserved[_world_to_cell(_stairs_npc.global_position)] = true
	
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		return
	
	# Randomly pick a quest type
	var quest_type: int = _rng.randi_range(0, 2)  # 0=DELIVERY, 1=HUNT, 2=AMBUSH
	
	_active_quest = {
		"quest_type": quest_type,
		"accepted": quest_type == QUEST_TYPE.THIEF_AMBUSH,
		"completed": false,
		"ready_to_turn_in": false,
		"shop_unlocked": false,
		"delivery_item_id": "",
		"monsters_killed": 0,
		"monsters_needed": _rng.randi_range(2, 4)
	}
	_has_quest_this_floor = true
	
	var quest_npc_data := _create_quest_npc_data(quest_type)
	_spawn_dynamic_npc(cell, quest_npc_data)
	_quest_npc = _dynamic_npcs[-1] if _dynamic_npcs.size() > 0 else null
	if quest_type == QUEST_TYPE.ITEM_DELIVERY:
		_spawn_delivery_quest_item(cell)
	
	var quest_names := ["Item Delivery", "Monster Hunt", "Thief Ambush"]
	_log_dungeon("[Dungeon] quest spawned type=%s cell=%s" % [quest_names[quest_type], str(cell)])

func _create_quest_npc_data(quest_type: int) -> MTNPCData:
	var data := NPCDataClass.new()
	var dialogue_before := ""
	var dialogue_after := ""
	var interaction_id := "dungeon_quest"
	
	match quest_type:
		QUEST_TYPE.ITEM_DELIVERY:
			data.display_name = "Merchant"
			dialogue_before = "Please, find me a healing potion on this level!"
			dialogue_after = "Thank you! You're a lifesaver."
			interaction_id = "dungeon_quest_delivery"
		QUEST_TYPE.MONSTER_HUNT:
			data.display_name = "Hunter"
			dialogue_before = "Help me defeat the monsters on this floor!"
			dialogue_after = "Excellent work! You're a true warrior."
			interaction_id = "dungeon_quest_hunt"
		QUEST_TYPE.THIEF_AMBUSH:
			data.display_name = "Thief"
			dialogue_before = "You've encountered a notorious thief!"
			dialogue_after = "Ha! You win this time..."
			interaction_id = "dungeon_quest_thief"
	
	data.dialogue_before = dialogue_before
	data.dialogue_after = dialogue_after
	data.interaction_id = interaction_id
	data.battle_once = false
	data.walk_enabled = false
	
	# Thief ambush has an elite-strength team
	if quest_type == QUEST_TYPE.THIEF_AMBUSH:
		var team_size: int = min(5, 1 + int(current_floor / 5.0))
		for _i in range(team_size):
			var entry := NPCMonsterEntryClass.new()
			entry.monster_data = _pick_monster_for_habitat()
			entry.level = max(3, current_floor * 2 + 3 + _rng.randi_range(0, 2))
			data.team_entries.append(entry)
	
	return data

func _pick_or_create_random_item() -> String:
	if item_reward_pool.is_empty():
		return "lesser_healing_potion"
	return item_reward_pool[_rng.randi_range(0, item_reward_pool.size() - 1)]

func _spawn_delivery_quest_item(quest_cell: Vector2i) -> void:
	var reserved: Dictionary = {}
	reserved[_player_spawn_cell] = true
	reserved[quest_cell] = true
	if _stairs_npc != null and _stairs_npc.visible:
		reserved[_world_to_cell(_stairs_npc.global_position)] = true
	if _boss_npc != null and _boss_npc.visible:
		reserved[_world_to_cell(_boss_npc.global_position)] = true
	for npc in _dynamic_npcs:
		if npc == null or not npc.visible:
			continue
		reserved[_world_to_cell(npc.global_position)] = true

	var room_index: int = _pick_normal_room_index()
	if room_index < 0:
		return
	var cell := _pick_cell_in_room(room_index, reserved)
	if cell == Vector2i(-1, -1):
		return

	var delivery_item_id := "quest_delivery_satchel_floor_%d" % current_floor
	_active_quest["delivery_item_id"] = delivery_item_id
	_spawn_dynamic_npc(cell, _create_delivery_quest_item_npc_data())
	_quest_item_npc = _dynamic_npcs[-1] if _dynamic_npcs.size() > 0 else null
	_log_dungeon("[Dungeon] delivery item spawned id=%s cell=%s" % [delivery_item_id, str(cell)])

func _create_delivery_quest_item_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = "Lost Satchel"
	data.dialogue_before = "You found the merchant's lost satchel."
	data.dialogue_after = ""
	data.interaction_id = "dungeon_quest_delivery_item"
	data.battle_once = false
	data.walk_enabled = false
	return data

func _handle_quest_delivery(npc) -> bool:
	if _active_quest.get("completed", false) and _active_quest.get("shop_unlocked", false):
		return _handle_merchant_shop(npc)
	var delivery_item_id: String = str(_active_quest.get("delivery_item_id", ""))
	if delivery_item_id == "":
		_enqueue_message("The merchant seems to have lost track of the package.")
		return true
	if not _active_quest.get("accepted", false):
		_active_quest["accepted"] = true
		_enqueue_message("Merchant Quest: Find the lost satchel somewhere on this floor.")
		return true
	if Game.get_item_count(delivery_item_id) <= 0:
		_enqueue_message("Merchant Quest: Please find my lost satchel and bring it back.")
		return true
	Game.remove_item(delivery_item_id, 1)
	_active_quest["completed"] = true
	_active_quest["ready_to_turn_in"] = false
	_active_quest["shop_unlocked"] = true
	_enqueue_message("Quest Complete: You returned the lost satchel.")
	_award_quest_rewards()
	_enqueue_message("Merchant unlocked: Trade with run gold is now available.")
	_log_dungeon("[Dungeon] quest completed type=delivery")
	return true

func _handle_quest_hunt(_npc) -> bool:
	if not _active_quest.get("accepted", false):
		_active_quest["accepted"] = true
		var target_count: int = _active_quest.get("monsters_needed", 2)
		_enqueue_message("Hunter Quest accepted: Defeat %d wild encounters on this floor." % target_count)
		_log_dungeon("[Dungeon] quest hunt accepted target=%d" % target_count)
		return true
	if _active_quest.get("ready_to_turn_in", false):
		_active_quest["completed"] = true
		_active_quest["ready_to_turn_in"] = false
		if _quest_npc != null:
			_set_npc_active(_quest_npc, false, Vector2i.ZERO)
		_enqueue_message("Quest Complete: The hunter rewards your work.")
		_award_quest_rewards()
		_log_dungeon("[Dungeon] quest completed type=hunt")
		return true
	# Hunt quest status
	var needed: int = _active_quest.get("monsters_needed", 2)
	var killed: int = _active_quest.get("monsters_killed", 0)
	_enqueue_message("Hunt Quest: %d/%d encounters defeated. Return when the hunt is done." % [killed, needed])
	_log_dungeon("[Dungeon] quest hunt status=%d/%d" % [killed, needed])
	return true

func _handle_quest_delivery_item(npc) -> bool:
	var delivery_item_id: String = str(_active_quest.get("delivery_item_id", ""))
	if delivery_item_id == "":
		return true
	Game.add_item(delivery_item_id, 1)
	if npc != null:
		_set_npc_active(npc, false, Vector2i.ZERO)
	_active_quest["ready_to_turn_in"] = true
	_enqueue_message("You found the lost satchel. Return it to the merchant.")
	_log_dungeon("[Dungeon] quest delivery item picked id=%s" % delivery_item_id)
	return true

func _handle_quest_thief(_npc) -> bool:
	# Thief ambush is a battle
	_enqueue_message("The thief engages you in battle!")
	return false  # Let normal battle flow happen

func _award_quest_rewards() -> void:
	# Quest rewards are run gold + persistent soul essence.
	if Game != null:
		Game.add_run_gold(quest_reward_gold)
		Game.add_soul_essence(quest_reward_soul_essence)
		_enqueue_message("Received %d gold and %d Soul Essence!" % [quest_reward_gold, quest_reward_soul_essence])
		_log_dungeon("[Dungeon] quest reward gold=%d essence=%d" % [quest_reward_gold, quest_reward_soul_essence])
	else:
		_enqueue_message("Quest rewarded! (Game singleton not found)")
		_log_dungeon("[Dungeon] quest reward failed - Game not initialized")

func _reset_floor_quest_state() -> void:
	var old_delivery_item_id: String = str(_active_quest.get("delivery_item_id", ""))
	if old_delivery_item_id != "" and Game != null:
		Game.remove_item(old_delivery_item_id, Game.get_item_count(old_delivery_item_id))
	_active_quest.clear()
	_has_quest_this_floor = false
	_quest_npc = null
	_quest_item_npc = null
	_merchant_shop_index = 0

func _handle_merchant_shop(_npc) -> bool:
	if merchant_shop_items.is_empty():
		_enqueue_message("Merchant: I'm out of stock for this run.")
		return true
	_open_merchant_shop()
	return true

func _create_merchant_shop_ui() -> void:
	_merchant_shop_layer = CanvasLayer.new()
	_merchant_shop_layer.layer = 14
	add_child(_merchant_shop_layer)

	_merchant_shop_panel = PanelContainer.new()
	_merchant_shop_panel.anchor_left = 0.5
	_merchant_shop_panel.anchor_top = 0.5
	_merchant_shop_panel.anchor_right = 0.5
	_merchant_shop_panel.anchor_bottom = 0.5
	_merchant_shop_panel.offset_left = -200
	_merchant_shop_panel.offset_top = -140
	_merchant_shop_panel.offset_right = 200
	_merchant_shop_panel.offset_bottom = 140
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 0.9, 0.65, 1)
	_merchant_shop_panel.add_theme_stylebox_override("panel", panel_style)
	_merchant_shop_layer.add_child(_merchant_shop_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	_merchant_shop_panel.add_child(outer)

	_merchant_shop_title = Label.new()
	_merchant_shop_title.text = "Dungeon Merchant"
	_merchant_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merchant_shop_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	outer.add_child(_merchant_shop_title)

	_merchant_shop_list = VBoxContainer.new()
	_merchant_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_merchant_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_merchant_shop_list.add_theme_constant_override("separation", 4)
	outer.add_child(_merchant_shop_list)

	_merchant_shop_status = Label.new()
	_merchant_shop_status.text = ""
	_merchant_shop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merchant_shop_status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1))
	outer.add_child(_merchant_shop_status)

	_merchant_shop_close_button = Button.new()
	_merchant_shop_close_button.text = "Close"
	_merchant_shop_close_button.focus_mode = Control.FOCUS_ALL
	_merchant_shop_close_button.pressed.connect(_close_merchant_shop)
	outer.add_child(_merchant_shop_close_button)

	_merchant_shop_panel.visible = false

func _rebuild_merchant_shop_buttons() -> void:
	_merchant_shop_buttons.clear()
	for child in _merchant_shop_list.get_children():
		child.queue_free()
	if Game == null:
		var unavailable: Label = Label.new()
		unavailable.text = "Merchant unavailable"
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_merchant_shop_list.add_child(unavailable)
		return
	for i in range(merchant_shop_items.size()):
		var item_id: String = str(merchant_shop_items[i])
		var item_name: String = item_id
		var item_data: MTItemData = ITEM_DB_CLASS.new().get_item(item_id)
		if item_data != null:
			item_name = item_data.name
		var base_price: int = 20
		if i < merchant_shop_prices.size():
			base_price = int(merchant_shop_prices[i])
		var price: int = _apply_merchant_discount(base_price)
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.text = "%s  -  %d gold" % [item_name, price]
		if Game.run_gold < price:
			button.disabled = true
		button.pressed.connect(_on_merchant_buy_pressed.bind(i))
		_merchant_shop_list.add_child(button)
		_merchant_shop_buttons.append(button)

func _open_merchant_shop() -> void:
	if _merchant_shop_panel == null or _merchant_shop_panel.get_parent() == null:
		_create_merchant_shop_ui()
	_rebuild_merchant_shop_buttons()
	_merchant_shop_status.text = "Select an item to buy."
	_merchant_shop_panel.visible = true
	_merchant_shop_open = true
	_pause_npc_walks()
	if _merchant_shop_buttons.size() > 0:
		_merchant_shop_buttons[0].grab_focus()
	else:
		_merchant_shop_close_button.grab_focus()

func _close_merchant_shop() -> void:
	_merchant_shop_open = false
	if _merchant_shop_panel != null:
		_merchant_shop_panel.visible = false
	_resume_npc_walks()
	var viewport = get_viewport()
	if viewport != null:
		viewport.gui_release_focus()

func _on_merchant_buy_pressed(index: int) -> void:
	if Game == null:
		_merchant_shop_status.text = "Merchant unavailable"
		return
	if index < 0 or index >= merchant_shop_items.size():
		return
	var item_id: String = str(merchant_shop_items[index])
	var base_price: int = 20
	if index < merchant_shop_prices.size():
		base_price = int(merchant_shop_prices[index])
	var price: int = _apply_merchant_discount(base_price)
	if not Game.spend_run_gold(price):
		_merchant_shop_status.text = "Not enough gold (%d needed, %d available)." % [price, Game.run_gold]
		_rebuild_merchant_shop_buttons()
		return
	Game.add_item(item_id, 1)
	var item_name: String = item_id
	var item_data: MTItemData = ITEM_DB_CLASS.new().get_item(item_id)
	if item_data != null:
		item_name = item_data.name
	_merchant_shop_status.text = "Bought %s for %d gold." % [item_name, price]
	_log_dungeon("[Dungeon] merchant sale item=%s price=%d run_gold=%d" % [item_id, price, Game.run_gold])
	_rebuild_merchant_shop_buttons()
	if _merchant_shop_buttons.size() > 0:
		_merchant_shop_buttons[0].grab_focus()
	else:
		_merchant_shop_close_button.grab_focus()

func _create_currency_hud() -> void:
	_currency_hud_layer = CanvasLayer.new()
	_currency_hud_layer.layer = 12
	add_child(_currency_hud_layer)
	_currency_hud_label = Label.new()
	_currency_hud_label.anchor_left = 0.0
	_currency_hud_label.anchor_top = 0.5
	_currency_hud_label.anchor_right = 0.0
	_currency_hud_label.anchor_bottom = 0.5
	_currency_hud_label.offset_left = 10
	_currency_hud_label.offset_top = -24
	_currency_hud_label.offset_right = 260
	_currency_hud_label.offset_bottom = 24
	_currency_hud_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_currency_hud_layer.add_child(_currency_hud_label)

func _update_currency_hud(force: bool = false) -> void:
	if _currency_hud_label == null:
		return
	if Game == null:
		if force:
			_currency_hud_label.text = "Gold: -\nSoul Essence: -"
		return
	var gold: int = Game.run_gold
	var essence: int = Game.soul_essence
	if not force and gold == _last_gold_display and essence == _last_essence_display:
		return
	_last_gold_display = gold
	_last_essence_display = essence
	_currency_hud_label.text = "Gold: %d\nSoul Essence: %d" % [gold, essence]

func _apply_merchant_discount(base_price: int) -> int:
	if Game == null:
		return max(1, base_price)
	var discount_level: int = Game.get_meta_unlock_level("merchant_discount")
	var factor: float = clampf(1.0 - float(discount_level) * 0.10, 0.5, 1.0)
	return max(1, int(round(float(base_price) * factor)))

func _get_effective_quest_spawn_chance() -> float:
	if Game == null:
		return quest_spawn_chance
	var bonus_level: int = Game.get_meta_unlock_level("quest_boost")
	return clamp(quest_spawn_chance + float(bonus_level) * 0.05, 0.0, 0.95)

func _start_dungeon_run_if_needed() -> void:
	if Game == null:
		return
	if current_floor != 1:
		return
	if bool(Game.flags.get("dungeon_run_active", false)):
		return
	var start_gold := run_start_gold + Game.get_meta_unlock_level("starting_gold") * 25
	Game.reset_run_state(start_gold)
	Game.flags["dungeon_run_active"] = true
	_enqueue_message("Run started. Gold: %d" % Game.run_gold)

func _finish_dungeon_run() -> void:
	if Game == null:
		return
	_close_merchant_shop()
	Game.flags["dungeon_run_active"] = false
	Game.reset_run_state(0)

func _award_battle_rewards(winner_team_index: int, interaction: String) -> void:
	if winner_team_index != 0:
		return
	if Game == null:
		return
	var gold_reward: int = 0
	if interaction == "elite_pack":
		gold_reward = elite_battle_gold
	elif interaction == "mimic_pack":
		gold_reward = mimic_battle_gold
	elif interaction == "dungeon_boss":
		gold_reward = boss_battle_gold
	elif interaction == "":
		gold_reward = wild_battle_gold
	if gold_reward > 0:
		Game.add_run_gold(gold_reward)
		if interaction != "":
			_enqueue_message("Gold +%d" % gold_reward)

func _handle_key_interaction(npc) -> bool:
	# Mark key as found and remove from map
	_key_found_this_floor = true
	_set_npc_active(npc, false, Vector2i.ZERO)
	
	_enqueue_message("You found the key! The stairs are now accessible.")
	_log_dungeon("[Dungeon] key found and picked up")
	
	return true

func _heal_party_percent(ratio: float) -> int:
	var healed := 0
	for monster in Game.party:
		if monster == null:
			continue
		if not (monster is MTMonsterInstance):
			continue
		var m := monster as MTMonsterInstance
		var max_hp := m.get_max_hp()
		if max_hp <= 0:
			continue
		var amount := int(ceil(max_hp * ratio))
		if amount <= 0:
			continue
		var before := m.hp
		m.hp = clamp(m.hp + amount, 0, max_hp)
		if m.hp > before:
			healed += 1
	return healed

func _restore_party_energy_percent(ratio: float) -> int:
	var restored := 0
	for monster in Game.party:
		if monster == null:
			continue
		if not (monster is MTMonsterInstance):
			continue
		var m := monster as MTMonsterInstance
		if not m.is_alive():
			continue
		var max_energy := m.get_max_energy()
		if max_energy <= 0:
			continue
		var amount := int(ceil(max_energy * ratio))
		if amount <= 0:
			continue
		var before := m.energy
		m.energy = clamp(m.energy + amount, 0, max_energy)
		if m.energy > before:
			restored += 1
	return restored

func _get_farthest_room(origin: Vector2i) -> Rect2i:
	if _room_rects.is_empty():
		return Rect2i(0, 0, 1, 1)
	var best_room := _room_rects[0]
	var best_dist := -1
	for room in _room_rects:
		var center := _room_center(room)
		var dist: int = abs(center.x - origin.x) + abs(center.y - origin.y)
		if dist > best_dist:
			best_dist = dist
			best_room = room
	return best_room

func _find_nearby_floor_cell(origin: Vector2i, max_dist: int) -> Vector2i:
	var best_cell := origin
	var best_dist := 999999
	for cell in _floor_cells:
		if cell == origin:
			continue
		var dist: int = abs(cell.x - origin.x) + abs(cell.y - origin.y)
		if dist <= 0 or dist > max_dist:
			continue
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
	if best_dist != 999999:
		return best_cell
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var candidate: Vector2i = origin + dir
		if _floor_cells.has(candidate):
			return candidate
	return origin

#  Habitat data 

func _get_habitat_monster_paths() -> Array[String]:
	match habitat.to_lower():
		"forest":
			return [
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/aquafin/aquafin.tres"
			]
		"ruins":
			return [
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			]
		"swamp":
			return [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/aquafin/aquafin.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			]
		_:
			return [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/stoneback/stoneback.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			]

func _get_habitat_weights() -> Array[int]:
	match habitat.to_lower():
		"forest":  return [10, 5, 2, 8, 6]
		"ruins":   return [6,  4, 3, 8, 7, 5]
		"swamp":   return [10, 4, 2, 8, 7, 5]
		_:         return [8,  6, 3, 7, 5]

#  Player reset 

func _reset_player_position() -> void:
	if _player == null:
		return
	_player.global_position = _cell_to_world(_player_spawn_cell)
	_sync_cells()
