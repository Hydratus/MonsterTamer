extends RefCounted
class_name MTDungeonNPCSpawnHelper

const NPCDataClass = preload("res://core/world/npc_data.gd")
const NPCMonsterEntryClass = preload("res://core/world/npc_monster_entry.gd")
const ITEM_DB_CLASS = preload("res://core/items/item_db.gd")

const INVALID_CELL := Vector2i(-1, -1)

static func _is_invalid_cell(cell: Vector2i) -> bool:
	return cell == INVALID_CELL

static func spawn_floor_npcs(owner) -> void:
	clear_dynamic_npcs(owner)
	if owner._floor_cells.size() < 8:
		return

	var valid_spawn_cells: int = 0
	for cell in owner._floor_cells:
		if is_safe_npc_spawn_cell(owner, cell) and not is_chokepoint_cell(owner, cell):
			valid_spawn_cells += 1
	owner._log_dungeon("[Dungeon] npc_spawn candidates=%d floor_cells=%d rooms=%d corridors=%d" % [
		valid_spawn_cells, owner._floor_cells.size(), owner._room_cells_lookup.size(), owner._corridor_cells_lookup.size()])

	var reserved: Dictionary = {}
	reserved[owner._player_spawn_cell] = true
	if owner._stairs_npc != null and owner._stairs_npc.visible:
		reserved[owner._world_to_cell(owner._stairs_npc.global_position)] = true
	if owner._boss_npc != null and owner._boss_npc.visible:
		reserved[owner._world_to_cell(owner._boss_npc.global_position)] = true
	spawn_elite_room_npc(owner, reserved)
	spawn_mimic_npc(owner, reserved)
	spawn_puzzle_switches(owner, reserved)
	spawn_key_npc(owner, reserved)
	spawn_event_object(owner, reserved)
	spawn_loose_items(owner, reserved)
	spawn_secret_vault(owner, reserved)

