extends "res://core/world/overworld.gd"

const EncounterEntryClass = preload("res://core/world/encounter_entry.gd")
const NPCDataClass = preload("res://core/world/npc_data.gd")
const NPCMonsterEntryClass = preload("res://core/world/npc_monster_entry.gd")
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")
const DungeonLayoutHelperClass = preload("res://core/world/dungeon_layout_helper.gd")
const DungeonShopUIHelperClass = preload("res://core/world/dungeon_shop_ui_helper.gd")
const DungeonPortalUIHelperClass = preload("res://core/world/dungeon_portal_ui_helper.gd")
const DungeonRunHelperClass = preload("res://core/world/dungeon_run_helper.gd")
const DungeonNPCSpawnHelperClass = preload("res://core/world/dungeon_npc_spawn_helper.gd")
const DungeonQuestHelperClass = preload("res://core/world/dungeon_quest_helper.gd")
const BalanceConstants = preload("res://core/systems/game_balance_constants.gd")
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
@export var habitat: String = "gloomrot_catacombs"
@export var floor_count: int = 50
@export var current_floor: int = 1
@export var base_encounter_chance: float = 0.05
var encounter_chance: float = 0.0
var encounter_table: Array[MTEncounterEntry] = []
@export var run_total_floors: int = 50
@export var run_segment_min_len: int = 7
@export var run_segment_max_len: int = 15
@export var run_biome_pool: Array[String] = [
	"gloomrot_catacombs",
	"thornfang_warrens",
	"sunforge_basilica",
	"skytide_reservoir",
	"emberfault_chasm",
	"stargrave_observatory",
	"ironhowl_bastion",
	"echo_vault"
]

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
	"lesser_undead_binding_rune",
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
	"lesser_undead_binding_rune",
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
var _portal_layer
var _portal_container
var _npc_spawn_positions: Dictionary = {}
var _disabled_static_npcs: Array = []
var _dynamic_npcs: Array = []
var _floor_cells: Array[Vector2i] = []
var _room_rects: Array[Rect2i] = []
var _player_spawn_cell: Vector2i = Vector2i.ZERO
var _pending_floor_advance := false
var _pending_return_to_hub := false
var _boss_battle_active := false
var _pending_biome_selection := false
var _selected_next_biome: String = ""
var _biome_portal_npcs: Array = []
var _room_cells_lookup: Dictionary = {}
var _gauntlet_fight_queue: Array[Dictionary] = []
var _current_gauntlet_fight_index: int = 0
var _gauntlet_active := false
var _final_boss_phase_active := false
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
var _last_threat_points_display: int = -1
var _last_threat_tier_display: int = -1
var _last_threat_seconds_display: int = -1
var _encounter_segments: Array[Dictionary] = []
var _active_encounter_segment_start: int = -1
var _active_route_segment_start: int = -1
var _active_route_segment_end: int = -1
var _biome_banner_layer: CanvasLayer
var _biome_banner_label: Label
var _biome_banner_tween: Tween
var _run_exploration_seconds: float = 0.0
var _run_time_threat_points: int = 0
var _run_wild_battles_won: int = 0
var _run_special_battles_won: int = 0
var _run_threat_points: int = 0
var _run_threat_tier: int = 0

#  Life-cycle 

func _log_dungeon(message: String) -> void:
	_log_debug(message)

func _has_game() -> bool:
	return _get_game() != null

func _get_game():
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Game")

func _get_route_segment_for_floor(target_floor: int) -> Dictionary:
	if not _has_game():
		return {}
	var game = _get_game()
	if game == null:
		return {}
	if not game.has_method("get_dungeon_segment_for_floor"):
		return {}
	return game.get_dungeon_segment_for_floor(target_floor)

func _sync_active_route_segment(show_banner: bool = false) -> void:
	var segment: Dictionary = _get_route_segment_for_floor(current_floor)
	if segment.is_empty():
		_active_route_segment_start = 1
		_active_route_segment_end = floor_count
		return
	var previous_start := _active_route_segment_start
	var next_start: int = int(segment.get("start_floor", 1))
	var next_end: int = int(segment.get("end_floor", floor_count))
	var next_biome := str(segment.get("biome", habitat))
	_active_route_segment_start = next_start
	_active_route_segment_end = next_end
	habitat = next_biome
	if show_banner and previous_start != -1 and previous_start != next_start:
		_show_biome_transition_banner(next_biome)


func _create_biome_transition_banner() -> void:
	_biome_banner_layer = CanvasLayer.new()
	_biome_banner_layer.layer = 13
	add_child(_biome_banner_layer)
	_biome_banner_label = Label.new()
	_biome_banner_label.anchor_left = 0.5
	_biome_banner_label.anchor_top = 0.0
	_biome_banner_label.anchor_right = 0.5
	_biome_banner_label.anchor_bottom = 0.0
	_biome_banner_label.offset_left = -210
	_biome_banner_label.offset_top = 18
	_biome_banner_label.offset_right = 210
	_biome_banner_label.offset_bottom = 56
	_biome_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_biome_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_biome_banner_label.visible = false
	_biome_banner_label.modulate = Color(1, 1, 1, 0)
	_biome_banner_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	_biome_banner_layer.add_child(_biome_banner_label)

func _show_biome_transition_banner(biome_name: String) -> void:
	if _biome_banner_label == null:
		return
	if _biome_banner_tween != null and _biome_banner_tween.is_valid():
		_biome_banner_tween.kill()
	_biome_banner_label.text = tr("Entering Biome: %s") % _get_habitat_display_name(biome_name)
	_biome_banner_label.visible = true
	_biome_banner_label.modulate = Color(1, 1, 1, 0)
	_biome_banner_tween = create_tween()
	_biome_banner_tween.tween_property(_biome_banner_label, "modulate", Color(1, 1, 1, 1), 0.2)
	_biome_banner_tween.tween_interval(1.6)
	_biome_banner_tween.tween_property(_biome_banner_label, "modulate", Color(1, 1, 1, 0), 0.3)
	_biome_banner_tween.finished.connect(func():
		if _biome_banner_label != null:
			_biome_banner_label.visible = false
	)

func _is_current_floor_boss_floor() -> bool:
	# Dynamic boss system: segment ends (<=49) plus floor 50 endgame.
	var game = _get_game()
	if game != null and game.boss_system_enabled:
		return game.is_dungeon_boss_floor(current_floor)
	# Legacy system
	return current_floor >= _active_route_segment_end

func _is_final_floor() -> bool:
	return current_floor >= floor_count

func _get_habitat_display_name(habitat_key: String) -> String:
	match habitat_key.to_lower():
		"gloomrot_catacombs":
			return "Gloomrot Catacombs"
		"thornfang_warrens":
			return "Thornfang Warrens"
		"sunforge_basilica":
			return "Sunforge Basilica"
		"skytide_reservoir":
			return "Skytide Reservoir"
		"emberfault_chasm":
			return "Emberfault Chasm"
		"stargrave_observatory":
			return "Stargrave Observatory"
		"ironhowl_bastion":
			return "Ironhowl Bastion"
		"echo_vault":
			return "Echo Vault"
		_:
			return habitat_key.capitalize()

func get_habitat_display_name(habitat_key: String) -> String:
	return _get_habitat_display_name(habitat_key)

func get_dungeon_hud_biome_text() -> String:
	return _get_habitat_display_name(habitat)

func get_dungeon_hud_floor_text() -> String:
	return "%d / %d" % [current_floor, floor_count]

func get_dungeon_hud_threat_time_text() -> String:
	var total_seconds: int = max(0, int(floor(_run_exploration_seconds)))
	var minutes: int = int(floor(float(total_seconds) / 60.0))
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _reset_run_threat_state() -> void:
	_run_exploration_seconds = 0.0
	_run_time_threat_points = 0
	_run_wild_battles_won = 0
	_run_special_battles_won = 0
	_run_threat_points = 0
	_run_threat_tier = 0

func _refresh_run_threat_state() -> void:
	var previous_tier := _run_threat_tier
	_run_threat_points = _run_time_threat_points
	_run_threat_points += _run_wild_battles_won * BalanceConstants.THREAT_WILD_BATTLE_POINTS
	_run_threat_points += _run_special_battles_won * BalanceConstants.THREAT_SPECIAL_BATTLE_POINTS
	_run_threat_tier = _get_threat_tier_for_points(_run_threat_points)
	if previous_tier != _run_threat_tier:
		_log_dungeon("[Dungeon] threat tier %d -> %d points=%d" % [previous_tier, _run_threat_tier, _run_threat_points])

