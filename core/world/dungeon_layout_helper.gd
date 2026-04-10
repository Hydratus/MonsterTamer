extends RefCounted
class_name MTDungeonLayoutHelper

static func _room_count(owner) -> int:
	return owner._room_rects.size()

static func _is_valid_room_index(owner, index: int) -> bool:
	return index >= 0 and index < _room_count(owner)

static func generate_floor_layout(owner) -> void:
	if owner.generation_seed > 0:
		owner._rng.seed = int(owner.generation_seed + owner.current_floor * 104729)
	elif owner._layout_seed > 0:
		# Reuse the saved seed so that calling _apply_floor_rules a second time
		# (from apply_world_payload) produces the exact same layout.
		owner._rng.seed = owner._layout_seed
	else:
		owner._rng.randomize()
		owner._layout_seed = owner._rng.seed

	owner._room_rects.clear()
	owner._room_cells_lookup.clear()
	owner._corridor_cells_lookup.clear()
	owner._room_type_by_index.clear()
	owner._room_index_by_cell.clear()
	owner._visited_room_indices.clear()
	owner._elite_room_index = -1
	owner._event_room_index = -1
	owner._elite_cleared_this_floor = false
	owner._reset_floor_quest_state()
	owner._log_dungeon("[Dungeon] generating floor %d/%d  seed=%d" % [owner.current_floor, owner.floor_count, owner._rng.seed])

	var carved: Dictionary = {}
	var target_rooms: int = owner._rng.randi_range(owner.min_room_count, owner.max_room_count)
	var attempts: int = target_rooms * 24

	for _i in range(attempts):
		if _room_count(owner) >= target_rooms:
			break
		var room_w: int = owner._rng.randi_range(owner.min_room_size, owner.max_room_size)
		var room_h: int = owner._rng.randi_range(owner.min_room_size, owner.max_room_size)
		var room_x: int = owner._rng.randi_range(2, max(2, owner.map_width - room_w - 3))
		var room_y: int = owner._rng.randi_range(2, max(2, owner.map_height - room_h - 3))
		var room := Rect2i(room_x, room_y, room_w, room_h)
		if room_intersects_existing(owner, room):
			continue
		owner._room_rects.append(room)
		carve_room(owner, room, carved)

	if _room_count(owner) == 0:
		var fx: int = max(2, int(owner.map_width / 2.0) - 3)
		var fy: int = max(2, int(owner.map_height / 2.0) - 3)
		var fallback := Rect2i(fx, fy, 6, 6)
		owner._room_rects.append(fallback)
		carve_room(owner, fallback, carved)

	for i in range(1, _room_count(owner)):
		carve_corridor(owner, room_center(owner._room_rects[i - 1]), room_center(owner._room_rects[i]), carved)
	build_room_index_lookup(owner)

	owner._floor_cells.clear()
	for cell_key in carved.keys():
		owner._floor_cells.append(cell_key)
	owner._log_dungeon("[Dungeon] %d rooms  %d floor cells" % [_room_count(owner), owner._floor_cells.size()])

static func room_intersects_existing(owner, candidate: Rect2i) -> bool:
	for room in owner._room_rects:
		var expanded := Rect2i(room.position - Vector2i.ONE, room.size + Vector2i(2, 2))
		if expanded.intersects(candidate):
			return true
	return false

static func carve_room(owner, room: Rect2i, carved: Dictionary) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			var cell := Vector2i(x, y)
			carved[cell] = true
			owner._room_cells_lookup[cell] = true
			if owner._corridor_cells_lookup.has(cell):
				owner._corridor_cells_lookup.erase(cell)

static func carve_corridor(owner, start: Vector2i, target: Vector2i, carved: Dictionary) -> void:
	var current := start
	var room_lookup: Dictionary = owner._room_cells_lookup
	var corridor_lookup: Dictionary = owner._corridor_cells_lookup
	while current.x != target.x:
		carved[current] = true
		if not room_lookup.has(current):
			corridor_lookup[current] = true
		current.x += 1 if target.x > current.x else -1
	while current.y != target.y:
		carved[current] = true
		if not room_lookup.has(current):
			corridor_lookup[current] = true
		current.y += 1 if target.y > current.y else -1
	carved[target] = true
	if not room_lookup.has(target):
		corridor_lookup[target] = true

static func room_center(room: Rect2i) -> Vector2i:
	return Vector2i(
		room.position.x + int(room.size.x / 2.0),
		room.position.y + int(room.size.y / 2.0)
	)

