extends RefCounted
class_name MTDungeonSmokeTests

const GameClass = preload("res://globals/game.gd")
const ItemDBClass = preload("res://core/items/item_db.gd")
const DungeonSceneScript = preload("res://core/world/dungeon_scene.gd")
const NPCTest2Data = preload("res://data/npc/NPCTest2.tres")
const ItemMenuClass = preload("res://ui/menus/item_menu.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

class _BossNpcStub:
	extends RefCounted
	var npc_data: MTNPCData

class _BossTrackGameStub:
	extends RefCounted
	var tracked_bosses: Array[Dictionary] = []

	func add_defeated_boss(boss_data: Dictionary) -> void:
		tracked_bosses.append(boss_data)

class _PortalChoiceGameStub:
	extends RefCounted
	var chosen_biome: String = ""

	func set_next_boss_biome_choice(biome: String) -> void:
		chosen_biome = biome

class _PortalNpcStub:
	extends Node2D
	var npc_data: MTNPCData
	var spawned_cell: Vector2i = Vector2i.ZERO

	func get_cell(_layer = null) -> Vector2i:
		return spawned_cell

class _TestDungeonScene:
	extends "res://core/world/dungeon_scene.gd"
	var injected_game: RefCounted = null

	func _get_game():
		return injected_game

	func _log_dungeon(_message: String) -> void:
		# Silence logs for this isolated unit-level smoke test.
		pass

class _TestDungeonPortalScene:
	extends "res://core/world/dungeon_scene.gd"
	var injected_game: RefCounted = null

	func _get_game():
		return injected_game

	func _log_dungeon(_message: String) -> void:
		pass

	func _enqueue_message(_text: String) -> void:
		# Skip UI message plumbing in isolated test context.
		pass

	func _is_cell_walkable(_cell: Vector2i) -> bool:
		return true

	func _spawn_dynamic_npc(cell: Vector2i, npc_data: MTNPCData) -> void:
		var npc := _PortalNpcStub.new()
		npc.npc_data = npc_data
		npc.spawned_cell = cell
		_dynamic_npcs.append(npc)
		_npcs.append(npc)

static func run_all() -> Dictionary:
	var results: Dictionary = {
		"floor_49_is_not_boss_floor": _test_floor_49_is_not_boss_floor(),
		"floor_50_is_endgame_boss_floor": _test_floor_50_is_endgame_boss_floor(),
		"floor_49_has_regular_segment": _test_floor_49_has_regular_segment(),
		"floor_50_biome_is_endgame": _test_floor_50_biome_is_endgame(),
		"segment_boss_boundaries_under_49": _test_segment_boss_boundaries_under_49(),
		"portal_options_are_valid_and_distinct": _test_portal_options_are_valid_and_distinct(),
		"portal_options_with_tiny_biome_pool": _test_portal_options_with_tiny_biome_pool(),
		"portal_weighting_shifts_early_to_late": _test_portal_weighting_shifts_early_to_late(),
		"forced_portal_choice_applies_to_next_segment": _test_forced_portal_choice_applies_to_next_segment(),
		"dungeon_default_item_pools_are_valid": _test_dungeon_default_item_pools_are_valid(),
		"npc_test_item_ids_are_valid": _test_npc_test_item_ids_are_valid(),
		"item_menu_input_lock_flag_roundtrip": _test_item_menu_input_lock_flag_roundtrip(),
		"boss_portal_npcs_spawn_and_clear_on_interaction": _test_boss_portal_npcs_spawn_and_clear_on_interaction(),
		"track_defeated_boss_uses_monster_name": _test_track_defeated_boss_uses_monster_name(),
		"track_defeated_boss_preserves_existing_name": _test_track_defeated_boss_preserves_existing_name()
	}
	return _finalize_results(results)

static func _finalize_results(results: Dictionary) -> Dictionary:
	var all_passed := true
	for key in results.keys():
		if not bool(results[key]):
			all_passed = false
			break
	results["all_passed"] = all_passed
	return results

static func _test_floor_49_is_not_boss_floor() -> bool:
	var game := _create_game_with_seed(1337)
	var is_boss_49: bool = bool(game.is_dungeon_boss_floor(49))
	return _expect(not is_boss_49, "Floor 49 must remain a normal floor (not a boss floor).")

static func _test_floor_50_is_endgame_boss_floor() -> bool:
	var game := _create_game_with_seed(1337)
	var boss_50: bool = bool(game.is_dungeon_boss_floor(50))
	var gauntlet_50: bool = bool(game.is_gauntlet_floor(50))
	var final_50: bool = bool(game.is_final_boss_floor(50))
	return _expect(boss_50 and gauntlet_50 and final_50, "Floor 50 must be boss+gauntlet+final floor.")

static func _test_floor_49_has_regular_segment() -> bool:
	var game := _create_game_with_seed(7331)
	var segment: Dictionary = game.get_dungeon_segment_for_floor(49)
	var biome: String = str(game.get_dungeon_biome_for_floor(49))
	var valid_segment: bool = not segment.is_empty()
	var biome_ok: bool = biome != "" and biome != "endgame"
	var regular_floor: bool = not bool(game.is_dungeon_boss_floor(49))
	return _expect(valid_segment and biome_ok and regular_floor, "Floor 49 should have a normal biome segment and be encounter-eligible.")

static func _test_floor_50_biome_is_endgame() -> bool:
	var game := _create_game_with_seed(7331)
	var biome_50: String = str(game.get_dungeon_biome_for_floor(50))
	var biome_49: String = str(game.get_dungeon_biome_for_floor(49))
	return _expect(biome_50 == "endgame" and biome_49 != "endgame", "Floor 50 biome must be endgame while floor 49 remains a normal biome.")

static func _test_segment_boss_boundaries_under_49() -> bool:
	var game := _create_game_with_seed(2026)
	var segments: Array = game.dungeon_route_segments
	if segments.is_empty():
		return _expect(false, "Expected generated route segments for boss-boundary test.")

	for raw_segment in segments:
		var segment: Dictionary = raw_segment if raw_segment is Dictionary else {}
		if segment.is_empty():
			continue
		var start_floor: int = int(segment.get("start_floor", 1))
		var end_floor: int = int(segment.get("end_floor", start_floor))

		if end_floor < 49:
			if not bool(game.is_dungeon_boss_floor(end_floor)):
				return _expect(false, "Segment end floor below 49 must be a boss floor.")

		if start_floor < end_floor:
			var interior_floor: int = start_floor
			if bool(game.is_dungeon_boss_floor(interior_floor)):
				return _expect(false, "Interior segment floor must not be marked as boss floor.")

	return _expect(true, "Segment boss boundaries under floor 49 are correct.")

static func _test_portal_options_are_valid_and_distinct() -> bool:
	var game := _create_game_with_seed(4242)
	var current_biome := "gloomrot_catacombs"
	var options: Array[String] = game.get_next_boss_biome_options(current_biome, 21)

	if options.size() != 2:
		return _expect(false, "Portal options must return exactly two biome choices.")
	if options[0] == options[1]:
		return _expect(false, "Portal options must be distinct.")
	if options.has(current_biome):
		return _expect(false, "Portal options must not include the current biome when alternatives exist.")

	var pool: Array[String] = game._route_biome_pool
	var valid: bool = pool.has(options[0]) and pool.has(options[1])
	return _expect(valid, "Portal options must come from the route biome pool.")

static func _test_portal_options_with_tiny_biome_pool() -> bool:
	var game := GameClass.new()
	var tiny_pool: Array[String] = ["gloomrot_catacombs", "echo_vault"]
	game.setup_dungeon_route_with_boss_system(50, tiny_pool, "gloomrot_catacombs", 31337, 7, 15)

	var options: Array[String] = game.get_next_boss_biome_options("gloomrot_catacombs", 21)
	if options.size() != 2:
		return _expect(false, "Tiny biome pool should still produce two portal options.")

	var in_pool: bool = tiny_pool.has(options[0]) and tiny_pool.has(options[1])
	var distinct: bool = options[0] != options[1]
	return _expect(in_pool and distinct, "Tiny biome pool portal options must be distinct and in-pool.")

static func _test_portal_weighting_shifts_early_to_late() -> bool:
	var game := _create_game_with_seed(9898)
	var candidates: Array[String] = ["gloomrot_catacombs", "echo_vault"]

	var early_counts := {"gloomrot_catacombs": 0, "echo_vault": 0}
	for i in range(400):
		var rolled_early: String = game._roll_weighted_biome_choice(candidates, 1)
		early_counts[rolled_early] = int(early_counts.get(rolled_early, 0)) + 1

	var late_counts := {"gloomrot_catacombs": 0, "echo_vault": 0}
	for j in range(400):
		var rolled_late: String = game._roll_weighted_biome_choice(candidates, 49)
		late_counts[rolled_late] = int(late_counts.get(rolled_late, 0)) + 1

	var early_prefers_gloomrot: bool = int(early_counts["gloomrot_catacombs"]) > int(early_counts["echo_vault"])
	var late_prefers_echo: bool = int(late_counts["echo_vault"]) > int(late_counts["gloomrot_catacombs"])
	return _expect(early_prefers_gloomrot and late_prefers_echo, "Weighted portal picks should favor early biomes at floor 1 and late biomes at floor 49.")

static func _test_forced_portal_choice_applies_to_next_segment() -> bool:
	var game := _create_game_with_seed(5151)
	var floor_1_segment: Dictionary = game.get_dungeon_segment_for_floor(1)
	if floor_1_segment.is_empty():
		return _expect(false, "First route segment must exist.")

	var first_biome: String = str(floor_1_segment.get("biome", ""))
	var first_end: int = int(floor_1_segment.get("end_floor", 1))
	var options: Array[String] = game.get_next_boss_biome_options(first_biome, first_end)
	if options.is_empty():
		return _expect(false, "Expected at least one next-biome option for forced choice test.")

	var forced_choice: String = options[0]
	game.set_next_boss_biome_choice(forced_choice)
	var next_biome: String = str(game.get_dungeon_biome_for_floor(first_end + 1))
	return _expect(next_biome == forced_choice, "Forced portal biome choice must apply to the next generated segment.")

static func _test_dungeon_default_item_pools_are_valid() -> bool:
	var dungeon := DungeonSceneScript.new()
	var item_db := ItemDBClass.new()
	var invalid_reward: Array[String] = item_db.find_invalid_item_ids(dungeon.item_reward_pool)
	var invalid_shop: Array[String] = item_db.find_invalid_item_ids(dungeon.merchant_shop_items)
	var reward_ok: bool = invalid_reward.is_empty()
	var shop_ok: bool = invalid_shop.is_empty()
	var details := "reward_invalid=%s shop_invalid=%s" % [str(invalid_reward), str(invalid_shop)]
	return _expect(reward_ok and shop_ok, "Dungeon default item pools contain unknown item IDs: %s" % details)

static func _test_npc_test_item_ids_are_valid() -> bool:
	var item_db := ItemDBClass.new()
	var ids: Array[String] = []
	for raw_id in NPCTest2Data.give_item_ids:
		ids.append(str(raw_id))
	var invalid: Array[String] = item_db.find_invalid_item_ids(ids)
	return _expect(invalid.is_empty(), "NPCTest2 contains unknown item IDs: %s" % str(invalid))

static func _test_item_menu_input_lock_flag_roundtrip() -> bool:
	var item_menu := ItemMenuClass.new()
	item_menu.set_input_locked(true)
	var locked_ok: bool = item_menu.is_input_locked()
	item_menu.set_input_locked(false)
	var unlocked_ok: bool = not item_menu.is_input_locked()
	return _expect(locked_ok and unlocked_ok, "Item menu input lock flag should toggle on/off.")

static func _test_boss_portal_npcs_spawn_and_clear_on_interaction() -> bool:
	var dungeon := _TestDungeonPortalScene.new()
	var game_stub := _PortalChoiceGameStub.new()
	dungeon.injected_game = game_stub
	dungeon._player_cell = Vector2i(0, 0)
	dungeon._room_rects = [Rect2i(8, 8, 8, 8), Rect2i(24, 8, 8, 8)]

	var options: Array[String] = ["emberfault_chasm", "echo_vault"]
	dungeon._spawn_biome_choice_portals(options)

	if dungeon._biome_portal_npcs.size() != 2:
		return _expect(false, "Expected exactly two biome portal NPCs to spawn.")

	for portal_npc in dungeon._biome_portal_npcs:
		if portal_npc == null or portal_npc.npc_data == null:
			return _expect(false, "Spawned portal NPC must contain npc_data.")
		var interaction: String = str(portal_npc.npc_data.interaction_id)
		if not interaction.begins_with("dungeon_portal_choice:"):
			return _expect(false, "Portal NPC interaction_id must use dungeon_portal_choice prefix.")
		var has_label := false
		for child in portal_npc.get_children():
			if child is Label and child.name == "PortalBiomeLabel":
				has_label = true
				break
		if not has_label:
			return _expect(false, "Portal NPC should have a biome name label.")

	dungeon._pending_biome_selection = true
	var selected_npc = dungeon._biome_portal_npcs[0]
	var selected_interaction: String = str(selected_npc.npc_data.interaction_id)
	var selected_biome: String = selected_interaction.split(":")[1]
	var handled: bool = dungeon._handle_biome_portal_interaction(selected_npc, selected_interaction)

	var clear_ok: bool = dungeon._biome_portal_npcs.is_empty() and dungeon._dynamic_npcs.is_empty()
	var choice_ok: bool = game_stub.chosen_biome == selected_biome
	var state_ok: bool = handled and not dungeon._pending_biome_selection and dungeon._pending_floor_advance
	return _expect(clear_ok and choice_ok and state_ok, "Portal interaction should clear portal NPCs and advance with selected biome.")

static func _test_track_defeated_boss_uses_monster_name() -> bool:
	var dungeon := _TestDungeonScene.new()
	var game_stub := _BossTrackGameStub.new()
	dungeon.injected_game = game_stub
	dungeon.current_floor = 15
	dungeon.habitat = "gloomrot_catacombs"

	var boss_entry := MTNPCMonsterEntry.new()
	var boss_monster := MTMonsterData.new()
	boss_monster.name = ""
	boss_entry.monster_data = boss_monster
	boss_entry.level = 18

	var boss_data := MTNPCData.new()
	boss_data.team_entries = [boss_entry]

	var boss_npc := _BossNpcStub.new()
	boss_npc.npc_data = boss_data
	dungeon._boss_npc = boss_npc

	# Regression target: this used to crash when trying to access monster_data.display_name.
	dungeon._track_defeated_boss()

	if game_stub.tracked_bosses.size() != 1:
		return _expect(false, "Expected exactly one tracked boss entry.")
	var tracked := game_stub.tracked_bosses[0]
	var team_template: Dictionary = tracked.get("team_template", {})
	var monsters: Array = team_template.get("monsters", [])
	if monsters.is_empty():
		return _expect(false, "Tracked boss entry should include at least one monster.")
	var first_monster: Dictionary = monsters[0]
	var name_ok: bool = str(first_monster.get("name", "")) == "Boss Monster"
	var level_ok: bool = int(first_monster.get("level", -1)) == 18
	return _expect(name_ok and level_ok, "Tracked boss monster should use fallback name and preserve level.")

static func _test_track_defeated_boss_preserves_existing_name() -> bool:
	var dungeon := _TestDungeonScene.new()
	var game_stub := _BossTrackGameStub.new()
	dungeon.injected_game = game_stub
	dungeon.current_floor = 16
	dungeon.habitat = "verdant_wilds"

	var boss_entry := MTNPCMonsterEntry.new()
	var boss_monster := MTMonsterData.new()
	boss_monster.name = "Ghostling"
	boss_entry.monster_data = boss_monster
	boss_entry.level = 22

	var boss_data := MTNPCData.new()
	boss_data.team_entries = [boss_entry]

	var boss_npc := _BossNpcStub.new()
	boss_npc.npc_data = boss_data
	dungeon._boss_npc = boss_npc

	dungeon._track_defeated_boss()

	if game_stub.tracked_bosses.size() != 1:
		return _expect(false, "Expected exactly one tracked boss entry for named monster.")
	var tracked := game_stub.tracked_bosses[0]
	var team_template: Dictionary = tracked.get("team_template", {})
	var monsters: Array = team_template.get("monsters", [])
	if monsters.is_empty():
		return _expect(false, "Tracked boss entry should include at least one named monster.")
	var first_monster: Dictionary = monsters[0]
	var name_ok: bool = str(first_monster.get("name", "")) == "Ghostling"
	var level_ok: bool = int(first_monster.get("level", -1)) == 22
	return _expect(name_ok and level_ok, "Tracked boss monster should keep explicit name and level.")

static func _create_game_with_seed(seed_value: int) -> Node:
	var game = GameClass.new()
	game.setup_dungeon_route_with_boss_system(50, [], "", seed_value, 7, 15)
	return game

static func _expect(condition: bool, message: String) -> bool:
	if not condition:
		DEBUG_LOG.error("DungeonSmokeTest", message)
	return condition