func _get_threat_tier_for_points(points: int) -> int:
	for raw_rule in BalanceConstants.THREAT_TIER_RULES:
		var rule: Dictionary = raw_rule if raw_rule is Dictionary else {}
		var min_points: int = int(rule.get("min_points", 0))
		var max_points: int = int(rule.get("max_points", 999999))
		if points >= min_points and points <= max_points:
			return int(rule.get("tier", 0))
	if BalanceConstants.THREAT_TIER_RULES.is_empty():
		return 0
	var last_rule: Dictionary = BalanceConstants.THREAT_TIER_RULES[BalanceConstants.THREAT_TIER_RULES.size() - 1]
	return int(last_rule.get("tier", 0))

func _get_current_threat_rule() -> Dictionary:
	for raw_rule in BalanceConstants.THREAT_TIER_RULES:
		var rule: Dictionary = raw_rule if raw_rule is Dictionary else {}
		if int(rule.get("tier", 0)) == _run_threat_tier:
			return rule
	return {}

func _get_current_threat_level_bonus() -> int:
	var rule: Dictionary = _get_current_threat_rule()
	var base_bonus: int = int(rule.get("level_bonus", 0))
	if _run_threat_tier < 5:
		return base_bonus
	var tier5_min: int = _get_threat_tier_min_points(5, 110)
	var overflow: int = max(0, _run_threat_points - tier5_min)
	var overflow_bonus: int = int(floor(float(overflow) / float(max(1, BalanceConstants.THREAT_TIER5_OVERFLOW_STEP))))
	return base_bonus + overflow_bonus

func _get_threat_tier_min_points(target_tier: int, fallback: int) -> int:
	for raw_rule in BalanceConstants.THREAT_TIER_RULES:
		var r: Dictionary = raw_rule if raw_rule is Dictionary else {}
		if int(r.get("tier", -1)) == target_tier:
			return int(r.get("min_points", fallback))
	return fallback

func _get_current_threat_elite_budget_multiplier() -> float:
	var rule: Dictionary = _get_current_threat_rule()
	var base_multiplier: float = max(0.1, float(rule.get("elite_budget_multiplier", 1.0)))
	if _run_threat_tier < 5:
		return base_multiplier
	var tier5_min: int = _get_threat_tier_min_points(5, 110)
	var overflow: int = max(0, _run_threat_points - tier5_min)
	var overflow_step: int = max(1, int(BalanceConstants.THREAT_TIER5_ELITE_OVERFLOW_STEP))
	var overflow_steps: int = int(floor(float(overflow) / float(overflow_step)))
	var overflow_bonus: float = min(
		float(BalanceConstants.THREAT_TIER5_ELITE_OVERFLOW_CAP),
		float(overflow_steps) * float(BalanceConstants.THREAT_TIER5_ELITE_OVERFLOW_BONUS)
	)
	return base_multiplier + overflow_bonus

func _get_current_threat_encounter_bonus() -> float:
	var rule: Dictionary = _get_current_threat_rule()
	return max(0.0, float(rule.get("encounter_chance_bonus", 0.0)))

func _update_threat_time(delta: float) -> void:
	if delta <= 0.0 or _in_battle:
		return
	_run_exploration_seconds += delta
	var per_point: float = max(1.0, float(BalanceConstants.THREAT_TIME_SECONDS_PER_POINT))
	var next_time_points: int = int(floor(_run_exploration_seconds / per_point))
	if next_time_points != _run_time_threat_points:
		_run_time_threat_points = next_time_points
		_refresh_run_threat_state()

func _register_battle_threat(winner_team_index: int, finished_interaction: String) -> void:
	if winner_team_index != 0:
		return
	if finished_interaction == "":
		_run_wild_battles_won += 1
	else:
		_run_special_battles_won += 1
	_refresh_run_threat_state()

func _apply_biome_boss_threat_reset() -> void:
	if _run_threat_points <= 0:
		return
	var reset_factor: float = clamp(float(BalanceConstants.THREAT_BIOME_BOSS_RESET_FACTOR), 0.0, 1.0)
	var before_points := _run_threat_points
	_run_threat_points = int(floor(float(_run_threat_points) * reset_factor))
	_run_time_threat_points = min(_run_time_threat_points, _run_threat_points)
	var encounter_points: int = _run_wild_battles_won * BalanceConstants.THREAT_WILD_BATTLE_POINTS
	encounter_points += _run_special_battles_won * BalanceConstants.THREAT_SPECIAL_BATTLE_POINTS
	if encounter_points > _run_threat_points:
		var remaining_points: int = _run_threat_points - _run_time_threat_points
		if remaining_points < 0:
			remaining_points = 0
		var special_points: int = max(1, BalanceConstants.THREAT_SPECIAL_BATTLE_POINTS)
		var weighted_total: int = max(1, _run_wild_battles_won + (_run_special_battles_won * special_points))
		var wild_share: float = float(_run_wild_battles_won) / float(weighted_total)
		var special_share: float = float(_run_special_battles_won * special_points) / float(weighted_total)
		_run_wild_battles_won = max(0, int(floor(float(remaining_points) * wild_share)))
		_run_special_battles_won = max(0, int(floor(float(remaining_points) * special_share / max(1.0, float(BalanceConstants.THREAT_SPECIAL_BATTLE_POINTS)))))
	_refresh_run_threat_state()
	_log_dungeon("[Dungeon] biome boss threat reset %d -> %d" % [before_points, _run_threat_points])

func _has_npc_data(npc) -> bool:
	return npc != null and npc.npc_data != null

func _touch_split_state_keepalive() -> void:
	# Keep strict diagnostics aware of fields that are now manipulated by helpers.
	if false:
		var _keepalive_refs := [
			_dynamic_npcs,
			_room_cells_lookup,
			_corridor_cells_lookup,
			_has_quest_this_floor,
			_quest_item_npc,
			_merchant_shop_index,
			_event_room_index,
			_floor_goal_state,
			_portal_layer,
			_portal_container,
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
			_last_essence_display,
			_last_threat_points_display,
			_last_threat_tier_display,
			_last_threat_seconds_display
		]
		_keepalive_refs.clear()

