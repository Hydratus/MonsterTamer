extends Node

const TEAM_SIZE_CAP := 5  # See GameBalanceConstants.TEAM_SIZE_CAP
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT := 50
const DUNGEON_ROUTE_MIN_SEGMENT_LEN_DEFAULT := 7
const DUNGEON_ROUTE_MAX_SEGMENT_LEN_DEFAULT := 15
const DUNGEON_ROUTE_DEFAULT_BIOMES: Array[String] = [
	"gloomrot_catacombs",
	"thornfang_warrens",
	"sunforge_basilica",
	"skytide_reservoir",
	"emberfault_chasm",
	"stargrave_observatory",
	"ironhowl_bastion",
	"echo_vault"
]

var party := []
var inventory := {}

func _ready() -> void:
	# Give 1 Secret Key on first game load if player doesn't already have one
	if not inventory.has("secret_key"):
		add_item("secret_key", 1)
var flags := {}
var player_name: String = "Player"
var run_gold: int = 0
var soul_essence: int = 0
var meta_unlocks: Dictionary = {}
var dungeon_route_segments: Array[Dictionary] = []

# Boss system tracking
var boss_system_enabled: bool = true  # Enable portal-based biome selection
var biome_progression_order: Array[String] = []  # Order of biomes player visits (floors 1-40)
var defeated_boss_data: Array[Dictionary] = []  # Tracks defeated bosses for gauntlet (floor 49)
var _route_rng := RandomNumberGenerator.new()
var _route_biome_pool: Array[String] = []
var _route_segment_min_len: int = DUNGEON_ROUTE_MIN_SEGMENT_LEN_DEFAULT
var _route_segment_max_len: int = DUNGEON_ROUTE_MAX_SEGMENT_LEN_DEFAULT
var _forced_next_biome: String = ""

var _item_db := ITEM_DB_CLASS.new()

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func add_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if not _is_valid_item_id(item_id):
		DEBUG_LOG.error("Game", "Unknown item id: %s" % item_id)
		return
	var current := get_item_count(item_id)
	inventory[item_id] = current + amount

func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if not _is_valid_item_id(item_id):
		DEBUG_LOG.error("Game", "Unknown item id: %s" % item_id)
		return false
	var current := get_item_count(item_id)
	if current < amount:
		return false
	var next := current - amount
	if next <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next
	return true

func swap_party_positions(index_a: int, index_b: int) -> bool:
	if index_a < 0 or index_b < 0:
		return false
	if index_a >= party.size() or index_b >= party.size():
		return false
	if index_a == index_b:
		return true
	var temp: Variant = party[index_a]
	party[index_a] = party[index_b]
	party[index_b] = temp
	return true

## Add a monster to the party with team size validation
func add_to_party(monster: MTMonsterInstance) -> bool:
	if monster == null:
		DEBUG_LOG.error("Game", "Cannot add null monster to party")
		return false
	if party.size() >= TEAM_SIZE_CAP:
		DEBUG_LOG.error("Game", "Party is full (max %d monsters)" % TEAM_SIZE_CAP)
		return false
	party.append(monster)
	return true

func remove_from_party(monster: MTMonsterInstance) -> bool:
	if monster == null:
		return false
	var party_index := party.find(monster)
	if party_index == -1:
		return false
	party.remove_at(party_index)
	return true

## Get current party size
func get_party_size() -> int:
	return party.size()

## Check if party is at maximum capacity
func is_party_full() -> bool:
	return party.size() >= TEAM_SIZE_CAP

func reset_run_state(starting_gold: int = 0) -> void:
	run_gold = max(0, starting_gold)
	clear_dungeon_route()

func restore_party_after_run() -> void:
	for monster in party:
		if monster == null:
			continue
		if not (monster is MTMonsterInstance):
			continue
		var m: MTMonsterInstance = monster as MTMonsterInstance
		m.hp = m.get_max_hp()
		m.energy = m.get_max_energy()
		m.clear_negative_statuses()
		m.reset_stat_stages()

func clear_dungeon_route() -> void:
	dungeon_route_segments.clear()
	biome_progression_order.clear()
	defeated_boss_data.clear()
	_forced_next_biome = ""

