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
	game.flags["dungeon_run_active"] = true
	owner._enqueue_message(TranslationServer.translate("Run started. Gold: %d") % game.run_gold)

static func finish_dungeon_run(owner) -> void:
	if not _has_game():
		return
	var game = _get_game()
	owner._close_merchant_shop()
	game.flags["dungeon_run_active"] = false
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