func _ready() -> void:
	_log_dungeon("[Dungeon] _ready() floor=%d  seed=%d" % [current_floor, generation_seed])
	_touch_split_state_keepalive()
	super._ready()
	_validate_dungeon_item_pools()
	_create_merchant_shop_ui()
	_create_portal_ui()
	_create_currency_hud()
	_create_biome_transition_banner()
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
	_update_threat_time(delta)
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
		run_total_floors = floor_count
		need_regen = true
	if payload.has("run_total_floors"):
		run_total_floors = int(payload["run_total_floors"])
		floor_count = run_total_floors
		need_regen = true
	if payload.has("run_segment_min_len"):
		run_segment_min_len = int(payload["run_segment_min_len"])
	if payload.has("run_segment_max_len"):
		run_segment_max_len = int(payload["run_segment_max_len"])
	if payload.has("run_biome_pool") and payload["run_biome_pool"] is Array:
		var raw_biome_pool: Array = payload["run_biome_pool"]
		var normalized_biome_pool: Array[String] = []
		for raw_biome in raw_biome_pool:
			var biome := str(raw_biome).strip_edges().to_lower()
			if biome == "" or normalized_biome_pool.has(biome):
				continue
			normalized_biome_pool.append(biome)
		if not normalized_biome_pool.is_empty():
			run_biome_pool = normalized_biome_pool
	if payload.has("habitat"):
		habitat = str(payload["habitat"])
		need_regen = true
	if payload.has("base_encounter_chance"):
		base_encounter_chance = clamp(float(payload["base_encounter_chance"]), 0.0, 1.0)
		need_regen = true
	if payload.has("seed"):
		generation_seed = int(payload["seed"])
		_layout_seed = 0
		need_regen = true
	_sync_active_route_segment()
	# Only regenerate when the floor is still empty (first-time entry when _ready
	# already ran) or when the payload actually requests a different setup.
	if _floor_cells.is_empty() or need_regen:
		_apply_floor_rules(false)
	_update_currency_hud(true)

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
	if not _has_npc_data(npc):
		return false
	var interaction: String = str(npc.npc_data.interaction_id)
	if interaction == "dungeon_stairs" and not _is_current_floor_boss_floor() and current_floor < floor_count:
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
	if interaction == "dungeon_boss" and _is_current_floor_boss_floor():
		_boss_battle_active = true
		return false
	if interaction.begins_with("dungeon_portal_choice:"):
		return _handle_biome_portal_interaction(npc, interaction)
	
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
	if interaction == "dungeon_boss_floor_shop":
		return _handle_boss_floor_shop(npc)
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
	_register_battle_threat(winner_team_index, finished_interaction)
	_award_battle_rewards(winner_team_index, finished_interaction)
	if winner_team_index == 0 and finished_interaction == "elite_pack":
		_elite_cleared_this_floor = true
		_enqueue_message(tr("Elite pack defeated. The path to the stairs is now open."))
		if _has_game():
			var game = _get_game()
			game.add_soul_essence(elite_battle_soul_essence)
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
		_apply_biome_boss_threat_reset()
		var game = _get_game()
		if game != null:
			game.add_soul_essence(boss_battle_soul_essence)
			_enqueue_message(tr("Soul Essence +%d") % boss_battle_soul_essence)

			# Track defeated biome bosses (segment end floors up to 49).
			if game.boss_system_enabled and current_floor <= 49 and game.is_dungeon_boss_floor(current_floor):
				_track_defeated_boss()

		# Floor 50 hosts both gauntlet and final boss, sequentially.
		if game != null and game.is_gauntlet_floor(current_floor):
			if _final_boss_phase_active:
				_final_boss_phase_active = false
				_pending_return_to_hub = true
				_enqueue_message(tr("Final boss defeated! The run is complete!"))
				return

			if _gauntlet_active:
				_current_gauntlet_fight_index += 1
				if _current_gauntlet_fight_index < _gauntlet_fight_queue.size():
					_enqueue_message(tr("Defeated! Preparing next gauntlet opponent..."))
					call_deferred("_trigger_next_gauntlet_encounter")
				else:
					_gauntlet_active = false
					_activate_final_boss_phase()
				return

			_activate_final_boss_phase()
			return

		if _is_final_floor() or (game != null and game.is_final_boss_floor(current_floor)):
			_pending_return_to_hub = true
			_enqueue_message(tr("Boss defeated! The run is complete!"))
			return

		if game != null and game.boss_system_enabled and current_floor < 49 and game.is_dungeon_boss_floor(current_floor):
			var biome_options = game.get_next_boss_biome_options(habitat, current_floor)
			if not biome_options.is_empty():
				_spawn_biome_choice_portals(biome_options)
				_pending_biome_selection = true
				_enqueue_message(tr("Two biome portals appear ahead. Step into one to choose your path."))
			else:
				_pending_floor_advance = true
				_enqueue_message(tr("Boss defeated! The path to the next biome opens."))
		else:
			_pending_floor_advance = true
			_enqueue_message(tr("Boss defeated! The path to the next biome opens."))

## Track defeated boss for gauntlet (floor 49)
func _track_defeated_boss() -> void:
	if _boss_npc == null or _boss_npc.npc_data == null:
		return
	
	var boss_data: Dictionary = {
		"floor": current_floor,
		"biome": habitat,
		"team_template": {
			"team_size": _boss_npc.npc_data.team_entries.size(),
			"monsters": []
		}
	}
	
	# Store team composition
	for team_entry in _boss_npc.npc_data.team_entries:
		if team_entry is MTNPCMonsterEntry:
			var monster_data: MTMonsterData = team_entry.monster_data
			if monster_data != null:
				var monster_name: String = str(monster_data.name).strip_edges()
				if monster_name == "":
					monster_name = "Boss Monster"
				var monster_dict: Dictionary = {
					"name": monster_name,
					"level": team_entry.level,
					"path": monster_data.resource_path
				}
				boss_data["team_template"]["monsters"].append(monster_dict)
	
	var game = _get_game()
	if game != null:
		game.add_defeated_boss(boss_data)
		_log_dungeon("[Dungeon] boss tracked floor=%d biome=%s team_size=%d" % [
			current_floor, habitat, boss_data["team_template"]["team_size"]])

#  Floor advancement 

func _advance_floor() -> void:
	if current_floor >= floor_count:
		return

	if _selected_next_biome != "":
		var game = _get_game()
		if game != null and game.has_method("set_next_boss_biome_choice"):
			game.set_next_boss_biome_choice(_selected_next_biome)
		_selected_next_biome = ""
		_pending_biome_selection = false

	current_floor += 1
	if current_floor == 50:
		_enqueue_message(tr("The final gate trembles open. Descend to Floor 50: Gauntlet of the Fallen."))

	_sync_active_route_segment(true)
	_layout_seed = 0  # fresh layout per floor
	_apply_floor_rules(true)
	_enqueue_message(tr("Floor %d / %d  |  Biome: %s") % [current_floor, floor_count, get_dungeon_hud_biome_text()])
	_update_currency_hud(true)

func _apply_floor_rules(reset_player: bool) -> void:
	floor_count = max(run_total_floors, 1)
	current_floor = clamp(current_floor, 1, max(floor_count, 1))
	_sync_active_route_segment()
	if current_floor == 1:
		_reset_run_threat_state()
		_encounter_segments.clear()
		_active_encounter_segment_start = -1
	_start_dungeon_run_if_needed()
	floor_count = max(run_total_floors, floor_count)
	_sync_active_route_segment()
	if base_encounter_chance <= 0.0:
		# Explicitly allow encounter-free dungeons via payload/inspector.
		encounter_chance = 0.0
	else:
		encounter_chance = clamp(
			base_encounter_chance + float(current_floor - 1) * 0.002 + _get_current_threat_encounter_bonus(), 0.0, 0.20)
	_log_dungeon("[Dungeon] encounter base=%s effective=%s floor=%d" % [
		str(base_encounter_chance), str(encounter_chance), current_floor])
	_check_monster_egg_hatch()
	_generate_floor_layout()
	_clear_biome_choice_portals()
	_assign_floor_goals()
	_assign_room_roles()
	_apply_layout_to_tilemaps()
	_build_floor_encounters()
	_update_special_npcs()
	_spawn_floor_npcs()
	_maybe_spawn_quest_npc()
	if reset_player or _player != null:
		_reset_player_position()
	_update_currency_hud(true)

func _start_random_battle() -> void:
	# Boss floors have no random encounters
	var game = _get_game()
	if game != null and game.is_dungeon_boss_floor(current_floor):
		return
	
	# Hard safety-net: when encounter chance is configured to zero, no random
	# battles are allowed to start in dungeon floors.
	if base_encounter_chance <= 0.0 or encounter_chance <= 0.0:
		return
	_log_dungeon("[Dungeon] encounter source=wild floor=%d chance=%s threat_points=%d tier=%d" % [
		current_floor,
		str(encounter_chance),
		_run_threat_points,
		_run_threat_tier
	])
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
	_battle_scene.player_soulbinder_name = _player_name()
	_battle_scene.enemy_soulbinder_name = "Wild"
	var player_team: Array[MTMonsterInstance] = _build_player_team_from_party()
	_battle_scene.start_battle(player_team, enemy_team)

func _build_enemy_team() -> Array[MTMonsterInstance]:
	_sanitize_encounter_entries()
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

func _start_npc_battle(npc) -> void:
	if not _has_npc_data(npc):
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

func _get_wild_level_range(threat_level_bonus: int) -> Vector2i:
	var min_level: int = current_floor + int(current_floor / 2.0) + threat_level_bonus
	if min_level < 1:
		min_level = 1
	var max_level: int = min_level + 3 + int((current_floor - 1) / 10.0)
	return Vector2i(min_level, max_level)

func _build_floor_encounters() -> void:
	encounter_table.clear()
	var threat_level_bonus: int = _get_current_threat_level_bonus()
	var wild_levels: Vector2i = _get_wild_level_range(threat_level_bonus)
	var segment := _get_active_encounter_segment()
	var candidates: Array = segment.get("candidates", [])
	for i in range(candidates.size()):
		var candidate: Dictionary = candidates[i]
		var monster: MTMonsterData = candidate.get("monster", null)
		if monster == null:
			continue
		var entry := EncounterEntryClass.new()
		entry.monster = monster
		entry.min_level = wild_levels.x
		entry.max_level = wild_levels.y
		entry.weight = max(1, int(candidate.get("roll_weight", 1)))
		encounter_table.append(entry)

	if encounter_table.is_empty():
		var fallback := load("res://data/monsters/slime.tres") as MTMonsterData
		if fallback != null:
			var e := EncounterEntryClass.new()
			e.monster = fallback
			e.min_level = wild_levels.x
			e.max_level = wild_levels.y
			e.weight = 10
			encounter_table.append(e)
	_sanitize_encounter_entries()