## Setup dungeon route with dynamic biome segments:
## - Floors 1-49: Random-length biome segments
## - Last floor of each segment is a biome boss floor
## - Next segment biome comes from portal selection (2 options)
## - Floor 50: Endgame floor (gauntlet + final boss)
func setup_dungeon_route_with_boss_system(
	total_floors: int = 50,
	biome_pool: Array[String] = [],
	preferred_start_biome: String = "",
	route_seed: int = 0,
	segment_min_len: int = DUNGEON_ROUTE_MIN_SEGMENT_LEN_DEFAULT,
	segment_max_len: int = DUNGEON_ROUTE_MAX_SEGMENT_LEN_DEFAULT
) -> void:
	if biome_pool.is_empty():
		biome_pool = DUNGEON_ROUTE_DEFAULT_BIOMES.duplicate()

	var normalized_pool: Array[String] = []
	for raw in biome_pool:
		var biome := str(raw).strip_edges().to_lower()
		if biome != "" and not normalized_pool.has(biome):
			normalized_pool.append(biome)
	if normalized_pool.is_empty():
		normalized_pool = DUNGEON_ROUTE_DEFAULT_BIOMES.duplicate()
	_route_biome_pool = normalized_pool

	_route_segment_min_len = max(1, segment_min_len)
	_route_segment_max_len = max(_route_segment_min_len, segment_max_len)

	if route_seed != 0:
		_route_rng.seed = route_seed
	else:
		_route_rng.randomize()

	boss_system_enabled = true
	biome_progression_order.clear()
	dungeon_route_segments.clear()
	defeated_boss_data.clear()
	_forced_next_biome = ""

	var route_limit: int = max(2, total_floors)
	var segment_limit_floor: int = max(1, route_limit - 1)
	var first_biome := _pick_route_biome(_route_rng, _route_biome_pool, "", preferred_start_biome.strip_edges().to_lower())
	_append_biome_segment(first_biome, 1, segment_limit_floor)

func _pick_route_biome(rng: RandomNumberGenerator, pool: Array[String], previous_biome: String, forced_biome: String) -> String:
	if forced_biome != "":
		return forced_biome
	if pool.is_empty():
		return "gloomrot_catacombs"
	if pool.size() == 1:
		return pool[0]
	var filtered: Array[String] = []
	for biome in pool:
		if biome == previous_biome:
			continue
		filtered.append(biome)
	if filtered.is_empty():
		filtered = pool
	return filtered[rng.randi_range(0, filtered.size() - 1)]

func _append_biome_segment(biome: String, start_floor: int, max_floor_before_endgame: int) -> void:
	if biome == "":
		return
	if start_floor > max_floor_before_endgame:
		return

	var remaining: int = max_floor_before_endgame - start_floor + 1
	var min_len: int = min(_route_segment_min_len, remaining)
	var max_len: int = min(_route_segment_max_len, remaining)
	if min_len > max_len:
		min_len = max_len
	var segment_len: int = max(1, _route_rng.randi_range(min_len, max_len))
	var end_floor: int = min(max_floor_before_endgame, start_floor + segment_len - 1)

	dungeon_route_segments.append({
		"index": dungeon_route_segments.size(),
		"biome": biome,
		"start_floor": start_floor,
		"end_floor": end_floor,
		"boss_floor": end_floor
	})
	biome_progression_order.append(biome)

func _ensure_route_covers_floor(target_floor: int) -> void:
	if not boss_system_enabled:
		return
	if target_floor <= 0:
		return
	if target_floor >= DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT:
		return

	var max_floor_before_endgame := DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT - 1
	var guard := 0
	while guard < 64:
		guard += 1
		var existing: Dictionary = {}
		for raw_segment in dungeon_route_segments:
			var segment: Dictionary = raw_segment if raw_segment is Dictionary else {}
			if segment.is_empty():
				continue
			var start_floor: int = int(segment.get("start_floor", 1))
			var end_floor: int = int(segment.get("end_floor", 1))
			if target_floor >= start_floor and target_floor <= end_floor:
				existing = segment
				break
		if not existing.is_empty():
			return

		var next_start: int = 1
		var previous_biome := ""
		if not dungeon_route_segments.is_empty():
			var last_segment: Dictionary = dungeon_route_segments[dungeon_route_segments.size() - 1]
			next_start = int(last_segment.get("end_floor", 0)) + 1
			previous_biome = str(last_segment.get("biome", ""))
		if next_start > max_floor_before_endgame:
			return

		var forced_choice := _forced_next_biome
		_forced_next_biome = ""
		var next_biome := _pick_route_biome(_route_rng, _route_biome_pool, previous_biome, forced_choice)
		_append_biome_segment(next_biome, next_start, max_floor_before_endgame)

func get_dungeon_segment_for_floor(target_floor: int) -> Dictionary:
	_ensure_route_covers_floor(target_floor)
	for raw_segment in dungeon_route_segments:
		var segment: Dictionary = raw_segment if raw_segment is Dictionary else {}
		if segment.is_empty():
			continue
		var start_floor: int = int(segment.get("start_floor", 1))
		var end_floor: int = int(segment.get("end_floor", 1))
		if target_floor >= start_floor and target_floor <= end_floor:
			return segment
	return {}

func get_dungeon_biome_for_floor(target_floor: int) -> String:
	# Floor 50: Endgame floor (gauntlet + final boss)
	if target_floor == 50:
		return "endgame"
	
	var segment: Dictionary = get_dungeon_segment_for_floor(target_floor)
	return str(segment.get("biome", ""))

func is_dungeon_boss_floor(target_floor: int) -> bool:
	# Dynamic boss system: segment end floors up to 48 plus floor 50 endgame.
	if boss_system_enabled:
		if target_floor >= DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT:
			return true
		var segment: Dictionary = get_dungeon_segment_for_floor(target_floor)
		if segment.is_empty():
			return false
		return target_floor < 49 and target_floor == int(segment.get("end_floor", -1))
	
	# Legacy system
	var legacy_segment: Dictionary = get_dungeon_segment_for_floor(target_floor)
	if legacy_segment.is_empty():
		return target_floor >= DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT
	return target_floor >= int(legacy_segment.get("boss_floor", 1))

