extends RefCounted
class_name MTDungeonSmokeTests

const GameClass = preload("res://globals/game.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

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
		"forced_portal_choice_applies_to_next_segment": _test_forced_portal_choice_applies_to_next_segment()
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

static func _create_game_with_seed(seed_value: int) -> Node:
	var game = GameClass.new()
	game.setup_dungeon_route_with_boss_system(50, [], "", seed_value, 7, 15)
	return game

static func _expect(condition: bool, message: String) -> bool:
	if not condition:
		DEBUG_LOG.error("DungeonSmokeTest", message)
	return condition