func _get_dungeon_encounter_config() -> Dictionary:
	var base_config: Dictionary = BalanceConstants.DUNGEON_ENCOUNTER_CONFIG.get("default", {})
	var habitat_key: String = habitat.to_lower()
	var habitat_config: Dictionary = BalanceConstants.DUNGEON_ENCOUNTER_CONFIG.get(habitat_key, {})
	if habitat_config.is_empty():
		return base_config
	var merged := base_config.duplicate(true)
	for key in habitat_config.keys():
		merged[key] = habitat_config[key]
	return merged

func _get_rarity_weights_for_start_floor(start_floor: int) -> Dictionary:
	var rules: Array = BalanceConstants.ENCOUNTER_RARITY_WEIGHT_RULES
	for raw_rule in rules:
		var rule: Dictionary = raw_rule if raw_rule is Dictionary else {}
		var min_floor: int = int(rule.get("start_min", 1))
		var max_floor: int = int(rule.get("start_max", 999))
		if start_floor >= min_floor and start_floor <= max_floor:
			return rule.get("weights", {})
	return {"common": 100}

func _get_elite_budget_rule_for_start_floor(start_floor: int) -> Dictionary:
	var rules: Array = BalanceConstants.ELITE_BUDGET_RULES
	for raw_rule in rules:
		var rule: Dictionary = raw_rule if raw_rule is Dictionary else {}
		var min_floor: int = int(rule.get("start_min", 1))
		var max_floor: int = int(rule.get("start_max", 999))
		if start_floor >= min_floor and start_floor <= max_floor:
			return rule
	return {
		"budget_min": 45,
		"budget_max": 65,
		"team_min": 2,
		"team_max": 3
	}

func _get_active_encounter_segment() -> Dictionary:
	_ensure_encounter_segments()
	for segment in _encounter_segments:
		var start_floor: int = int(segment.get("start_floor", 1))
		var end_floor_exclusive: int = int(segment.get("end_floor_exclusive", 2))
		if current_floor >= start_floor and current_floor < end_floor_exclusive:
			var segment_biome := str(segment.get("biome", habitat))
			if segment_biome != "":
				habitat = segment_biome
			if _active_encounter_segment_start != start_floor:
				_active_encounter_segment_start = start_floor
				_log_dungeon("[Dungeon] encounter segment active start=%d end=%d pool=%d" % [
					start_floor,
					end_floor_exclusive,
					segment.get("candidates", []).size()
				])
			return segment
	return {}

func _has_encounter_segment_for_floor(target_floor: int) -> bool:
	for segment in _encounter_segments:
		var start_floor: int = int(segment.get("start_floor", 1))
		var end_floor_exclusive: int = int(segment.get("end_floor_exclusive", 2))
		if target_floor >= start_floor and target_floor < end_floor_exclusive:
			return true
	return false

func _has_encounter_segment_start(start_floor: int) -> bool:
	for segment in _encounter_segments:
		if int(segment.get("start_floor", -1)) == start_floor:
			return true
	return false

func _append_encounter_segments_for_route_segment(route_segment: Dictionary, candidate_min: int, candidate_max: int) -> void:
	if route_segment.is_empty():
		return
	var route_start_floor: int = int(route_segment.get("start_floor", 1))
	if _has_encounter_segment_start(route_start_floor):
		return
	var route_end_floor: int = int(route_segment.get("end_floor", route_start_floor))
	var biome: String = str(route_segment.get("biome", habitat))
	var old_habitat := habitat
	habitat = biome
	var biome_config: Dictionary = _get_dungeon_encounter_config()
	habitat = old_habitat

	var segment_len: int = route_end_floor - route_start_floor + 1
	var subtable_lengths: Array[int] = _generate_subtable_lengths(segment_len)

	var table_floor: int = route_start_floor
	for subtable_len in subtable_lengths:
		var subtable_end_floor: int = table_floor + subtable_len - 1
		var route_candidate_count: int = _rng.randi_range(candidate_min, candidate_max)
		var candidates: Array[Dictionary] = _build_segment_candidates(biome_config, table_floor, route_candidate_count)
		_encounter_segments.append({
			"start_floor": table_floor,
			"end_floor_exclusive": subtable_end_floor + 1,
			"candidates": candidates,
			"biome": biome
		})
		table_floor = subtable_end_floor + 1

func _ensure_encounter_segments() -> void:
	if _has_encounter_segment_for_floor(current_floor):
		return

	# Ensure route exists for current floor before deriving encounter pools.
	_get_route_segment_for_floor(current_floor)
	if _has_encounter_segment_for_floor(current_floor):
		return

	if _has_game():
		var game = _get_game()
		if game != null and game.has_method("get_dungeon_segment_for_floor"):
			var route_segments = game.dungeon_route_segments
			var route_segment_rules: Dictionary = BalanceConstants.ENCOUNTER_SEGMENT_RULES
			var route_candidate_min: int = max(1, int(route_segment_rules.get("candidate_min", 4)))
			var route_candidate_max: int = max(route_candidate_min, int(route_segment_rules.get("candidate_max", 7)))
			for raw_segment in route_segments:
				var segment: Dictionary = raw_segment if raw_segment is Dictionary else {}
				_append_encounter_segments_for_route_segment(segment, route_candidate_min, route_candidate_max)
			if _has_encounter_segment_for_floor(current_floor):
				return

	var config: Dictionary = _get_dungeon_encounter_config()
	var segment_rules: Dictionary = BalanceConstants.ENCOUNTER_SEGMENT_RULES
	var min_len: int = max(1, int(segment_rules.get("min_len", 3)))
	var max_len: int = max(min_len, int(segment_rules.get("max_len", 7)))
	var candidate_min: int = max(1, int(segment_rules.get("candidate_min", 4)))
	var candidate_max: int = max(candidate_min, int(segment_rules.get("candidate_max", 7)))

	var start_floor: int = 1
	while start_floor <= floor_count:
		var seg_len: int = _rng.randi_range(min_len, max_len)
		var end_floor_exclusive: int = min(start_floor + seg_len, floor_count + 1)
		var actual_seg_len: int = end_floor_exclusive - start_floor
		
		# Generate sub-table lengths for this segment
		var subtable_lengths: Array[int] = _generate_subtable_lengths(actual_seg_len)
		
		# Create encounter segments for each sub-table
		var table_floor: int = start_floor
		for subtable_len in subtable_lengths:
			var subtable_end_floor: int = table_floor + subtable_len - 1
			var candidate_count: int = _rng.randi_range(candidate_min, candidate_max)
			var candidates: Array[Dictionary] = _build_segment_candidates(config, table_floor, candidate_count)
			_encounter_segments.append({
				"start_floor": table_floor,
				"end_floor_exclusive": subtable_end_floor + 1,
				"candidates": candidates
			})
			table_floor = subtable_end_floor + 1
		start_floor = end_floor_exclusive

# Generate variable sub-table lengths (3-7 each) that sum to segment_len
func _generate_subtable_lengths(segment_len: int) -> Array[int]:
	const MIN_TABLE_LEN := 3
	const MAX_TABLE_LEN := 7
	
	if segment_len < MIN_TABLE_LEN:
		return [segment_len]
	if segment_len <= MAX_TABLE_LEN:
		return [segment_len]
	
	var lengths: Array[int] = []
	var remaining: int = segment_len
	
	while remaining > 0:
		if remaining <= MIN_TABLE_LEN:
			lengths.append(remaining)
			remaining = 0
		elif remaining <= MAX_TABLE_LEN:
			lengths.append(remaining)
			remaining = 0
		else:
			var length: int = _rng.randi_range(MIN_TABLE_LEN, min(MAX_TABLE_LEN, remaining))
			lengths.append(length)
			remaining -= length
	
	return lengths

func _build_segment_candidates(config: Dictionary, start_floor: int, target_count: int) -> Array[Dictionary]:
	var pools: Dictionary = config.get("rarity_pools", {})
	var costs: Dictionary = config.get("monster_costs", {})
	var weights: Dictionary = _get_rarity_weights_for_start_floor(start_floor)
	var used_paths: Dictionary = {}
	var candidates: Array[Dictionary] = []

	for _attempt in range(200):
		if candidates.size() >= target_count:
			break
		var rarity: String = _roll_rarity_from_weights(weights)
		if rarity == "":
			break
		var path: String = _pick_unique_path_from_rarity_pool(pools, rarity, used_paths)
		if path == "":
			continue
		var monster := load(path) as MTMonsterData
		if monster == null:
			continue
		used_paths[path] = true
		var roll_weight: int = max(1, int(weights.get(rarity, 1)))
		var fallback_cost := _default_cost_for_rarity(rarity)
		candidates.append({
			"path": path,
			"monster": monster,
			"rarity": rarity,
			"roll_weight": roll_weight,
			"cost": int(costs.get(path, fallback_cost))
		})

	if candidates.is_empty():
		var fallback := load("res://data/monsters/slime.tres") as MTMonsterData
		if fallback != null:
			candidates.append({
				"path": "res://data/monsters/slime.tres",
				"monster": fallback,
				"rarity": "common",
				"roll_weight": 10,
				"cost": 10
			})
	return candidates