func is_gauntlet_floor(target_floor: int) -> bool:
	return boss_system_enabled and target_floor == 50

func is_final_boss_floor(target_floor: int) -> bool:
	return boss_system_enabled and target_floor == 50

func get_next_boss_biome_options(current_biome: String, current_floor: int = -1) -> Array[String]:
	"""Returns 2 weighted biome choices for the next segment after a boss victory."""
	if _route_biome_pool.is_empty():
		return []

	var candidates: Array[String] = _route_biome_pool.duplicate()
	if candidates.size() > 1 and candidates.has(current_biome):
		candidates.erase(current_biome)
	if candidates.is_empty():
		candidates = _route_biome_pool.duplicate()

	var options: Array[String] = []
	while options.size() < 2 and not candidates.is_empty():
		var next_biome: String = _roll_weighted_biome_choice(candidates, current_floor)
		options.append(next_biome)
		candidates.erase(next_biome)

	if options.size() == 1:
		for biome in _route_biome_pool:
			if biome != options[0]:
				options.append(biome)
				break

	return options

func _roll_weighted_biome_choice(candidates: Array[String], current_floor: int) -> String:
	if candidates.is_empty():
		return ""
	if candidates.size() == 1:
		return candidates[0]

	var phase_floor: int = current_floor
	if phase_floor <= 0 and not dungeon_route_segments.is_empty():
		var last_segment: Dictionary = dungeon_route_segments[dungeon_route_segments.size() - 1]
		phase_floor = int(last_segment.get("end_floor", 1))
	phase_floor = clamp(phase_floor, 1, 49)
	var progress: float = float(phase_floor - 1) / 48.0

	var early_focus := {
		"gloomrot_catacombs": 1.40,
		"thornfang_warrens": 1.35,
		"sunforge_basilica": 1.25,
		"skytide_reservoir": 1.20,
		"emberfault_chasm": 0.90,
		"stargrave_observatory": 0.85,
		"ironhowl_bastion": 0.80,
		"echo_vault": 0.75
	}
	var late_focus := {
		"gloomrot_catacombs": 0.75,
		"thornfang_warrens": 0.80,
		"sunforge_basilica": 0.90,
		"skytide_reservoir": 0.95,
		"emberfault_chasm": 1.25,
		"stargrave_observatory": 1.30,
		"ironhowl_bastion": 1.35,
		"echo_vault": 1.40
	}

	var total_weight: float = 0.0
	for biome in candidates:
		var early_w: float = float(early_focus.get(biome, 1.0))
		var late_w: float = float(late_focus.get(biome, 1.0))
		total_weight += lerp(early_w, late_w, progress)

	if total_weight <= 0.0:
		return candidates[_route_rng.randi_range(0, candidates.size() - 1)]

	var roll: float = _route_rng.randf_range(0.0, total_weight)
	var running: float = 0.0
	for biome in candidates:
		var early_w: float = float(early_focus.get(biome, 1.0))
		var late_w: float = float(late_focus.get(biome, 1.0))
		running += lerp(early_w, late_w, progress)
		if roll <= running:
			return biome

	return candidates[candidates.size() - 1]

func set_next_boss_biome_choice(biome: String) -> void:
	var normalized := biome.strip_edges().to_lower()
	if normalized == "":
		return
	if _route_biome_pool.has(normalized):
		_forced_next_biome = normalized

func get_defeated_boss_data() -> Array[Dictionary]:
	"""Returns array of defeated bosses for gauntlet generation"""
	return defeated_boss_data.duplicate()

func add_defeated_boss(boss_data: Dictionary) -> void:
	"""Track defeated boss for gauntlet (floor 49)"""
	if defeated_boss_data.size() < 8:  # Max 8 bosses
		defeated_boss_data.append(boss_data)


func add_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	run_gold += amount

func spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_gold < amount:
		return false
	run_gold -= amount
	return true

func add_soul_essence(amount: int) -> void:
	if amount <= 0:
		return
	soul_essence += amount

func spend_soul_essence(amount: int) -> bool:
	if amount <= 0:
		return true
	if soul_essence < amount:
		return false
	soul_essence -= amount
	return true

func get_meta_unlock_level(unlock_id: String) -> int:
	if unlock_id == "":
		return 0
	return int(meta_unlocks.get(unlock_id, 0))

func has_meta_unlock(unlock_id: String) -> bool:
	return get_meta_unlock_level(unlock_id) > 0

func buy_meta_unlock(unlock_id: String, cost: int, max_level: int = 1) -> bool:
	if unlock_id == "":
		return false
	if cost < 0:
		return false
	var current_level: int = get_meta_unlock_level(unlock_id)
	if current_level >= max(1, max_level):
		return false
	if not spend_soul_essence(cost):
		return false
	meta_unlocks[unlock_id] = current_level + 1
	return true

func _is_valid_item_id(item_id: String) -> bool:
	return item_id != "" and _item_db.has_item(item_id)