static func build_room_index_lookup(owner) -> void:
	owner._room_index_by_cell.clear()
	for i in range(_room_count(owner)):
		var room: Rect2i = owner._room_rects[i]
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				owner._room_index_by_cell[Vector2i(x, y)] = i

static func assign_room_roles(owner) -> void:
	owner._room_type_by_index.clear()
	if _room_count(owner) == 0:
		return
	for i in range(_room_count(owner)):
		owner._room_type_by_index[i] = owner.ROOM_TYPE_NORMAL

	var start_index := 0
	var exit_index := get_farthest_room_index(owner, start_index)
	owner._room_type_by_index[start_index] = owner.ROOM_TYPE_START
	owner._room_type_by_index[exit_index] = owner.ROOM_TYPE_EXIT

	var candidates: Array[int] = []
	for i in range(_room_count(owner)):
		if i == start_index or i == exit_index:
			continue
		candidates.append(i)
	if candidates.is_empty():
		owner._log_dungeon("[Dungeon] room roles: only start/exit available")
		return

	var candidate_distances: Dictionary = {}
	for idx in candidates:
		candidate_distances[idx] = room_distance(owner, start_index, idx)
	candidates.sort_custom(func(a: int, b: int):
		return int(candidate_distances.get(a, 0)) > int(candidate_distances.get(b, 0))
	)

	owner._elite_room_index = -1
	if owner.current_floor < owner.floor_count and owner._current_floor_goal == owner.FLOOR_GOAL_TYPE.ELITE:
		owner._elite_room_index = candidates[0]
		owner._room_type_by_index[owner._elite_room_index] = owner.ROOM_TYPE_ELITE

	owner._log_dungeon("[Dungeon] room roles start=%d exit=%d elite=%d" % [
		start_index, exit_index, owner._elite_room_index])

static func assign_floor_goals(owner) -> void:
	owner._floor_goal_state.clear()
	owner._switches_total = 0
	owner._switches_activated = 0
	owner._key_found_this_floor = false
	owner._elite_cleared_this_floor = true

	if owner.current_floor >= owner.floor_count:
		owner._current_floor_goal = owner.FLOOR_GOAL_TYPE.OPEN
		owner._log_dungeon("[Dungeon] floor goal=OPEN (boss floor)")
		return

	var roll: int = owner._rng.randi_range(0, 99)
	var cumulative: int = 0

	if roll < cumulative + owner.goal_prob_open:
		owner._current_floor_goal = owner.FLOOR_GOAL_TYPE.OPEN
		owner._log_dungeon("[Dungeon] floor goal=OPEN")
		return
	cumulative += owner.goal_prob_open

	if roll < cumulative + owner.goal_prob_elite:
		owner._current_floor_goal = owner.FLOOR_GOAL_TYPE.ELITE
		owner._log_dungeon("[Dungeon] floor goal=ELITE")
		return
	cumulative += owner.goal_prob_elite

	if roll < cumulative + owner.goal_prob_key:
		owner._current_floor_goal = owner.FLOOR_GOAL_TYPE.KEY
		owner._floor_goal_state["key_found"] = false
		owner._log_dungeon("[Dungeon] floor goal=KEY")
		return

	owner._current_floor_goal = owner.FLOOR_GOAL_TYPE.PUZZLE
	owner._switches_total = 3
	owner._switches_activated = 0
	owner._floor_goal_state["switches_activated"] = 0
	owner._floor_goal_state["switches_total"] = 3
	owner._log_dungeon("[Dungeon] floor goal=PUZZLE switches_total=3")

static func get_farthest_room_index(owner, origin_index: int) -> int:
	if _room_count(owner) == 0:
		return 0
	var oi: int = clampi(origin_index, 0, _room_count(owner) - 1)
	var origin: Vector2i = room_center(owner._room_rects[oi])
	var best_index: int = oi
	var best_dist: int = -1
	for i in range(_room_count(owner)):
		var center := room_center(owner._room_rects[i])
		var dist: int = abs(center.x - origin.x) + abs(center.y - origin.y)
		if dist > best_dist:
			best_dist = dist
			best_index = i
	return best_index

static func room_distance(owner, a_index: int, b_index: int) -> int:
	if not _is_valid_room_index(owner, a_index):
		return 0
	if not _is_valid_room_index(owner, b_index):
		return 0
	var a := room_center(owner._room_rects[a_index])
	var b := room_center(owner._room_rects[b_index])
	return abs(a.x - b.x) + abs(a.y - b.y)