func _roll_rarity_from_weights(weights: Dictionary) -> String:
	var total := 0
	for rarity in BalanceConstants.ENCOUNTER_RARITY_ORDER:
		total += max(0, int(weights.get(rarity, 0)))
	if total <= 0:
		return ""
	var roll := _rng.randi_range(1, total)
	var running := 0
	for rarity in BalanceConstants.ENCOUNTER_RARITY_ORDER:
		running += max(0, int(weights.get(rarity, 0)))
		if roll <= running:
			return rarity
	return ""

func _pick_unique_path_from_rarity_pool(pools: Dictionary, rarity: String, used_paths: Dictionary) -> String:
	var selected := _pick_unique_path_from_list(pools.get(rarity, []), used_paths)
	if selected != "":
		return selected
	for fallback_rarity in BalanceConstants.ENCOUNTER_RARITY_ORDER:
		selected = _pick_unique_path_from_list(pools.get(fallback_rarity, []), used_paths)
		if selected != "":
			return selected
	return ""

func _pick_unique_path_from_list(list_value, used_paths: Dictionary) -> String:
	var entries: Array = list_value if list_value is Array else []
	if entries.is_empty():
		return ""
	var available: Array[String] = []
	for raw in entries:
		var path := str(raw)
		if path == "" or used_paths.has(path):
			continue
		available.append(path)
	if available.is_empty():
		return ""
	return available[_rng.randi_range(0, available.size() - 1)]

func _default_cost_for_rarity(rarity: String) -> int:
	match rarity:
		"common":
			return 10
		"uncommon":
			return 16
		"rare":
			return 22
		"very_rare":
			return 30
		"legendary":
			return 40
		_:
			return 12

func _validate_dungeon_item_pools() -> void:
	var db := ITEM_DB_CLASS.new()
	var valid_reward_pool: Array[String] = db.filter_valid_item_ids(item_reward_pool)
	if valid_reward_pool.size() != item_reward_pool.size():
		_log_dungeon("[Dungeon] filtered invalid item ids from reward pool")
	item_reward_pool = valid_reward_pool

	var valid_shop_items: Array[String] = db.filter_valid_item_ids(merchant_shop_items)
	if valid_shop_items.size() != merchant_shop_items.size():
		_log_dungeon("[Dungeon] filtered invalid item ids from merchant shop")
	merchant_shop_items = valid_shop_items

	if merchant_shop_prices.size() > merchant_shop_items.size():
		merchant_shop_prices.resize(merchant_shop_items.size())

	_sanitize_encounter_entries()

func _sanitize_encounter_entries() -> void:
	var valid: Array[MTEncounterEntry] = []
	for entry in encounter_table:
		if entry == null:
			continue
		if entry.monster == null:
			continue
		if entry.weight <= 0:
			continue
		if entry.min_level < 1:
			entry.min_level = 1
		if entry.max_level < entry.min_level:
			entry.max_level = entry.min_level
		valid.append(entry)
	encounter_table = valid

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
		if not _has_npc_data(npc):
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
	_player_spawn_cell = start_cell

	var game = _get_game()
	if game != null and game.is_gauntlet_floor(current_floor):
		# Floor 50: gauntlet and final boss share this floor.
		_set_npc_active(_stairs_npc, false, Vector2i.ZERO)
		if _final_boss_phase_active:
			_prepare_final_boss()
			if _room_rects.size() > 2:
				_set_npc_active(_boss_npc, true, _room_center(_room_rects[2]))
			else:
				_set_npc_active(_boss_npc, true, _room_center(_room_rects[1]))
		else:
			_prepare_gauntlet_battle()
			if _room_rects.size() > 1:
				_set_npc_active(_boss_npc, true, _room_center(_room_rects[1]))
			else:
				_set_npc_active(_boss_npc, true, _room_center(_room_rects[0]))
	elif not _is_current_floor_boss_floor():
		# Normal floors: stairs in far room
		var far_room := _room_rects[_get_farthest_room_index(0)]
		var far_cell := _room_center(far_room)
		_set_npc_active(_stairs_npc, true, far_cell)
		_set_npc_active(_boss_npc, false, Vector2i.ZERO)
	else:
		# Regular boss floors (41-48): boss in far room
		var far_room := _room_rects[_get_farthest_room_index(0)]
		var far_cell := _room_center(far_room)
		_set_npc_active(_stairs_npc, false, Vector2i.ZERO)
		_prepare_boss_npc()
		_set_npc_active(_boss_npc, true, far_cell)

	_log_dungeon("[Dungeon] spawn=%s  boss=%s" % [
		str(start_cell), str(_boss_npc.global_position if _boss_npc != null else "NULL")])

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
	var target_team_size: int = max(1, boss_team_size)
	var upgraded_entries := _build_boss_team_entries(target_team_size)
	boss_data.team_entries = upgraded_entries
	_log_dungeon("[Dungeon] boss team prepared size=%d" % boss_data.team_entries.size())
	_boss_npc.npc_data = boss_data

## Prepare gauntlet battle (Floor 49)
## Uses defeated bosses from earlier floors with Level 49
func _prepare_gauntlet_battle() -> void:
	"""Prepare multiple consecutive gauntlet boss fights (one per defeated boss)"""
	if _boss_npc == null or _boss_npc.npc_data == null:
		return
	var game = _get_game()
	if game == null:
		return
	
	# Build queue of individual gauntlet fights (one per defeated boss)
	var defeated_bosses: Array = game.get_defeated_boss_data()
	_gauntlet_fight_queue.clear()
	_current_gauntlet_fight_index = 0
	_final_boss_phase_active = false
	
	# Create separate fight entry for each defeated boss
	for i in range(defeated_bosses.size()):
		var boss_entry: Dictionary = defeated_bosses[i] as Dictionary
		if boss_entry.is_empty():
			continue
		
		var gauntlet_entry: Dictionary = {
			"boss_index": i,
			"boss_data": boss_entry,
			"team_entries": [],
			"boss_name": boss_entry.get("name", "Boss %d" % (i + 1))
		}
		
		# Build team for this gauntlet fight from boss's monsters
		var template: Dictionary = boss_entry.get("team_template", {})
		if template.has("monsters"):
			for j in range(min(5, int(template.get("team_size", 5)))):
				var monster_pool = template["monsters"]
				if monster_pool is Array and j < monster_pool.size():
					var monster_dict = monster_pool[j]
					gauntlet_entry["team_entries"].append(_create_npc_monster_entry_from_dict(monster_dict, 50))
		
		if not gauntlet_entry["team_entries"].is_empty():
			_gauntlet_fight_queue.append(gauntlet_entry)
	
	# If no defeated bosses, create default gauntlet fight
	if _gauntlet_fight_queue.is_empty():
		var default_fight: Dictionary = {
			"boss_index": 0,
			"boss_data": {},
			"team_entries": _build_boss_team_entries(boss_team_size),
			"boss_name": "Boss Gauntlet"
		}
		_gauntlet_fight_queue.append(default_fight)
	
	_gauntlet_active = true
	_start_next_gauntlet_fight()
	_log_dungeon("[Dungeon] gauntlet queue prepared fights=%d" % _gauntlet_fight_queue.size())

func _start_next_gauntlet_fight() -> void:
	"""Start the next fight in the gauntlet queue"""
	if _current_gauntlet_fight_index >= _gauntlet_fight_queue.size():
		_gauntlet_active = false
		return
	
	if _boss_npc == null or _boss_npc.npc_data == null:
		return
	
	var current_fight: Dictionary = _gauntlet_fight_queue[_current_gauntlet_fight_index]
	var gauntlet_data: MTNPCData = _boss_npc.npc_data.duplicate(true) as MTNPCData
	if gauntlet_data == null:
		return
	
	gauntlet_data.battle_once = true
	var total_fights = _gauntlet_fight_queue.size()
	var fight_num = _current_gauntlet_fight_index + 1
	gauntlet_data.npc_name = "Gauntlet (%d/%d): %s" % [fight_num, total_fights, current_fight["boss_name"]]
	gauntlet_data.team_entries = current_fight["team_entries"]
	
	_boss_npc.npc_data = gauntlet_data
	_log_dungeon("[Dungeon] gauntlet fight started index=%d name=%s team_size=%d" % [
		_current_gauntlet_fight_index, gauntlet_data.npc_name, gauntlet_data.team_entries.size()])

