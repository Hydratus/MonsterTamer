extends "res://core/world/overworld.gd"

const EncounterEntryClass = preload("res://core/world/encounter_entry.gd")
const NPCDataClass = preload("res://core/world/npc_data.gd")
const NPCMonsterEntryClass = preload("res://core/world/npc_monster_entry.gd")
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")
const DungeonLayoutHelperClass = preload("res://core/world/dungeon_layout_helper.gd")
const DungeonShopUIHelperClass = preload("res://core/world/dungeon_shop_ui_helper.gd")
const DungeonRunHelperClass = preload("res://core/world/dungeon_run_helper.gd")
const DungeonNPCSpawnHelperClass = preload("res://core/world/dungeon_npc_spawn_helper.gd")
const DungeonQuestHelperClass = preload("res://core/world/dungeon_quest_helper.gd")
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

func _touch_split_state_keepalive() -> void:
	# Keep strict diagnostics aware of fields that are now manipulated by helpers.
	if false:
		print(
			_dynamic_npcs,
			_room_cells_lookup,
			_corridor_cells_lookup,
			_has_quest_this_floor,
			_quest_item_npc,
			_merchant_shop_index,
			_event_room_index,
			_floor_goal_state,
			_merchant_shop_layer,
			_merchant_shop_panel,
			_merchant_shop_title,
			_merchant_shop_list,
			_merchant_shop_status,
			_merchant_shop_close_button,
			_merchant_shop_buttons,
			_currency_hud_layer,
			_currency_hud_label,
			_last_gold_display,
			_last_essence_display
		)

func _ready() -> void:
	_log_dungeon("[Dungeon] _ready() floor=%d  seed=%d" % [current_floor, generation_seed])
	_touch_split_state_keepalive()
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
		_enqueue_message(tr("Elite pack defeated. The path to the stairs is now open."))
		if Game != null:
			Game.add_soul_essence(elite_battle_soul_essence)
			_enqueue_message(tr("Soul Essence +%d") % elite_battle_soul_essence)
	
	if winner_team_index == 0 and finished_interaction == "dungeon_quest_thief":
		_active_quest["completed"] = true
		if _quest_npc != null:
			_set_npc_active(_quest_npc, false, Vector2i.ZERO)
		_enqueue_message(tr("Quest Complete: You defeated the thief!"))
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
				_enqueue_message(tr("Hunt complete. Return to the hunter for your reward."))
				_log_dungeon("[Dungeon] quest hunt ready_to_turn_in kills=%d" % killed)
	
	if winner_team_index == 1:
		_boss_battle_active = false
		_pending_return_to_hub = true
		_enqueue_message(tr("You were defeated. Returning to the city."))
		return
	if _boss_battle_active and winner_team_index == 0:
		_boss_battle_active = false
		_pending_return_to_hub = true
		if Game != null:
			Game.add_soul_essence(boss_battle_soul_essence)
			_enqueue_message(tr("Soul Essence +%d") % boss_battle_soul_essence)
		_enqueue_message(tr("Boss defeated! Returning to the city."))

#  Floor advancement 

func _advance_floor() -> void:
	if current_floor >= floor_count:
		return
	current_floor += 1
	_layout_seed = 0  # fresh layout per floor
	_apply_floor_rules(true)
	_enqueue_message(tr("Floor %d / %d") % [current_floor, floor_count])

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
	DungeonNPCSpawnHelperClass.spawn_floor_npcs(self)