static func spawn_event_object(owner, reserved: Dictionary) -> void:
	if owner.current_floor >= owner.floor_count:
		return
	if owner._rng.randf() > clamp(owner.event_object_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = pick_normal_room_index(owner)
	if room_index < 0:
		return
	var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
	if _is_invalid_cell(cell):
		return
	reserved[cell] = true
	var event_type: int = owner._rng.randi_range(0, 6)
	var event_data: MTNPCData
	match event_type:
		0:
			event_data = create_healing_spring_npc_data()
		1:
			event_data = create_gold_stash_npc_data()
		2:
			event_data = create_essence_cache_npc_data()
		3:
			event_data = create_status_trap_npc_data()
		4:
			event_data = create_merchant_cache_npc_data()
		5:
			event_data = create_monster_egg_npc_data()
		_:
			event_data = create_cursed_altar_npc_data()
	spawn_dynamic_npc(owner, cell, event_data)
	owner._log_dungeon("[Dungeon] event object spawned type=%d cell=%s" % [event_type, str(cell)])

static func spawn_loose_items(owner, reserved: Dictionary) -> void:
	var count: int = owner._rng.randi_range(0, owner.loose_item_max_count)
	for _i in range(count):
		var room_index: int = pick_normal_room_index(owner)
		if room_index < 0:
			break
		var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
		if _is_invalid_cell(cell):
			continue
		reserved[cell] = true
		var item_id: String = owner._pick_or_create_random_item()
		spawn_dynamic_npc(owner, cell, create_loose_item_npc_data(item_id))
	if count > 0:
		owner._log_dungeon("[Dungeon] loose items spawned count=%d" % count)

static func spawn_secret_vault(owner, reserved: Dictionary) -> void:
	if owner.current_floor >= owner.floor_count:
		return
	if owner._rng.randf() > clamp(owner.secret_vault_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = pick_normal_room_index(owner)
	if room_index < 0:
		return
	var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
	if _is_invalid_cell(cell):
		return
	reserved[cell] = true
	spawn_dynamic_npc(owner, cell, create_secret_vault_npc_data())
	owner._log_dungeon("[Dungeon] secret vault spawned cell=%s" % str(cell))

static func spawn_elite_room_npc(owner, reserved: Dictionary) -> void:
	if owner._current_floor_goal != owner.FLOOR_GOAL_TYPE.ELITE:
		owner._elite_cleared_this_floor = true
		return
	if owner.current_floor >= owner.floor_count:
		owner._elite_cleared_this_floor = true
		owner._log_dungeon("[Dungeon] elite disabled on boss floor")
		return
	if owner._elite_room_index < 0 or owner._elite_room_index >= owner._room_rects.size():
		owner._elite_cleared_this_floor = true
		return
	var cell: Vector2i = pick_cell_in_room(owner, owner._elite_room_index, reserved)
	if _is_invalid_cell(cell):
		owner._elite_cleared_this_floor = true
		owner._log_dungeon("[Dungeon] elite room has no valid spawn cell; unlocking stairs")
		return
	reserved[cell] = true
	spawn_dynamic_npc(owner, cell, create_elite_npc_data(owner))
	owner._elite_cleared_this_floor = false

static func spawn_mimic_npc(owner, reserved: Dictionary) -> void:
	if owner.current_floor < owner.mimic_min_floor:
		return
	if owner._rng.randf() > clamp(owner.mimic_spawn_chance, 0.0, 1.0):
		return
	var room_index: int = pick_normal_room_index(owner)
	if room_index < 0:
		return
	var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
	if _is_invalid_cell(cell):
		return
	reserved[cell] = true
	spawn_dynamic_npc(owner, cell, create_mimic_npc_data(owner))
	owner._log_dungeon("[Dungeon] mimic spawned room=%d cell=%s" % [room_index, str(cell)])

static func spawn_puzzle_switches(owner, reserved: Dictionary) -> void:
	if owner._current_floor_goal != owner.FLOOR_GOAL_TYPE.PUZZLE:
		return
	if owner._switches_total <= 0:
		return
	for i in range(owner._switches_total):
		var room_index: int = pick_normal_room_index(owner)
		if room_index < 0:
			owner._log_dungeon("[Dungeon] puzzle: no valid room for switch %d" % (i + 1))
			continue
		var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
		if _is_invalid_cell(cell):
			owner._log_dungeon("[Dungeon] puzzle: no valid cell in room %d for switch %d" % [room_index, i + 1])
			continue
		reserved[cell] = true
		var switch_data: MTNPCData = create_puzzle_switch_npc_data(i + 1)
		spawn_dynamic_npc(owner, cell, switch_data)
		owner._log_dungeon("[Dungeon] puzzle switch %d spawned at cell=%s" % [i + 1, str(cell)])

static func spawn_key_npc(owner, reserved: Dictionary) -> void:
	if owner._current_floor_goal != owner.FLOOR_GOAL_TYPE.KEY:
		return
	var room_index: int = pick_normal_room_index(owner)
	if room_index < 0:
		owner._log_dungeon("[Dungeon] key: no valid room found")
		return
	var cell: Vector2i = pick_cell_in_room(owner, room_index, reserved)
	if _is_invalid_cell(cell):
		owner._log_dungeon("[Dungeon] key: no valid cell in room %d" % room_index)
		return
	reserved[cell] = true
	spawn_dynamic_npc(owner, cell, create_key_npc_data())
	owner._log_dungeon("[Dungeon] key spawned at cell=%s in room=%d" % [str(cell), room_index])

static func pick_normal_room_index(owner) -> int:
	var candidates: Array[int] = []
	for i in range(owner._room_rects.size()):
		var room_type: String = str(owner._room_type_by_index.get(i, owner.ROOM_TYPE_NORMAL))
		if room_type != owner.ROOM_TYPE_NORMAL:
			continue
		candidates.append(i)
	if candidates.is_empty():
		return -1
	return int(candidates[owner._rng.randi_range(0, candidates.size() - 1)])

static func pick_cell_in_room(owner, room_index: int, reserved: Dictionary) -> Vector2i:
	if room_index < 0 or room_index >= owner._room_rects.size():
		return INVALID_CELL
	var room: Rect2i = owner._room_rects[room_index]
	var candidates: Array[Vector2i] = []
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			var cell := Vector2i(x, y)
			if reserved.has(cell):
				continue
			if not is_safe_npc_spawn_cell(owner, cell):
				continue
			if is_chokepoint_cell(owner, cell):
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return INVALID_CELL
	return candidates[owner._rng.randi_range(0, candidates.size() - 1)]

static func spawn_dynamic_npc(owner, cell: Vector2i, npc_data: MTNPCData) -> void:
	var template = owner._stairs_npc if owner._stairs_npc != null else owner._boss_npc
	if template == null:
		return
	var npc = template.duplicate()
	npc.name = "FloorNPC_%d" % (owner._dynamic_npcs.size() + 1)
	npc.npc_data = npc_data
	npc.visible = true
	npc.set_process(true)
	npc.set_physics_process(true)
	owner.add_child(npc)
	npc.global_position = owner._cell_to_world(cell)
	if npc.npc_data != null:
		var interaction: String = str(npc.npc_data.interaction_id)
		if interaction == "elite_pack":
			npc.modulate = Color(1.0, 0.8, 0.5, 1.0)
		elif interaction == "mimic_pack":
			npc.modulate = Color(0.8, 1.0, 0.7, 1.0)
	if npc.has_method("set_tile_layer"):
		npc.set_tile_layer(owner._grass_layer)
	owner._dynamic_npcs.append(npc)
	owner._npcs.append(npc)

static func clear_dynamic_npcs(owner) -> void:
	for npc in owner._dynamic_npcs:
		if npc == null:
			continue
		owner._npcs.erase(npc)
		npc.queue_free()
	owner._dynamic_npcs.clear()

static func create_battle_npc_data(owner, index: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Wanderer %d") % index
	data.dialogue_before = TranslationServer.translate("The dungeon belongs to the strongest.")
	data.battle_once = true
	data.walk_enabled = false
	var team_size: int = 1 if owner.current_floor < 3 else 2
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = pick_monster_for_habitat(owner)
		entry.level = max(2, owner.current_floor * 2 + owner._rng.randi_range(0, 2))
		data.team_entries.append(entry)
	return data

static func create_item_npc_data(owner, index: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Explorer %d") % index
	data.dialogue_before = TranslationServer.translate("Found this on this floor. Take it.")
	data.gives_items = true
	data.give_item_amount = 1
	data.battle_once = true
	data.walk_enabled = false
	if not owner.item_reward_pool.is_empty():
		var item_db = owner.ITEM_DB_CLASS.new()
		var valid_ids: Array[String] = item_db.filter_valid_item_ids(owner.item_reward_pool)
		if not valid_ids.is_empty():
			var item_id: String = valid_ids[owner._rng.randi_range(0, valid_ids.size() - 1)]
			data.give_item_ids = [item_id]
	return data

static func create_elite_npc_data(owner) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Elite")
	data.dialogue_before = TranslationServer.translate("A concentrated pack of wild monsters surrounds you.")
	data.dialogue_after = TranslationServer.translate("The elite pack has been defeated.")
	data.interaction_id = "elite_pack"
	data.battle_once = true
	data.walk_enabled = false
	var team_size: int = min(5, 1 + int(owner.current_floor / 5.0))
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = pick_monster_for_habitat(owner)
		entry.level = max(3, owner.current_floor * 2 + 3 + owner._rng.randi_range(0, 2))
		data.team_entries.append(entry)
	return data

static func create_mimic_npc_data(owner) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Mimic")
	data.dialogue_before = TranslationServer.translate("A lonely chest twitches... it was bait!")
	data.dialogue_after = TranslationServer.translate("The mimic vanishes into the shadows.")
	data.interaction_id = "mimic_pack"
	data.battle_once = true
	data.walk_enabled = false
	var team_size: int = 1 if owner.current_floor < 4 else 2
	for _i in range(team_size):
		var entry := NPCMonsterEntryClass.new()
		entry.monster_data = pick_monster_for_habitat(owner)
		entry.level = max(4, owner.current_floor * 2 + 4 + owner._rng.randi_range(0, 3))
		data.team_entries.append(entry)
	return data

static func create_puzzle_switch_npc_data(switch_number: int) -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Switch %d") % switch_number
	data.dialogue_before = TranslationServer.translate("You activate the switch. A mechanism clicks into place.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_switch_%d" % switch_number
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_key_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Glowing Key")
	data.dialogue_before = TranslationServer.translate("You pick up the ancient key. It glows with power.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_key"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_healing_spring_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Healing Spring")
	data.dialogue_before = TranslationServer.translate("A bubbling spring glows with restorative energy. (Restores HP and Energy once)")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_healing_spring"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_gold_stash_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Gold Chest")
	data.dialogue_before = TranslationServer.translate("A dusty chest rests here, filled with coins!")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_gold_stash"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_essence_cache_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Soul Essence Cache")
	data.dialogue_before = TranslationServer.translate("A crystalline orb pulses with condensed Soul Essence.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_essence_cache"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_status_trap_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Suspicious Rune")
	data.dialogue_before = TranslationServer.translate("Strange runes glow on the floor here... (Possible trap!)")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_status_trap"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_merchant_cache_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Hidden Merchant Cache")
	data.dialogue_before = TranslationServer.translate("A small supply cache has been left behind by a passing merchant.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_merchant_cache"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_monster_egg_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Monster Egg")
	data.dialogue_before = TranslationServer.translate("A warm egg rests here. Something stirs inside...")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_monster_egg"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_cursed_altar_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Cursed Altar")
	data.dialogue_before = TranslationServer.translate("A dark altar radiates power. Risk your team's health for rewards?")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_cursed_altar"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_loose_item_npc_data(item_id: String) -> MTNPCData:
	var data := NPCDataClass.new()
	var item_data = ITEM_DB_CLASS.new().get_item(item_id)
	data.display_name = item_data.name if item_data != null else item_id
	data.dialogue_before = TranslationServer.translate("You find %s lying on the ground.") % (item_data.name if item_data != null else item_id)
	data.dialogue_after = ""
	data.interaction_id = "dungeon_loose_item:" + item_id
	data.battle_once = false
	data.walk_enabled = false
	return data

static func create_secret_vault_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Secret Vault")
	data.dialogue_before = TranslationServer.translate("A heavy iron vault. This requires a Secret Key to open.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_secret_vault"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func pick_monster_for_habitat(owner) -> MTMonsterData:
	var paths: Array[String] = owner._get_habitat_monster_paths()
	if paths.is_empty():
		return load("res://data/monsters/slime/slime.tres") as MTMonsterData
	var path: String = paths[owner._rng.randi_range(0, paths.size() - 1)]
	var result := load(path) as MTMonsterData
	if result != null:
		return result
	return load("res://data/monsters/slime/slime.tres") as MTMonsterData

static func pick_free_floor_cell(owner, reserved: Dictionary) -> Vector2i:
	if owner._floor_cells.is_empty():
		return INVALID_CELL
	for _i in range(200):
		var cell: Vector2i = owner._floor_cells[owner._rng.randi_range(0, owner._floor_cells.size() - 1)]
		if reserved.has(cell):
			continue
		if not is_safe_npc_spawn_cell(owner, cell):
			continue
		if is_chokepoint_cell(owner, cell):
			continue
		return cell
	return INVALID_CELL

static func is_safe_npc_spawn_cell(owner, cell: Vector2i) -> bool:
	if not owner._room_cells_lookup.has(cell):
		return false
	for y in range(-1, 2):
		for x in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var n := cell + Vector2i(x, y)
			if owner._corridor_cells_lookup.has(n):
				return false
	return true

static func is_chokepoint_cell(owner, cell: Vector2i) -> bool:
	var n: int = 0
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if owner._has_tile(owner._dirt_layer, cell + dir):
			n += 1
	return n <= 1