func _activate_final_boss_phase() -> void:
	_final_boss_phase_active = true
	_prepare_final_boss()
	if _boss_npc != null:
		if _room_rects.size() > 2:
			_set_npc_active(_boss_npc, true, _room_center(_room_rects[2]))
		elif _room_rects.size() > 1:
			_set_npc_active(_boss_npc, true, _room_center(_room_rects[1]))
	_enqueue_message(tr("Gauntlet cleared! The Final Warden appears."))

func _trigger_next_gauntlet_encounter() -> void:
	"""Trigger battle with next gauntlet opponent"""
	if not _gauntlet_active or _current_gauntlet_fight_index >= _gauntlet_fight_queue.size():
		return
	
	# Update boss NPC data for next fight
	_start_next_gauntlet_fight()
	
	# Check if player is next to boss NPC and trigger battle
	if _boss_npc != null:
		var cell = _boss_npc.cell
		var adj_cells = [
			cell + Vector2i.UP,
			cell + Vector2i.DOWN,
			cell + Vector2i.LEFT,
			cell + Vector2i.RIGHT
		]
		
		if _player != null and _player.cell in adj_cells:
			# Auto-trigger next gauntlet battle
			_boss_battle_active = true
			_start_npc_battle(_boss_npc)

## Prepare final boss (Floor 50)
## Super strong unique boss
func _prepare_final_boss() -> void:
	if _boss_npc == null or _boss_npc.npc_data == null:
		return
	
	var final_data: MTNPCData = _boss_npc.npc_data.duplicate(true) as MTNPCData
	if final_data == null:
		return
	
	final_data.battle_once = true
	final_data.npc_name = "The Final Warden"
	
	# Final boss team: 5 level 50 super-strong monsters
	var final_entries: Array[MTNPCMonsterEntry] = []
	var final_monsters := [
		{"name": "Astralisk", "level": 50, "path": "res://data/monsters/astralisk.tres"},
		{"name": "Aurumane", "level": 50, "path": "res://data/monsters/aurumane.tres"},
		{"name": "Volcarn", "level": 50, "path": "res://data/monsters/volcarn.tres"},
		{"name": "Thundrake", "level": 50, "path": "res://data/monsters/thundrake.tres"},
		{"name": "Halcyriel", "level": 50, "path": "res://data/monsters/halcyriel.tres"}
	]
	
	for monster_def in final_monsters:
		var monster_entry := MTNPCMonsterEntry.new()
		var monster_data = load(monster_def.get("path", "res://data/monsters/slime.tres")) as MTMonsterData
		if monster_data != null:
			monster_entry.monster_data = monster_data
			monster_entry.level = 50
			final_entries.append(monster_entry)
	
	final_data.team_entries = final_entries
	_boss_npc.npc_data = final_data
	_log_dungeon("[Dungeon] final boss team prepared size=%d" % final_data.team_entries.size())

func _create_npc_monster_entry_from_dict(monster_dict: Dictionary, target_level: int) -> MTNPCMonsterEntry:
	var entry := MTNPCMonsterEntry.new()
	var monster_data = load(monster_dict.get("path", "res://data/monsters/slime.tres")) as MTMonsterData
	if monster_data != null:
		entry.monster_data = monster_data
		entry.level = target_level
	return entry

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
	var candidates: Array = _get_active_encounter_segment().get("candidates", [])
	if not candidates.is_empty():
		var candidate: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var data: MTMonsterData = candidate.get("monster", null)
		if data != null:
			return data
	return DungeonNPCSpawnHelperClass.pick_monster_for_habitat(self)

func _get_active_segment_start_floor() -> int:
	var segment: Dictionary = _get_active_encounter_segment()
	return int(segment.get("start_floor", current_floor))

func _build_elite_team_entries() -> Array[MTNPCMonsterEntry]:
	var entries: Array[MTNPCMonsterEntry] = []
	var threat_level_bonus: int = _get_current_threat_level_bonus()
	var wild_levels := _get_wild_level_range(threat_level_bonus)
	var elite_min_level: int = wild_levels.y + 1
	var segment: Dictionary = _get_active_encounter_segment()
	var candidates: Array = segment.get("candidates", [])
	if candidates.is_empty():
		var fallback: MTNPCMonsterEntry = NPCMonsterEntryClass.new()
		fallback.monster_data = _pick_monster_for_habitat()
		fallback.level = elite_min_level
		entries.append(fallback)
		return entries

	var budget_rule: Dictionary = _get_elite_budget_rule_for_start_floor(_get_active_segment_start_floor())
	var threat_budget_multiplier: float = _get_current_threat_elite_budget_multiplier()
	var base_budget: int = _rng.randi_range(int(budget_rule.get("budget_min", 45)), int(budget_rule.get("budget_max", 65)))
	var target_budget: int = max(1, int(round(float(base_budget) * threat_budget_multiplier)))
	var team_min: int = max(1, int(budget_rule.get("team_min", 2)))
	var team_max: int = max(team_min, int(budget_rule.get("team_max", 3)))
	var team_target: int = _rng.randi_range(team_min, team_max)

	var budget_used: int = 0
	var high_rarity_count: int = 0
	var attempts: int = 0
	while entries.size() < team_target and attempts < 80:
		attempts += 1
		var candidate: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var rarity: String = str(candidate.get("rarity", "common"))
		if (rarity == "very_rare" or rarity == "legendary") and high_rarity_count >= 1:
			continue
		var cost: int = max(1, int(candidate.get("cost", 10)))
		if entries.size() >= team_min and budget_used + cost > target_budget:
			continue
		var entry: MTNPCMonsterEntry = NPCMonsterEntryClass.new()
		entry.monster_data = candidate.get("monster", null)
		if entry.monster_data == null:
			continue
		entry.level = elite_min_level + _rng.randi_range(0, 2)
		entries.append(entry)
		budget_used += cost
		if rarity == "very_rare" or rarity == "legendary":
			high_rarity_count += 1

	while entries.size() < team_min:
		var fallback_entry: MTNPCMonsterEntry = NPCMonsterEntryClass.new()
		fallback_entry.monster_data = _pick_monster_for_habitat()
		fallback_entry.level = elite_min_level + _rng.randi_range(0, 1)
		entries.append(fallback_entry)

	return entries

func _build_thief_team_entries() -> Array[MTNPCMonsterEntry]:
	var size_hint: int = int(min(5, 1 + int(current_floor / 5.0)))
	return _build_curated_template_team("thief_team_templates", size_hint)

func _build_boss_team_entries(target_team_size: int) -> Array[MTNPCMonsterEntry]:
	return _build_curated_template_team("boss_team_templates", max(1, target_team_size))

func _build_curated_template_team(template_key: String, target_team_size: int) -> Array[MTNPCMonsterEntry]:
	var threat_level_bonus: int = _get_current_threat_level_bonus()
	var wild_levels := _get_wild_level_range(threat_level_bonus)
	var curated_min_level: int = wild_levels.y + 1
	var curated_variance: int = 1
	if template_key == "boss_team_templates":
		curated_min_level += 2
		curated_variance = 2
	var config: Dictionary = _get_dungeon_encounter_config()
	var templates: Array = config.get(template_key, [])
	var chosen_template: Array = []
	if not templates.is_empty():
		chosen_template = templates[_rng.randi_range(0, templates.size() - 1)]
	var entries: Array[MTNPCMonsterEntry] = []
	for raw_path in chosen_template:
		if entries.size() >= target_team_size:
			break
		var monster_data := load(str(raw_path)) as MTMonsterData
		if monster_data == null:
			continue
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = monster_data
		entry.level = curated_min_level + _rng.randi_range(0, curated_variance)
		entries.append(entry)

	while entries.size() < target_team_size:
		var extra := NPCMonsterEntryClass.new()
		extra.monster_data = _pick_monster_for_habitat()
		extra.level = curated_min_level + _rng.randi_range(0, curated_variance)
		entries.append(extra)
	return entries

func _pick_free_floor_cell(reserved: Dictionary) -> Vector2i:
	return DungeonNPCSpawnHelperClass.pick_free_floor_cell(self, reserved)

