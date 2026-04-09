extends RefCounted
class_name MTDungeonRunHelper

static func get_effective_quest_spawn_chance(owner) -> float:
	if Game == null:
		return owner.quest_spawn_chance
	var bonus_level: int = Game.get_meta_unlock_level("quest_boost")
	return clamp(owner.quest_spawn_chance + float(bonus_level) * 0.05, 0.0, 0.95)

static func start_dungeon_run_if_needed(owner) -> void:
	if Game == null:
		return
	if owner.current_floor != 1:
		return
	if bool(Game.flags.get("dungeon_run_active", false)):
		return
	var start_gold: int = owner.run_start_gold + Game.get_meta_unlock_level("starting_gold") * 25
	Game.reset_run_state(start_gold)
	Game.flags["dungeon_run_active"] = true
	owner._enqueue_message(TranslationServer.translate("Run started. Gold: %d") % Game.run_gold)

static func finish_dungeon_run(owner) -> void:
	if Game == null:
		return
	owner._close_merchant_shop()
	Game.flags["dungeon_run_active"] = false
	Game.reset_run_state(0)

static func award_battle_rewards(owner, winner_team_index: int, interaction: String) -> void:
	if winner_team_index != 0:
		return
	if Game == null:
		return
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
		Game.add_run_gold(gold_reward)
		if interaction != "":
			owner._enqueue_message(TranslationServer.translate("Gold +%d") % gold_reward)