func _spawn_event_object(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_event_object(self, reserved)

func _spawn_loose_items(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_loose_items(self, reserved)

func _spawn_secret_vault(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_secret_vault(self, reserved)

func _spawn_elite_room_npc(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_elite_room_npc(self, reserved)

func _spawn_mimic_npc(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_mimic_npc(self, reserved)

func _spawn_puzzle_switches(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_puzzle_switches(self, reserved)

func _spawn_key_npc(reserved: Dictionary) -> void:
	DungeonNPCSpawnHelperClass.spawn_key_npc(self, reserved)

func _pick_normal_room_index() -> int:
	return DungeonNPCSpawnHelperClass.pick_normal_room_index(self)

func _pick_cell_in_room(room_index: int, reserved: Dictionary) -> Vector2i:
	return DungeonNPCSpawnHelperClass.pick_cell_in_room(self, room_index, reserved)

func _spawn_dynamic_npc(cell: Vector2i, npc_data: MTNPCData) -> void:
	DungeonNPCSpawnHelperClass.spawn_dynamic_npc(self, cell, npc_data)

func _clear_dynamic_npcs() -> void:
	DungeonNPCSpawnHelperClass.clear_dynamic_npcs(self)

func _create_battle_npc_data(index: int) -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_battle_npc_data(self, index)

func _create_item_npc_data(index: int) -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_item_npc_data(self, index)

func _create_elite_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_elite_npc_data(self)

func _create_mimic_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_mimic_npc_data(self)

func _create_puzzle_switch_npc_data(switch_number: int) -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_puzzle_switch_npc_data(switch_number)

func _create_key_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_key_npc_data()

func _create_healing_spring_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_healing_spring_npc_data()

func _create_gold_stash_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_gold_stash_npc_data()

func _create_essence_cache_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_essence_cache_npc_data()

func _create_status_trap_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_status_trap_npc_data()

func _create_merchant_cache_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_merchant_cache_npc_data()

func _create_monster_egg_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_monster_egg_npc_data()

func _create_cursed_altar_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_cursed_altar_npc_data()

func _create_loose_item_npc_data(item_id: String) -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_loose_item_npc_data(item_id)

func _create_secret_vault_npc_data() -> MTNPCData:
	return DungeonNPCSpawnHelperClass.create_secret_vault_npc_data()



func _pick_monster_for_habitat() -> MTMonsterData:
	return DungeonNPCSpawnHelperClass.pick_monster_for_habitat(self)

func _pick_free_floor_cell(reserved: Dictionary) -> Vector2i:
	return DungeonNPCSpawnHelperClass.pick_free_floor_cell(self, reserved)

func _is_safe_npc_spawn_cell(cell: Vector2i) -> bool:
	return DungeonNPCSpawnHelperClass.is_safe_npc_spawn_cell(self, cell)

func _is_chokepoint_cell(cell: Vector2i) -> bool:
	return DungeonNPCSpawnHelperClass.is_chokepoint_cell(self, cell)

#  Layout generation 

func _generate_floor_layout() -> void:
	DungeonLayoutHelperClass.generate_floor_layout(self)

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
	return DungeonLayoutHelperClass.room_intersects_existing(self, candidate)

func _carve_room(room: Rect2i, carved: Dictionary) -> void:
	DungeonLayoutHelperClass.carve_room(self, room, carved)

func _carve_corridor(start: Vector2i, target: Vector2i, carved: Dictionary) -> void:
	DungeonLayoutHelperClass.carve_corridor(self, start, target, carved)

func _room_center(room: Rect2i) -> Vector2i:
	return DungeonLayoutHelperClass.room_center(room)

func _build_room_index_lookup() -> void:
	DungeonLayoutHelperClass.build_room_index_lookup(self)

func _assign_room_roles() -> void:
	DungeonLayoutHelperClass.assign_room_roles(self)

func _assign_floor_goals() -> void:
	DungeonLayoutHelperClass.assign_floor_goals(self)

func _get_farthest_room_index(origin_index: int) -> int:
	return DungeonLayoutHelperClass.get_farthest_room_index(self, origin_index)

func _room_distance(a_index: int, b_index: int) -> int:
	return DungeonLayoutHelperClass.room_distance(self, a_index, b_index)

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
		_enqueue_message(tr("An elite presence fills this room."))
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
	_enqueue_message(tr("You picked up %s!") % item_name)
	return true

func _handle_healing_spring(npc) -> bool:
	var healed := _heal_party_percent(0.40)
	var energized := _restore_party_energy_percent(0.40)
	_set_npc_active(npc, false, Vector2i.ZERO)
	_enqueue_message(tr("Healing Spring: Your team is refreshed. (%d healed, %d recharged)") % [healed, energized])
	_log_dungeon("[Dungeon] healing spring used healed=%d energized=%d" % [healed, energized])
	return true

func _handle_gold_stash(npc) -> bool:
	var amount := 10 + current_floor * 3
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_run_gold(amount)
	_enqueue_message(tr("You found a gold stash! Gold +%d") % amount)
	_log_dungeon("[Dungeon] gold stash amount=%d" % amount)
	return true

func _handle_essence_cache(npc) -> bool:
	var amount := 1 + int(current_floor / 10.0)
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_soul_essence(amount)
	_enqueue_message(tr("Soul Essence Cache: You absorb the power. Soul Essence +%d") % amount)
	_log_dungeon("[Dungeon] essence cache amount=%d" % amount)
	return true

func _handle_status_trap(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game == null or Game.party.is_empty():
		_enqueue_message(tr("A trap springs! But there is nothing to harm."))
		return true
	for monster in Game.party:
		if monster == null:
			continue
		var m := monster as MTMonsterInstance
		if m == null or m.hp <= 0:
			continue
		var damage := int(ceil(m.get_max_hp() * 0.25))
		m.hp = max(1, m.hp - damage)
		var mname := m.data.name if m.data != null else tr("Monster")
		_enqueue_message(tr("It's a trap! %s lost %d HP!") % [mname, damage])
		_log_dungeon("[Dungeon] status trap triggered hp_lost=%d" % damage)
		break
	return true

func _handle_monster_egg(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game != null:
		Game.add_item("monster_egg", 1)
	_enqueue_message(tr("You found a Monster Egg! It will hatch on the next floor."))
	_log_dungeon("[Dungeon] monster egg picked up")
	return true

func _handle_cursed_altar(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if Game == null:
		_enqueue_message(tr("The altar pulses with dark energy, but nothing happens."))
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
	_enqueue_message(tr("Cursed Altar: Your team suffers %d total damage... Soul Essence +1, Gold +%d.") % [total_lost, gold_gain])
	_log_dungeon("[Dungeon] cursed altar used hp_lost=%d gold=%d" % [total_lost, gold_gain])
	return true

func _handle_secret_vault(npc) -> bool:
	if Game == null or Game.get_item_count("secret_key") <= 0:
		_enqueue_message(tr("Locked. You need a Secret Key to open this vault."))
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
	_enqueue_message(tr("Secret Vault opened! Found items, Gold +%d, and Soul Essence +2!") % gold)
	_log_dungeon("[Dungeon] secret vault opened gold=%d" % gold)
	return true

func _check_monster_egg_hatch() -> void:
	if Game == null or Game.get_item_count("monster_egg") <= 0:
		return
	if Game.party.size() >= 6:
		_enqueue_message(tr("Your egg is ready to hatch, but your team is full!"))
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
	_enqueue_message(tr("Your Monster Egg hatched! %s joined your team!") % monster_data.name)
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
			return tr("A powerful presence blocks your descent. Defeat the elite room first.")
		FLOOR_GOAL_TYPE.KEY:
			return tr("The stairs are sealed. You must find the key on this floor.")
		FLOOR_GOAL_TYPE.PUZZLE:
			return tr("The stairs are sealed. You must activate all 3 switches (%d/%d).") % [_switches_activated, _switches_total]
		_:
			return tr("You cannot proceed.")

func _handle_puzzle_switch_interaction(npc, interaction: String) -> bool:
	# Parse switch number from interaction_id "dungeon_switch_1" -> 1
	var parts := interaction.split("_")
	if parts.size() < 3:
		return false
	var switch_num: int = int(parts[-1])
	
	# Mark this switch as activated and remove NPC from map
	_switches_activated += 1
	_set_npc_active(npc, false, Vector2i.ZERO)
	
	var progress_msg := tr("Switch %d activated! (%d/%d)") % [switch_num, _switches_activated, _switches_total]
	_enqueue_message(progress_msg)
	_log_dungeon("[Dungeon] puzzle switch %d activated progress=%d/%d" % [switch_num, _switches_activated, _switches_total])
	
	# Check if all switches are activated
	if _switches_activated >= _switches_total:
		_enqueue_message(tr("All switches activated! The stairs are now open."))
		_log_dungeon("[Dungeon] puzzle completed all switches activated")
	
	return true

#  Quest System 

func _maybe_spawn_quest_npc() -> void:
	DungeonQuestHelperClass.maybe_spawn_quest_npc(self)

func _create_quest_npc_data(quest_type: int) -> MTNPCData:
	return DungeonQuestHelperClass.create_quest_npc_data(self, quest_type)

func _pick_or_create_random_item() -> String:
	return DungeonQuestHelperClass.pick_or_create_random_item(self)

func _spawn_delivery_quest_item(quest_cell: Vector2i) -> void:
	DungeonQuestHelperClass.spawn_delivery_quest_item(self, quest_cell)

func _create_delivery_quest_item_npc_data() -> MTNPCData:
	return DungeonQuestHelperClass.create_delivery_quest_item_npc_data()

func _handle_quest_delivery(npc) -> bool:
	return DungeonQuestHelperClass.handle_quest_delivery(self, npc)

func _handle_quest_hunt(_npc) -> bool:
	return DungeonQuestHelperClass.handle_quest_hunt(self, _npc)

func _handle_quest_delivery_item(npc) -> bool:
	return DungeonQuestHelperClass.handle_quest_delivery_item(self, npc)

func _handle_quest_thief(_npc) -> bool:
	return DungeonQuestHelperClass.handle_quest_thief(self, _npc)

func _award_quest_rewards() -> void:
	DungeonQuestHelperClass.award_quest_rewards(self)

func _reset_floor_quest_state() -> void:
	DungeonQuestHelperClass.reset_floor_quest_state(self)

func _handle_merchant_shop(_npc) -> bool:
	if merchant_shop_items.is_empty():
		_enqueue_message(tr("Merchant: I'm out of stock for this run."))
		return true
	_open_merchant_shop()
	return true

func _create_merchant_shop_ui() -> void:
	DungeonShopUIHelperClass.create_merchant_shop_ui(self)

func _rebuild_merchant_shop_buttons() -> void:
	DungeonShopUIHelperClass.rebuild_merchant_shop_buttons(self, ITEM_DB_CLASS)

func _open_merchant_shop() -> void:
	DungeonShopUIHelperClass.open_merchant_shop(self, ITEM_DB_CLASS)

func _close_merchant_shop() -> void:
	DungeonShopUIHelperClass.close_merchant_shop(self)

func _on_merchant_buy_pressed(index: int) -> void:
	DungeonShopUIHelperClass.on_merchant_buy_pressed(self, index, ITEM_DB_CLASS)

func _create_currency_hud() -> void:
	DungeonShopUIHelperClass.create_currency_hud(self)

func _update_currency_hud(force: bool = false) -> void:
	DungeonShopUIHelperClass.update_currency_hud(self, force)

func _apply_merchant_discount(base_price: int) -> int:
	return DungeonShopUIHelperClass.apply_merchant_discount(self, base_price)

func _get_effective_quest_spawn_chance() -> float:
	return DungeonRunHelperClass.get_effective_quest_spawn_chance(self)

func _start_dungeon_run_if_needed() -> void:
	DungeonRunHelperClass.start_dungeon_run_if_needed(self)

func _finish_dungeon_run() -> void:
	DungeonRunHelperClass.finish_dungeon_run(self)

func _award_battle_rewards(winner_team_index: int, interaction: String) -> void:
	DungeonRunHelperClass.award_battle_rewards(self, winner_team_index, interaction)

func _handle_key_interaction(npc) -> bool:
	# Mark key as found and remove from map
	_key_found_this_floor = true
	_set_npc_active(npc, false, Vector2i.ZERO)
	
	_enqueue_message(tr("You found the key! The stairs are now accessible."))
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