func _is_safe_npc_spawn_cell(cell: Vector2i) -> bool:
	return DungeonNPCSpawnHelperClass.is_safe_npc_spawn_cell(self, cell)

func _is_chokepoint_cell(cell: Vector2i) -> bool:
	return DungeonNPCSpawnHelperClass.is_chokepoint_cell(self, cell)

#  Layout generation 

func _generate_floor_layout() -> void:
	# Boss floors use special minimal layout.
	var game = _get_game()
	if game != null and game.boss_system_enabled and game.is_dungeon_boss_floor(current_floor):
		_generate_boss_floor_layout()
	else:
		DungeonLayoutHelperClass.generate_floor_layout(self)

## Special layout for boss floors and gauntlet
## Floors 41-48: 2 rooms (entry + boss)
## Floors 49-50: 3 rooms (entry + gauntlet/final boss center + final boss/nexus)
func _generate_boss_floor_layout() -> void:
	_log_dungeon("[Dungeon] _generate_boss_floor_layout floor=%d" % current_floor)
	
	# Clear previous layout
	_floor_cells.clear()
	_room_rects.clear()
	_room_type_by_index.clear()
	_room_index_by_cell.clear()
	_elite_room_index = -1
	
	var is_gauntlet_or_final := current_floor == 50
	
	if is_gauntlet_or_final:
		# 3-room layout for Gauntlet (49) and Final Boss (50)
		# Entry room: 8x8 at (8, 8)
		var entry_rect := Rect2i(8, 8, 8, 8)
		_room_rects.append(entry_rect)
		_room_type_by_index[0] = ROOM_TYPE_START
		
		# Center battle room: 8x8 at (24, 8)
		var center_rect := Rect2i(24, 8, 8, 8)
		_room_rects.append(center_rect)
		_room_type_by_index[1] = ROOM_TYPE_NORMAL
		
		# Final room: 8x8 at (40, 8)
		var final_rect := Rect2i(40, 8, 8, 8)
		_room_rects.append(final_rect)
		_room_type_by_index[2] = ROOM_TYPE_EXIT
		
		# Carve all 3 rooms
		for room_rect in _room_rects:
			for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
				for y in range(room_rect.position.y, room_rect.position.y + room_rect.size.y):
					var cell := Vector2i(x, y)
					_floor_cells.append(cell)
					_room_index_by_cell[cell] = _room_rects.find(room_rect)
		
		# Carve corridors (entry -> center, center -> final)
		var entry_center_x := int(entry_rect.get_center().x)
		var center_center_x := int(center_rect.get_center().x)
		var final_center_x := int(final_rect.get_center().x)
		var corridor_y := int(entry_rect.get_center().y)
		
		# Corridor 1: entry to center
		for x in range(entry_center_x, center_center_x + 1):
			var cell := Vector2i(x, corridor_y)
			if cell not in _floor_cells:
				_floor_cells.append(cell)
			_corridor_cells_lookup[cell] = true
		
		# Corridor 2: center to final
		for x in range(center_center_x, final_center_x + 1):
			var cell := Vector2i(x, corridor_y)
			if cell not in _floor_cells:
				_floor_cells.append(cell)
			_corridor_cells_lookup[cell] = true
		
		_player_spawn_cell = entry_rect.get_center()
	else:
		# 2-room layout for regular boss floors (41-48)
		# Entry room: 8x8 at position (8, 8)
		var entry_rect := Rect2i(8, 8, 8, 8)
		_room_rects.append(entry_rect)
		_room_type_by_index[0] = ROOM_TYPE_START
		
		# Boss room: 8x8 at position (24, 8)
		var boss_rect := Rect2i(24, 8, 8, 8)
		_room_rects.append(boss_rect)
		_room_type_by_index[1] = ROOM_TYPE_EXIT
		
		# Carve both rooms into floor cells
		for room_rect in _room_rects:
			for x in range(room_rect.position.x, room_rect.position.x + room_rect.size.x):
				for y in range(room_rect.position.y, room_rect.position.y + room_rect.size.y):
					var cell := Vector2i(x, y)
					_floor_cells.append(cell)
					_room_index_by_cell[cell] = _room_rects.find(room_rect)
		
		# Carve corridor between rooms
		var corridor_start_x := int(entry_rect.get_center().x)
		var corridor_end_x := int(boss_rect.get_center().x)
		var corridor_y := int(entry_rect.get_center().y)
		
		if corridor_start_x < corridor_end_x:
			for x in range(corridor_start_x, corridor_end_x + 1):
				var cell := Vector2i(x, corridor_y)
				if cell not in _floor_cells:
					_floor_cells.append(cell)
				_corridor_cells_lookup[cell] = true
		
		_player_spawn_cell = entry_rect.get_center()
	
	_log_dungeon("[Dungeon] boss floor layout: %d cells, %d rooms" % [_floor_cells.size(), _room_rects.size()])

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
	if not _has_npc_data(npc):
		return true
	var interaction: String = str(npc.npc_data.interaction_id)
	var parts := interaction.split(":")
	var item_id := "lesser_healing_potion"
	if parts.size() >= 2:
		item_id = parts[1]
	if _has_game():
		var game = _get_game()
		game.add_item(item_id, 1)
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
	if _has_game():
		var game = _get_game()
		game.add_run_gold(amount)
	_enqueue_message(tr("You found a gold stash! Gold +%d") % amount)
	_log_dungeon("[Dungeon] gold stash amount=%d" % amount)
	return true

func _handle_essence_cache(npc) -> bool:
	var amount := 1 + int(current_floor / 10.0)
	_set_npc_active(npc, false, Vector2i.ZERO)
	if _has_game():
		var game = _get_game()
		game.add_soul_essence(amount)
	_enqueue_message(tr("Soul Essence Cache: You absorb the power. Soul Essence +%d") % amount)
	_log_dungeon("[Dungeon] essence cache amount=%d" % amount)
	return true

