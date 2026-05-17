extends RefCounted
class_name MTDungeonRunHelper

static func _has_game() -> bool:
	return _get_game() != null

static func _get_game():
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Game")

static func get_effective_quest_spawn_chance(owner) -> float:
	if not _has_game():
		return owner.quest_spawn_chance
	var game = _get_game()
	var bonus_level: int = game.get_meta_unlock_level("quest_boost")
	return clamp(owner.quest_spawn_chance + float(bonus_level) * 0.05, 0.0, 0.95)

static func start_dungeon_run_if_needed(owner) -> void:
	if not _has_game():
		return
	var game = _get_game()
	if owner.current_floor != 1:
		return
	if bool(game.flags.get("dungeon_run_active", false)):
		return
	var start_gold: int = owner.run_start_gold + game.get_meta_unlock_level("starting_gold") * 25
	game.reset_run_state(start_gold)
	if owner.has_method("_hide_biome_portals"):
		owner._hide_biome_portals()
	var route_total_floors: int = max(1, int(owner.run_total_floors))
	var preferred_start_biome := str(owner.habitat)
	var route_seed: int = int(owner.generation_seed)
	
	# Use new boss system with portal-based biome selection
	game.setup_dungeon_route_with_boss_system(
		route_total_floors,
		owner.run_biome_pool,
		preferred_start_biome,
		route_seed,
		owner.run_segment_min_len,
		owner.run_segment_max_len
	)
	owner.floor_count = route_total_floors
	var start_biome: String = game.get_dungeon_biome_for_floor(owner.current_floor)
	if start_biome != "":
		owner.habitat = start_biome
	game.flags["dungeon_run_active"] = true
	if game.dungeon_route_segments.size() > 0:
		var route_parts: Array[String] = []
		for raw_segment in game.dungeon_route_segments:
			var segment: Dictionary = raw_segment if raw_segment is Dictionary else {}
			if segment.is_empty():
				continue
			var biome_key: String = str(segment.get("biome", "?"))
			var biome: String = biome_key.capitalize()
			if owner.has_method("get_habitat_display_name"):
				biome = str(owner.get_habitat_display_name(biome_key))
			var start_floor: int = int(segment.get("start_floor", 1))
			var end_floor: int = int(segment.get("end_floor", start_floor))
			route_parts.append("%s %d-%d" % [biome, start_floor, end_floor])
		owner._log_dungeon("[Dungeon] route=%s" % " | ".join(route_parts))
	if start_biome != "":
		var start_biome_label := start_biome.capitalize()
		if owner.has_method("get_habitat_display_name"):
			start_biome_label = str(owner.get_habitat_display_name(start_biome))
		owner._enqueue_message(TranslationServer.translate("Run started. Gold: %d\nBiome: %s") % [game.run_gold, start_biome_label])
	else:
		owner._enqueue_message(TranslationServer.translate("Run started. Gold: %d") % game.run_gold)

static func finish_dungeon_run(owner) -> void:
	if not _has_game():
		return
	var game = _get_game()
	owner._close_merchant_shop()
	game.flags["dungeon_run_active"] = false
	if game.has_method("restore_party_after_run"):
		game.restore_party_after_run()
	game.reset_run_state(0)

static func award_battle_rewards(owner, winner_team_index: int, interaction: String) -> void:
	if winner_team_index != 0:
		return
	if not _has_game():
		return
	var game = _get_game()
	var gold_reward: int = 0
	if interaction == "elite_pack":
		gold_reward = owner.elite_battle_gold
	elif interaction == "mimic_pack":
		gold_reward = owner.mimic_battle_gold
	elif interaction == "dungeon_boss":
		gold_reward = owner.boss_battle_gold
	elif interaction == "":
		gold_reward = owner.wild_battle_gold
	if gold_reward > 0:
		game.add_run_gold(gold_reward)
		if interaction != "":
			owner._enqueue_message(TranslationServer.translate("Gold +%d") % gold_reward)
