extends Node

const TEAM_SIZE_CAP := 5  # See GameBalanceConstants.TEAM_SIZE_CAP
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT := 50
const DUNGEON_ROUTE_MIN_SEGMENT_LEN_DEFAULT := 7
const DUNGEON_ROUTE_MAX_SEGMENT_LEN_DEFAULT := 15
const DUNGEON_ROUTE_DEFAULT_BIOMES: Array[String] = ["cavern", "forest", "ruins", "swamp"]

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

func clear_dungeon_route() -> void:
	dungeon_route_segments.clear()

func setup_dungeon_route(
	total_floors: int,
	biome_pool: Array[String],
	preferred_start_biome: String = "",
	min_segment_len: int = DUNGEON_ROUTE_MIN_SEGMENT_LEN_DEFAULT,
	max_segment_len: int = DUNGEON_ROUTE_MAX_SEGMENT_LEN_DEFAULT,
	route_seed: int = 0
) -> void:
	var target_total: int = max(1, total_floors)
	var seg_min: int = max(1, min_segment_len)
	var seg_max: int = max(seg_min, max_segment_len)
	if seg_min > target_total:
		seg_min = target_total
	if seg_max > target_total:
		seg_max = target_total

	var pool: Array[String] = []
	for raw in biome_pool:
		var biome := str(raw).strip_edges().to_lower()
		if biome == "":
			continue
		if not pool.has(biome):
			pool.append(biome)
	if pool.is_empty():
		pool = DUNGEON_ROUTE_DEFAULT_BIOMES.duplicate()

	var rng := RandomNumberGenerator.new()
	if route_seed != 0:
		rng.seed = route_seed
	else:
		rng.randomize()

	var min_segments: int = int(ceil(float(target_total) / float(seg_max)))
	var max_segments: int = int(floor(float(target_total) / float(seg_min)))
	if max_segments < min_segments:
		max_segments = min_segments
	var segment_count: int = rng.randi_range(min_segments, max_segments)

	var lengths: Array[int] = []
	for _i in range(segment_count):
		lengths.append(seg_min)
	var remaining: int = target_total - segment_count * seg_min

	for i in range(segment_count):
		if remaining <= 0:
			break
		var capacity: int = seg_max - lengths[i]
		if capacity <= 0:
			continue
		var add: int = rng.randi_range(0, min(capacity, remaining))
		lengths[i] += add
		remaining -= add

	while remaining > 0:
		for i in range(segment_count):
			if remaining <= 0:
				break
			if lengths[i] >= seg_max:
				continue
			lengths[i] += 1
			remaining -= 1

	for i in range(lengths.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = lengths[i]
		lengths[i] = lengths[j]
		lengths[j] = tmp

	dungeon_route_segments.clear()
	var floor_cursor: int = 1
	var previous_biome := ""
	for i in range(lengths.size()):
		var forced_biome := ""
		if i == 0:
			forced_biome = preferred_start_biome.strip_edges().to_lower()
		var biome: String = _pick_route_biome(rng, pool, previous_biome, forced_biome)
		var seg_len: int = lengths[i]
		var start_floor: int = floor_cursor
		var end_floor: int = start_floor + seg_len - 1
		dungeon_route_segments.append({
			"index": i,
			"biome": biome,
			"start_floor": start_floor,
			"end_floor": end_floor,
			"boss_floor": end_floor
		})
		previous_biome = biome
		floor_cursor = end_floor + 1

func _pick_route_biome(rng: RandomNumberGenerator, pool: Array[String], previous_biome: String, forced_biome: String) -> String:
	if forced_biome != "":
		return forced_biome
	if pool.is_empty():
		return "cavern"
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

func get_dungeon_segment_for_floor(target_floor: int) -> Dictionary:
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
	var segment: Dictionary = get_dungeon_segment_for_floor(target_floor)
	return str(segment.get("biome", ""))

func is_dungeon_boss_floor(target_floor: int) -> bool:
	var segment: Dictionary = get_dungeon_segment_for_floor(target_floor)
	if segment.is_empty():
		return target_floor >= DUNGEON_ROUTE_TOTAL_FLOORS_DEFAULT
	return target_floor >= int(segment.get("boss_floor", 1))

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