func _handle_status_trap(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	var living_party := _get_party_monster_instances(true)
	if living_party.is_empty():
		_enqueue_message(tr("A trap springs! But there is nothing to harm."))
		return true
	for m in living_party:
		var damage := int(ceil(m.get_max_hp() * 0.25))
		m.hp = max(1, m.hp - damage)
		var mname := m.data.name if m.data != null else tr("Monster")
		_enqueue_message(tr("It's a trap! %s lost %d HP!") % [mname, damage])
		_log_dungeon("[Dungeon] status trap triggered hp_lost=%d" % damage)
		break
	return true

func _handle_monster_egg(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if _has_game():
		var game = _get_game()
		game.add_item("monster_egg", 1)
	_enqueue_message(tr("You found a Monster Egg! It will hatch on the next floor."))
	_log_dungeon("[Dungeon] monster egg picked up")
	return true

func _handle_cursed_altar(npc) -> bool:
	_set_npc_active(npc, false, Vector2i.ZERO)
	if not _has_game():
		_enqueue_message(tr("The altar pulses with dark energy, but nothing happens."))
		return true
	var game = _get_game()
	var total_lost := 0
	for m in _get_party_monster_instances(true):
		var damage := int(ceil(m.get_max_hp() * 0.30))
		m.hp = max(1, m.hp - damage)
		total_lost += damage
	var gold_gain := 10 + current_floor * 2
	game.add_soul_essence(1)
	game.add_run_gold(gold_gain)
	_enqueue_message(tr("Cursed Altar: Your team suffers %d total damage... Soul Essence +1, Gold +%d.") % [total_lost, gold_gain])
	_log_dungeon("[Dungeon] cursed altar used hp_lost=%d gold=%d" % [total_lost, gold_gain])
	return true

func _handle_secret_vault(npc) -> bool:
	if not _has_game():
		_enqueue_message(tr("Locked. You need a Secret Key to open this vault."))
		return true
	var game = _get_game()
	if game.get_item_count("secret_key") <= 0:
		_enqueue_message(tr("Locked. You need a Secret Key to open this vault."))
		return true
	game.remove_item("secret_key", 1)
	_set_npc_active(npc, false, Vector2i.ZERO)
	# Vault rewards: 1 random item + gold + soul essence
	var item_id := _pick_or_create_random_item()
	game.add_item(item_id, 1)
	var gold := 20 + current_floor * 4
	game.add_run_gold(gold)
	game.add_soul_essence(2)
	_enqueue_message(tr("Secret Vault opened! Found items, Gold +%d, and Soul Essence +2!") % gold)
	_log_dungeon("[Dungeon] secret vault opened gold=%d" % gold)
	return true

func _check_monster_egg_hatch() -> void:
	if not _has_game():
		return
	var game = _get_game()
	if game.get_item_count("monster_egg") <= 0:
		return
	if game.is_party_full():
		_enqueue_message(tr("Your egg is ready to hatch, but your team is full!"))
		return
	game.remove_item("monster_egg", 1)
	var monster_data := _pick_monster_for_habitat()
	if monster_data == null:
		return
	var new_monster := MTMonsterInstance.new(monster_data)
	new_monster.level = max(1, current_floor - 1)
	new_monster._recalculate_stats()
	new_monster.hp = new_monster.get_max_hp()
	if not game.add_to_party(new_monster):
		_enqueue_message(tr("Your egg is ready to hatch, but your team is full!"))
		return
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

func _handle_boss_floor_shop(_npc) -> bool:
	"""Handle shopkeeper interaction on boss floors 41-48"""
	if merchant_shop_items.is_empty():
		_enqueue_message(tr("Shopkeeper: I'm out of stock for this run."))
		return true
	_open_merchant_shop()
	return true

func _create_merchant_shop_ui() -> void:
	DungeonShopUIHelperClass.create_merchant_shop_ui(self)

func _create_portal_ui() -> void:
	DungeonPortalUIHelperClass.create_portal_ui(self)

func _show_biome_portals(biome_options: Array[String]) -> void:
	DungeonPortalUIHelperClass.show_biome_selection_portals(self, biome_options)

func _hide_biome_portals() -> void:
	DungeonPortalUIHelperClass.hide_biome_selection_portals(self)

func _spawn_biome_choice_portals(biome_options: Array[String]) -> void:
	_clear_biome_choice_portals()
	_hide_biome_portals()
	if biome_options.is_empty():
		return
	var room_index: int = _get_farthest_room_index(0)
	if room_index < 0 or room_index >= _room_rects.size():
		return
	var room_center: Vector2i = _room_center(_room_rects[room_index])
	var preferred_cells: Array[Vector2i] = [room_center + Vector2i(-2, 0), room_center + Vector2i(2, 0)]
	var reserved: Dictionary = {}
	reserved[_player_cell] = true
	if _stairs_npc != null and _stairs_npc.visible:
		reserved[_world_to_cell(_stairs_npc.global_position)] = true
	if _boss_npc != null and _boss_npc.visible:
		reserved[_world_to_cell(_boss_npc.global_position)] = true
	for npc in _npcs:
		if npc == null or not npc.visible or not npc.has_method("get_cell"):
			continue
		reserved[npc.get_cell(_grass_layer)] = true
	var spawn_count: int = min(2, biome_options.size())
	for i in range(spawn_count):
		var biome: String = str(biome_options[i])
		var preferred: Vector2i = preferred_cells[i] if i < preferred_cells.size() else room_center
		var cell: Vector2i = _find_portal_spawn_cell(preferred, reserved)
		if cell == Vector2i(-1, -1):
			continue
		reserved[cell] = true
		_spawn_dynamic_npc(cell, _create_biome_portal_npc_data(biome))
		if _dynamic_npcs.is_empty():
			continue
		var portal_npc = _dynamic_npcs[_dynamic_npcs.size() - 1]
		if portal_npc == null:
			continue
		portal_npc.modulate = Color(0.55, 0.8, 1.0, 1.0) if i == 0 else Color(0.95, 0.7, 0.35, 1.0)
		_attach_portal_name_label(portal_npc, DungeonPortalUIHelperClass.get_biome_display_name(biome))
		_biome_portal_npcs.append(portal_npc)

func _clear_biome_choice_portals() -> void:
	for portal_npc in _biome_portal_npcs:
		if portal_npc == null:
			continue
		_npcs.erase(portal_npc)
		_dynamic_npcs.erase(portal_npc)
		portal_npc.queue_free()
	_biome_portal_npcs.clear()

func _find_portal_spawn_cell(preferred: Vector2i, reserved: Dictionary) -> Vector2i:
	if _is_cell_walkable(preferred) and not reserved.has(preferred):
		return preferred
	var max_radius := 6
	for radius in range(1, max_radius + 1):
		for y in range(preferred.y - radius, preferred.y + radius + 1):
			for x in range(preferred.x - radius, preferred.x + radius + 1):
				var candidate := Vector2i(x, y)
				if reserved.has(candidate):
					continue
				if not _is_cell_walkable(candidate):
					continue
				return candidate
	return Vector2i(-1, -1)

func _create_biome_portal_npc_data(biome: String) -> MTNPCData:
	var data := NPCDataClass.new()
	var biome_name: String = DungeonPortalUIHelperClass.get_biome_display_name(biome)
	data.display_name = biome_name
	data.dialogue_before = tr("A portal to %s hums with energy.") % biome_name
	data.interaction_id = "dungeon_portal_choice:%s" % biome
	data.walk_enabled = false
	data.battle_once = false
	return data

func _attach_portal_name_label(portal_npc, label_text: String) -> void:
	if portal_npc == null:
		return
	for child in portal_npc.get_children():
		if child is Label and child.name == "PortalBiomeLabel":
			child.queue_free()
	var label := Label.new()
	label.name = "PortalBiomeLabel"
	label.text = label_text
	label.position = Vector2(-64, -44)
	label.size = Vector2(128, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.1, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	portal_npc.add_child(label)

func _on_portal_biome_selected(biome: String) -> void:
	"""Handle biome selection from portal UI"""
	_selected_next_biome = biome
	_pending_biome_selection = false
	var game = _get_game()
	if game != null and game.has_method("set_next_boss_biome_choice"):
		game.set_next_boss_biome_choice(biome)
	_clear_biome_choice_portals()
	_hide_biome_portals()
	_enqueue_message(tr("Traveling to %s...") % [DungeonPortalUIHelperClass.get_biome_display_name(biome)])
	_pending_floor_advance = true

func _handle_biome_portal_interaction(npc, interaction: String) -> bool:
	if not _pending_biome_selection:
		return true
	var parts := interaction.split(":")
	if parts.size() < 2:
		return true
	var biome: String = str(parts[1]).strip_edges()
	if biome == "":
		return true
	_on_portal_biome_selected(biome)
	_set_npc_active(npc, false, Vector2i.ZERO)
	return true

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
	for m in _get_party_monster_instances():
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
	for m in _get_party_monster_instances(true):
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

func _get_party_monster_instances(only_alive: bool = false) -> Array[MTMonsterInstance]:
	var result: Array[MTMonsterInstance] = []
	if not _has_game():
		return result
	var game = _get_game()
	for monster in game.party:
		if monster == null:
			continue
		if not (monster is MTMonsterInstance):
			continue
		var m := monster as MTMonsterInstance
		if only_alive and not m.is_alive():
			continue
		result.append(m)
	return result

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
		"thornfang_warrens":
			return [
				"res://data/monsters/wolf.tres",
				"res://data/monsters/fernox.tres",
				"res://data/monsters/slime.tres",
				"res://data/monsters/aquafin.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"sunforge_basilica":
			return [
				"res://data/monsters/stoneback.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/emberkat.tres",
				"res://data/monsters/ghostling.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"skytide_reservoir":
			return [
				"res://data/monsters/aquafin.tres",
				"res://data/monsters/slime.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/fernox.tres",
				"res://data/monsters/ghostling.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"emberfault_chasm":
			return [
				"res://data/monsters/emberkat.tres",
				"res://data/monsters/stoneback.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/fernox.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"stargrave_observatory":
			return [
				"res://data/monsters/ghostling.tres",
				"res://data/monsters/slime.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/aquafin.tres",
				"res://data/monsters/stoneback.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"ironhowl_bastion":
			return [
				"res://data/monsters/wolf.tres",
				"res://data/monsters/stoneback.tres",
				"res://data/monsters/emberkat.tres",
				"res://data/monsters/fernox.tres",
				"res://data/monsters/wolfinator.tres"
			]
		"echo_vault":
			return [
				"res://data/monsters/ghostling.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/aquafin.tres",
				"res://data/monsters/fernox.tres",
				"res://data/monsters/wolfinator.tres"
			]
		_:
			return [
				"res://data/monsters/slime.tres",
				"res://data/monsters/ghostling.tres",
				"res://data/monsters/stoneback.tres",
				"res://data/monsters/wolf.tres",
				"res://data/monsters/wolfinator.tres"
			]
#  Player reset 

func _reset_player_position() -> void:
	if _player == null:
		return
	_player.global_position = _cell_to_world(_player_spawn_cell)
	_sync_cells()
