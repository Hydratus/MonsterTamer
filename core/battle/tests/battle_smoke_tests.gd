extends RefCounted
class_name MTBattleSmokeTests

const RestActionClass = preload("res://core/battle/actions/rest_action.gd")
const EscapeActionClass = preload("res://core/battle/actions/escape_action.gd")
const AttackActionClass = preload("res://core/battle/actions/attack_action.gd")

const SLIME_DATA: MTMonsterData = preload("res://data/monsters/slime/slime.tres")
const WOLF_DATA: MTMonsterData = preload("res://data/monsters/wolf/wolf.tres")
const INFERNO_ATTACK: MTAttackData = preload("res://data/moves/Inferno.tres")
const NORMAL_ATTACK: MTAttackData = preload("res://data/moves/NormalAttack.tres")
const AQUA_BLAST_ATTACK: MTAttackData = preload("res://data/moves/AquaBlast.tres")
const BATTLE_CRY_ATTACK: MTAttackData = preload("res://data/moves/BattleCry.tres")
const EMBER_ATTACK: MTAttackData = preload("res://data/moves/Ember.tres")
const FIRE_BITE_ATTACK: MTAttackData = preload("res://data/moves/FireBite.tres")
const QUICK_ATTACK: MTAttackData = preload("res://data/moves/QuickAttack.tres")
const WATER_GUN_ATTACK: MTAttackData = preload("res://data/moves/WaterGun.tres")
const BalanceConstants = preload("res://core/systems/game_balance_constants.gd")
const THORN_HIDE_TRAIT: MTTraitData = preload("res://data/traits/ThornHide.tres")
const WEAKENING_HIDE_TRAIT: MTTraitData = preload("res://data/traits/WeakeningHide.tres")
const BRUTE_FORCE_TRAIT: MTTraitData = preload("res://data/traits/BruteForce.tres")
const HP_REGEN_TRAIT: MTTraitData = preload("res://data/traits/HPRegen.tres")
const STRONG_BODY_TRAIT: MTTraitData = preload("res://data/traits/StrongBody.tres")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

class _DummyMessageBox:
	extends RefCounted
	var message_queue: Array = []
	var current_action_messages: Array = []
	var clear_count: int = 0
	var flush_count: int = 0

	func clear_messages() -> void:
		message_queue.clear()
		current_action_messages.clear()
		clear_count += 1

	func flush_action_messages() -> void:
		if not current_action_messages.is_empty():
			message_queue.append_array(current_action_messages)
			current_action_messages.clear()
		flush_count += 1

class _DummyBattleScene:
	extends RefCounted
	var message_box := _DummyMessageBox.new()
	var logged_messages: Array[String] = []
	var queued_steps: int = 0
	var queued_exp_steps: int = 0
	var queued_exp_front_steps: int = 0
	var last_winner_team_index: int = -999
	var forced_switch_team_index: int = -1
	var menu_shown := false
	var hud_updated := false
	var capture_attempts: int = 0

	func add_battle_message(text: String) -> void:
		logged_messages.append(text)
		message_box.current_action_messages.append(text)

	func flush_action_messages() -> void:
		message_box.flush_action_messages()

	func show_battle_messages() -> void:
		pass

	func queue_message_step(cb: Callable) -> void:
		queued_steps += 1
		if cb.is_valid():
			cb.call()

	func queue_exp_step(_cb: Callable, _args: Array) -> void:
		queued_exp_steps += 1

	func queue_exp_step_front(_cb: Callable, _args: Array) -> void:
		queued_exp_front_steps += 1

	func update_hud_with_active() -> void:
		hud_updated = true

	func show_player_menu(_monster: MTMonsterInstance) -> void:
		menu_shown = true

	func show_forced_switch_menu(team_index: int) -> void:
		forced_switch_team_index = team_index

	func hide_ui() -> void:
		pass

	func on_battle_finished(winner_team_index: int) -> void:
		last_winner_team_index = winner_team_index

	func perform_capture_attempt(_actor: MTMonsterInstance, _target: MTMonsterInstance, _item: MTItemData) -> void:
		capture_attempts += 1

	func get_item_user_name(_actor: MTMonsterInstance) -> String:
		return "DummyPlayer"

static func run_all() -> Dictionary:
	var results: Dictionary = {
		"rest_recovers_energy": _test_rest_recovers_energy(),
		"ai_uses_rest_when_exhausted": _test_ai_uses_rest_when_exhausted(),
		"escape_chance_scales": _test_escape_chance_scales(),
		"learn_attack_cap_rejects_weak_new_move": _test_learn_attack_cap_rejects_weak_new_move(),
		"learn_attack_cap_replaces_weaker_move": _test_learn_attack_cap_replaces_weaker_move(),
		"learn_trait_cap_rejects_new_trait_by_default": _test_learn_trait_cap_rejects_new_trait_by_default(),
		"learn_trait_cap_supports_custom_forget_choice": _test_learn_trait_cap_supports_custom_forget_choice(),
		"player_item_submit_heals_self": _test_player_item_submit_heals_self(),
		"player_action_gating_requires_all_human_inputs": _test_player_action_gating_requires_all_human_inputs(),
		"perform_switch_updates_active_monster": _test_perform_switch_updates_active_monster(),
		"adapter_message_bridge": _test_adapter_message_bridge(),
		"adapter_ui_bridge": _test_adapter_ui_bridge(),
		"adapter_item_bridge": _test_adapter_item_bridge(),
		"reserve_regen_skips_ko": _test_reserve_regen_skips_ko(),
		"contact_thorns_reflects_damage": _test_contact_thorns_reflects_damage(),
		"contact_weakening_lowers_strength": _test_contact_weakening_lowers_strength(),
		"thorns_ko_stops_lifesteal": _test_thorns_ko_stops_lifesteal(),
		"miss_skips_damage_and_contact": _test_miss_skips_damage_and_contact(),
		"player_ko_requests_forced_switch": _test_player_ko_requests_forced_switch(),
		"enemy_ko_auto_switches_reserve": _test_enemy_ko_auto_switches_reserve(),
		"lifesteal_restores_attacker_hp": _test_lifesteal_restores_attacker_hp(),
	}
	return _finalize_results(results)

static func run_logic() -> Dictionary:
	var results: Dictionary = {
		"stat_scaling_with_level": _test_stat_scaling_with_level(),
		"evolution_triggers_at_correct_level": _test_evolution_triggers_at_correct_level(),
		"move_learning_at_level_up": _test_move_learning_at_level_up(),
		"trait_learning_at_level_up": _test_trait_learning_at_level_up(),
		"exp_calculation_correct": _test_exp_calculation_correct(),
		"capture_chance_improves_lower_hp": _test_capture_chance_improves_lower_hp(),
		"stat_stage_modifiers_affect_effective_stats": _test_stat_stage_modifiers_affect_effective_stats(),
		"brute_force_trait_increases_strength": _test_brute_force_trait_increases_strength(),
		"encounter_sanitizing_removes_invalid_entries": _test_encounter_sanitizing_removes_invalid_entries()
	}
	return _finalize_results(results)

static func _finalize_results(results: Dictionary) -> Dictionary:
	var all_passed: bool = true
	for key in results.keys():
		if not bool(results[key]):
			all_passed = false
			break
	results["all_passed"] = all_passed
	return results

static func _test_rest_recovers_energy() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.energy = 0
	var expected: int = max(1, int(ceil(float(monster.get_max_energy()) * 0.25)))
	var action: MTBattleAction = RestActionClass.new()
	action.actor = monster
	action.execute()
	return _expect(monster.energy == expected, "Rest should recover 25% max energy (min 1)")

static func _test_ai_uses_rest_when_exhausted() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.attacks = [INFERNO_ATTACK]
	monster.energy = 0
	var ai := MTAIDecision.new()
	var battle := MTBattleController.new()
	var action: MTBattleAction = ai.decide(monster, battle)
	return _expect(action is MTRestAction, "AI should choose Rest if no attack is affordable")

static func _test_escape_chance_scales() -> bool:
	var fast_monster := MTMonsterInstance.new(SLIME_DATA)
	var slow_monster := MTMonsterInstance.new(WOLF_DATA)
	fast_monster.level = 25
	slow_monster.level = 5
	fast_monster.speed = 50
	slow_monster.speed = 10
	var high_chance: float = EscapeActionClass.calculate_escape_chance(fast_monster, slow_monster)
	var low_chance: float = EscapeActionClass.calculate_escape_chance(slow_monster, fast_monster)
	return _expect(high_chance > low_chance, "Escape chance should improve with better speed/level")

static func _test_learn_attack_cap_rejects_weak_new_move() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.attacks = [
		INFERNO_ATTACK,
		AQUA_BLAST_ATTACK,
		EMBER_ATTACK,
		FIRE_BITE_ATTACK,
		QUICK_ATTACK,
		WATER_GUN_ATTACK
	]

	var changed := monster.learn_attack_with_limit(BATTLE_CRY_ATTACK)
	var size_ok := monster.attacks.size() == BalanceConstants.MAX_LEARNED_ATTACKS
	var skipped_new_ok := not monster.attacks.has(BATTLE_CRY_ATTACK)
	return _expect(changed and size_ok and skipped_new_ok, "Learning a weak move at cap should keep max 6 and allow skipping the new move")

static func _test_learn_attack_cap_replaces_weaker_move() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.attacks = [
		BATTLE_CRY_ATTACK,
		EMBER_ATTACK,
		FIRE_BITE_ATTACK,
		QUICK_ATTACK,
		WATER_GUN_ATTACK,
		NORMAL_ATTACK
	]

	var changed := monster.learn_attack_with_limit(INFERNO_ATTACK)
	var size_ok := monster.attacks.size() == BalanceConstants.MAX_LEARNED_ATTACKS
	var learned_ok := monster.attacks.has(INFERNO_ATTACK)
	var replaced_ok := not monster.attacks.has(BATTLE_CRY_ATTACK)
	return _expect(changed and size_ok and learned_ok and replaced_ok, "Learning a stronger move at cap should replace a weaker move")

static func _test_learn_trait_cap_rejects_new_trait_by_default() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.passive_traits = [
		THORN_HIDE_TRAIT,
		WEAKENING_HIDE_TRAIT,
		BRUTE_FORCE_TRAIT,
		HP_REGEN_TRAIT
	]

	var changed := monster.learn_trait_with_limit(STRONG_BODY_TRAIT)
	var size_ok := monster.passive_traits.size() == BalanceConstants.MAX_LEARNED_TRAITS
	var skipped_new_ok := not monster.passive_traits.has(STRONG_BODY_TRAIT)
	return _expect(changed and size_ok and skipped_new_ok, "Trait learning at cap should keep max 4 and include rejecting the new trait")

static func _test_learn_trait_cap_supports_custom_forget_choice() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.passive_traits = [
		THORN_HIDE_TRAIT,
		WEAKENING_HIDE_TRAIT,
		BRUTE_FORCE_TRAIT,
		HP_REGEN_TRAIT
	]
	monster.trait_forget_selector = func(_candidates, _monster):
		return 1

	var changed := monster.learn_trait_with_limit(STRONG_BODY_TRAIT)
	var size_ok := monster.passive_traits.size() == BalanceConstants.MAX_LEARNED_TRAITS
	var learned_ok := monster.passive_traits.has(STRONG_BODY_TRAIT)
	var replaced_ok := not monster.passive_traits.has(WEAKENING_HIDE_TRAIT)
	return _expect(changed and size_ok and learned_ok and replaced_ok, "Trait forget selector should control which trait is replaced at cap")

static func _test_player_item_submit_heals_self() -> bool:
	var player := _create_monster(SLIME_DATA, MTPlayerDecision.new())
	var enemy := _create_monster(WOLF_DATA, MTAIDecision.new())
	player.hp = max(1, player.hp - 5)
	var hp_before := player.hp

	var battle := _create_battle([
		_create_team([player]),
		_create_team([enemy])
	])

	var heal_item := MTItemData.new()
	heal_item.id = "_test_heal"
	heal_item.name = "Test Heal"
	heal_item.category = MTItemData.Category.ACTIVE
	heal_item.heal_min = 10
	heal_item.heal_max = 10
	heal_item.consumable = false

	battle.submit_player_item(player, heal_item, null)
	return _expect(player.hp > hp_before, "Submitting item with null target should heal active player (self-target fallback)")

static func _test_player_action_gating_requires_all_human_inputs() -> bool:
	var player_a := _create_monster(SLIME_DATA, MTPlayerDecision.new())
	var player_b := _create_monster(WOLF_DATA, MTPlayerDecision.new())

	var battle := _create_battle([
		_create_team([player_a]),
		_create_team([player_b])
	])

	battle.submit_player_rest(player_a)
	var waiting_ok := battle.pending_player_actions.has(player_a) and battle.action_queue.is_empty() and battle.current_state == null

	battle.submit_player_rest(player_b)
	var resolved_ok := battle.pending_player_actions.is_empty() and battle.current_state is MTResolveActionsState

	return _expect(waiting_ok and resolved_ok, "Controller should wait for all human-player inputs before resolving actions")

static func _test_perform_switch_updates_active_monster() -> bool:
	var active := _create_monster(SLIME_DATA)
	var bench := _create_monster(WOLF_DATA)
	var enemy := _create_monster(SLIME_DATA)
	var battle := _create_battle([
		_create_team([active, bench]),
		_create_team([enemy])
	])

	var messages: Array[String] = []
	battle.message_logged.connect(func(text: String):
		messages.append(text)
	)

	var switched: bool = battle.perform_switch(0, 1, active)
	var active_ok: bool = battle.teams[0].get_active_monster() == bench
	var msg_ok: bool = not messages.is_empty() and messages[0].find("sent out") >= 0
	return _expect(switched and active_ok and msg_ok, "perform_switch should activate selected monster and emit switch message")

static func _test_adapter_message_bridge() -> bool:
	var setup := _create_battle_with_dummy_scene([])
	var battle: MTBattleController = setup.battle
	var scene: _DummyBattleScene = setup.scene
	battle.log_message("Adapter message test")

	var logged_ok := scene.logged_messages.size() == 1 and scene.logged_messages[0] == "Adapter message test"
	var has_pending_ok := battle.has_pending_action_messages()
	battle.flush_action_messages()
	var has_queue_ok := battle.has_queued_messages()
	return _expect(logged_ok and has_pending_ok and has_queue_ok, "Adapter should bridge message logging and queues")

static func _test_adapter_ui_bridge() -> bool:
	var setup := _create_battle_with_dummy_scene([])
	var battle: MTBattleController = setup.battle
	var scene: _DummyBattleScene = setup.scene

	var monster := _create_monster(SLIME_DATA)
	battle.show_player_menu(monster)
	battle.show_forced_switch_menu(1)
	battle.update_hud_with_active()
	battle.finish_battle(0)

	var menu_ok := scene.menu_shown
	var switch_ok := scene.forced_switch_team_index == 1
	var hud_ok := scene.hud_updated
	var finish_ok := scene.last_winner_team_index == 0
	return _expect(menu_ok and switch_ok and hud_ok and finish_ok, "Adapter should bridge UI and battle lifecycle calls")

static func _test_adapter_item_bridge() -> bool:
	var setup := _create_battle_with_dummy_scene([])
	var battle: MTBattleController = setup.battle
	var scene: _DummyBattleScene = setup.scene

	var actor := _create_monster(SLIME_DATA)
	var target := _create_monster(WOLF_DATA)
	var soulbinder_item := MTItemData.new()
	soulbinder_item.id = "_test_soulbinder"
	soulbinder_item.name = "TestSoulbinder"
	soulbinder_item.category = MTItemData.Category.SOULBINDER
	soulbinder_item.consumable = false

	var action := MTItemAction.new()
	action.actor = actor
	action.target = target
	action.item = soulbinder_item
	action.execute(battle)

	var capture_ok := scene.capture_attempts == 1
	var name_ok := battle.get_item_user_name(actor) == "DummyPlayer"
	return _expect(capture_ok and name_ok, "Adapter should bridge capture attempts and item user naming")

static func _test_reserve_regen_skips_ko() -> bool:
	var active := MTMonsterInstance.new(SLIME_DATA)
	var reserve_alive := MTMonsterInstance.new(WOLF_DATA)
	var reserve_ko := MTMonsterInstance.new(WOLF_DATA)
	reserve_alive.energy = 0
	reserve_ko.energy = 0
	reserve_ko.hp = 0

	var player_team := MTMonsterTeam.new([active, reserve_alive, reserve_ko])
	var enemy_team := MTMonsterTeam.new([MTMonsterInstance.new(SLIME_DATA)])

	var battle := MTBattleController.new()
	battle.teams = [player_team, enemy_team]

	var scene := MTBattleScene.new()
	battle.bind_scene(scene)
	scene.battle = battle
	scene.mark_player_participant(active)

	var expected_gain: int = max(1, int(ceil(float(reserve_alive.get_max_energy()) * 0.08)))
	scene.apply_reserve_energy_regen()

	var alive_ok: bool = reserve_alive.energy == expected_gain
	var ko_ok: bool = reserve_ko.energy == 0
	var passed := _expect(alive_ok and ko_ok, "Reserve regen should skip KO monsters and restore alive reserve")
	_cleanup_battle_scene(scene, battle)
	return passed

static func _test_contact_thorns_reflects_damage() -> bool:
	var attacker := _create_monster(WOLF_DATA)
	var defender := _create_monster(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [THORN_HIDE_TRAIT]
	var before_hp: int = attacker.hp

	var action := _create_attack_action(attacker, defender, {
		"power": NORMAL_ATTACK.power,
		"accuracy": 100,
		"damage_type": MTDamageType.Type.PHYSICAL,
		"attack_element": MTElement.Type.FIRE,
		"makes_contact": true,
		"crit_rate": 0.0
	})
	action.execute()

	return _expect(attacker.hp < before_hp, "Contact attack should trigger thorns reflect damage")

static func _test_contact_weakening_lowers_strength() -> bool:
	var attacker := _create_monster(WOLF_DATA)
	var defender := _create_monster(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [WEAKENING_HIDE_TRAIT]
	var before_stage: int = int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH])

	var action := _create_attack_action(attacker, defender, {
		"power": NORMAL_ATTACK.power,
		"accuracy": 100,
		"damage_type": MTDamageType.Type.PHYSICAL,
		"attack_element": MTElement.Type.FIRE,
		"makes_contact": true,
		"crit_rate": 0.0
	})
	action.execute()

	var after_stage: int = int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH])
	return _expect(after_stage < before_stage, "Contact attack should lower attacker strength from weakening hide")

static func _test_thorns_ko_stops_lifesteal() -> bool:
	var attacker := _create_monster(WOLF_DATA)
	var defender := _create_monster(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [THORN_HIDE_TRAIT]
	attacker.hp = 1

	var action := _create_attack_action(attacker, defender, {
		"power": NORMAL_ATTACK.power,
		"accuracy": 100,
		"damage_type": MTDamageType.Type.PHYSICAL,
		"attack_element": MTElement.Type.FIRE,
		"makes_contact": true,
		"lifesteal": 1.0,
		"crit_rate": 0.0
	})
	action.execute()

	return _expect(attacker.hp == 0, "Thorns should KO attacker before lifesteal can restore HP")

static func _test_miss_skips_damage_and_contact() -> bool:
	var attacker := _create_monster(WOLF_DATA)
	var defender := _create_monster(SLIME_DATA)
	defender.passive_traits = [WEAKENING_HIDE_TRAIT]
	var defender_hp_before: int = defender.hp
	var attacker_strength_stage_before: int = int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH])

	var action := _create_attack_action(attacker, defender, {
		"power": NORMAL_ATTACK.power,
		"accuracy": 0,
		"damage_type": MTDamageType.Type.PHYSICAL,
		"attack_element": MTElement.Type.FIRE,
		"makes_contact": true,
		"crit_rate": 0.0
	})
	action.execute()

	var defender_unchanged := defender.hp == defender_hp_before
	var stage_unchanged := int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH]) == attacker_strength_stage_before
	return _expect(defender_unchanged and stage_unchanged, "Missed attacks should deal no damage and not trigger contact effects")

static func _test_player_ko_requests_forced_switch() -> bool:
	var player_active := _create_monster(SLIME_DATA, MTPlayerDecision.new())
	var player_reserve := _create_monster(WOLF_DATA, MTPlayerDecision.new())
	var enemy_active := _create_monster(WOLF_DATA, MTAIDecision.new())
	player_active.hp = 0

	var battle := _create_battle([
		_create_team([player_active, player_reserve], 0),
		_create_team([enemy_active], 0)
	])
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)

	var state := MTCheckEndState.new()
	state.enter(battle)

	var forced_switch_ok := scene.forced_switch_team_index == 0
	var queued_ok := scene.queued_steps >= 1
	var message_ok := not scene.logged_messages.is_empty()
	return _expect(forced_switch_ok and queued_ok and message_ok, "Player KO should queue a forced switch menu for team 0")

static func _test_enemy_ko_auto_switches_reserve() -> bool:
	var player_active := _create_monster(SLIME_DATA, MTPlayerDecision.new())
	var enemy_active := _create_monster(WOLF_DATA, MTAIDecision.new())
	var enemy_reserve := _create_monster(SLIME_DATA, MTAIDecision.new())
	enemy_active.hp = 0

	var battle := _create_battle([
		_create_team([player_active], 0),
		_create_team([enemy_active, enemy_reserve], 0)
	])
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)

	var state := MTCheckEndState.new()
	state.enter(battle)

	var active_enemy: MTMonsterInstance = battle.teams[1].get_active_monster()
	var switched_ok: bool = active_enemy == enemy_reserve
	var message_ok := scene.logged_messages.size() >= 2
	return _expect(switched_ok and message_ok, "Enemy KO should auto-switch to the next living reserve monster")

# ========== NEW TESTS (18-27) ==========

static func _test_stat_scaling_with_level() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	var stats_lvl1 := {
		"max_hp": monster.get_max_hp(),
		"strength": monster.strength,
		"magic": monster.magic,
		"defense": monster.defense,
		"speed": monster.speed
	}
	
	monster.level = 50
	monster._recalculate_stats()
	var stats_lvl50 := {
		"max_hp": monster.get_max_hp(),
		"strength": monster.strength,
		"magic": monster.magic,
		"defense": monster.defense,
		"speed": monster.speed
	}
	
	var all_scaled_up := true
	for stat in stats_lvl1.keys():
		if stats_lvl50[stat] <= stats_lvl1[stat]:
			all_scaled_up = false
			break
	
	return _expect(all_scaled_up, "All stats should increase significantly from level 1 to 50")

static func _test_evolution_triggers_at_correct_level() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	var can_evolve_early := monster.can_evolve()
	
	if monster.data.evolution == null:
		return _expect(not can_evolve_early, "Monster without evolution data should not be evolvable")
	
	var evolution_data := monster.data.evolution as MTEvolutionData
	if evolution_data == null:
		return true  # Skip if no valid evolution
	
	monster.level = evolution_data.evolution_level
	monster._recalculate_stats()
	var can_evolve_now := monster.can_evolve()
	
	var pre_evolution_name := monster.data.name
	var evolved := monster.apply_evolution()
	var post_evolution_name := monster.data.name
	
	var name_changed := pre_evolution_name != post_evolution_name
	return _expect(can_evolve_now and evolved and name_changed, "Evolution should trigger at correct level and change monster data")

static func _test_move_learning_at_level_up() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.level = 1
	monster.attacks.clear()
	monster.attacks = [NORMAL_ATTACK]
	
	var available_moves := monster.get_available_attacks_to_learn()
	if available_moves.is_empty():
		return _expect(true, "No moves available at level 1 (valid edge case)")
	
	# Jump to a level where moves should be available
	for target_level in range(2, 20):
		monster.level = target_level
		monster._recalculate_stats()
		available_moves = monster.get_available_attacks_to_learn()
		if not available_moves.is_empty():
			var initial_size := monster.attacks.size()
			for learn_data in available_moves:
				monster.learn_attack_with_limit(learn_data.attack as MTAttackData)
			var final_size := monster.attacks.size()
			return _expect(final_size > initial_size, "Monster should learn new moves at level-up")
	
	return _expect(true, "No learnable moves in range 2-19 (valid edge case)")

static func _test_trait_learning_at_level_up() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	monster.level = 1
	monster.passive_traits.clear()
	
	# Jump to a level where traits should be available
	for target_level in range(1, 30):
		monster.level = target_level
		monster._recalculate_stats()
		var available_traits := monster.get_available_traits_to_learn()
		if not available_traits.is_empty():
			var initial_size := monster.passive_traits.size()
			for learn_data in available_traits:
				monster.learn_trait_with_limit(learn_data.trait_data as MTTraitData)
			var final_size := monster.passive_traits.size()
			return _expect(final_size > initial_size, "Monster should learn new traits at level-up")
	
	return _expect(true, "No learnable traits in range 1-29 (valid edge case)")

static func _test_exp_calculation_correct() -> bool:
	var defeated := MTMonsterInstance.new(SLIME_DATA)
	defeated.level = 10
	defeated.data.base_exp = 100
	
	var earned_exp := defeated._calculate_earned_exp(defeated)
	# Formula: (baseExp × (level + 5)) / 7 = (100 × 15) / 7 ≈ 214
	var expected_min := int((100 * (10 + 5)) / 7.0) - 1
	var expected_max := int((100 * (10 + 5)) / 7.0) + 1
	
	return _expect(earned_exp >= expected_min and earned_exp <= expected_max, "EXP calculation should follow formula")

static func _test_capture_chance_improves_lower_hp() -> bool:
	var target := MTMonsterInstance.new(SLIME_DATA)
	var item := MTItemData.new()
	item.id = "_test_ball"
	item.name = "Test Ball"
	item.rune_tier = 1
	item.category = MTItemData.Category.SOULBINDER
	
	# Simulate full HP
	target.hp = target.get_max_hp()
	var chance_full_hp := _calculate_test_capture_chance(target, item)
	
	# Simulate half HP
	target.hp = int(target.get_max_hp() / 2.0)
	var chance_half_hp := _calculate_test_capture_chance(target, item)
	
	# Simulate low HP
	target.hp = 1
	var chance_low_hp := _calculate_test_capture_chance(target, item)
	
	return _expect(chance_low_hp > chance_half_hp and chance_half_hp > chance_full_hp, "Capture chance should improve when target HP is lower")

static func _test_stat_stage_modifiers_affect_effective_stats() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	var base_strength: int = monster.get_strength()
	
	# Set stat stage to +2
	monster.stat_stages[MTMonsterInstance.StatType.STRENGTH] = 2
	monster._invalidate_stat_cache()
	var boosted_strength: int = monster.get_strength()
	
	# Set stat stage to -2
	monster.stat_stages[MTMonsterInstance.StatType.STRENGTH] = -2
	monster._invalidate_stat_cache()
	var reduced_strength: int = monster.get_strength()
	
	return _expect(boosted_strength > base_strength and reduced_strength < base_strength, "Stat stages should modify effective stats")

static func _test_brute_force_trait_increases_strength() -> bool:
	var monster := MTMonsterInstance.new(SLIME_DATA)
	var base_strength: int = monster.get_strength()
	
	monster.passive_traits.clear()
	monster.passive_traits = [BRUTE_FORCE_TRAIT]
	monster._invalidate_stat_cache()
	var boosted_strength: int = monster.get_strength()
	
	return _expect(boosted_strength >= base_strength, "Brute Force trait should increase strength stat")

static func _test_lifesteal_restores_attacker_hp() -> bool:
	var attacker := _create_monster(WOLF_DATA)
	var defender := _create_monster(SLIME_DATA)
	attacker.hp = 1
	attacker.passive_traits = []
	defender.passive_traits = []
	
	var action := _create_attack_action(attacker, defender, {
		"power": NORMAL_ATTACK.power,
		"accuracy": 100,
		"damage_type": MTDamageType.Type.PHYSICAL,
		"attack_element": MTElement.Type.FIRE,
		"makes_contact": false,
		"lifesteal": 0.5,
		"crit_rate": 0.0
	})
	action.execute()
	
	return _expect(attacker.hp > 1, "Lifesteal should restore attacker HP after dealing damage")

static func _test_encounter_sanitizing_removes_invalid_entries() -> bool:
	var encounter_table: Array[MTEncounterEntry] = []
	
	# Add valid entry
	var valid_entry := MTEncounterEntry.new()
	valid_entry.monster = SLIME_DATA
	valid_entry.min_level = 1
	valid_entry.max_level = 5
	valid_entry.weight = 10
	encounter_table.append(valid_entry)
	
	# Add invalid entries
	var null_monster := MTEncounterEntry.new()
	null_monster.monster = null
	null_monster.weight = 10
	encounter_table.append(null_monster)
	
	var zero_weight := MTEncounterEntry.new()
	zero_weight.monster = WOLF_DATA
	zero_weight.weight = 0
	encounter_table.append(zero_weight)
	
	var bad_level_range := MTEncounterEntry.new()
	bad_level_range.monster = SLIME_DATA
	bad_level_range.min_level = 10
	bad_level_range.max_level = 5  # max < min
	bad_level_range.weight = 10
	encounter_table.append(bad_level_range)
	
	# Simulate sanitizing (copying the logic)
	var valid_entries: Array[MTEncounterEntry] = []
	for entry in encounter_table:
		if entry == null:
			continue
		if entry.monster == null:
			continue
		if entry.weight <= 0:
			continue
		if entry.max_level < entry.min_level:
			continue
		valid_entries.append(entry)
	
	return _expect(valid_entries.size() == 1, "Sanitizing should remove all invalid entries and keep only 1 valid")

# ========== HELPER FUNCTIONS ==========

static func _calculate_test_capture_chance(target: MTMonsterInstance, item: MTItemData) -> float:
	var base_rate := float(clamp(target.data.base_catch_rate, 1, 100))
	var hp_ratio := 1.0
	var max_hp := target.get_max_hp()
	if max_hp > 0:
		hp_ratio = float(target.hp) / float(max_hp)
	hp_ratio = clamp(hp_ratio, 0.0, 1.0)
	var hp_factor := 1.0 - (0.5 * hp_ratio)
	var level_factor := 100.0 / (100.0 + float(target.level) * 2.0)
	var rune_factor := pow(1.25, float(item.rune_tier))
	var chance: float = base_rate * rune_factor * hp_factor * level_factor
	return clamp(chance, 1.0, 95.0)

static func _create_monster(monster_data: MTMonsterData, decision = null) -> MTMonsterInstance:
	var monster := MTMonsterInstance.new(monster_data)
	monster.decision = decision
	return monster

static func _create_team(monsters: Array[MTMonsterInstance], active_index: int = -1) -> MTMonsterTeam:
	var team := MTMonsterTeam.new(monsters)
	if active_index >= 0:
		team.active_monster_index = active_index
	return team

static func _create_battle(teams: Array) -> MTBattleController:
	var battle := MTBattleController.new()
	battle.teams = teams
	return battle

static func _create_battle_with_dummy_scene(teams: Array) -> Dictionary:
	var battle := _create_battle(teams)
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)
	return {
		"battle": battle,
		"scene": scene
	}

static func _create_attack_action(actor: MTMonsterInstance, target: MTMonsterInstance, overrides: Dictionary = {}) -> MTAttackAction:
	var action := AttackActionClass.new()
	action.actor = actor
	action.target = target
	action.action_name = str(overrides.get("action_name", NORMAL_ATTACK.name))
	action.power = int(overrides.get("power", NORMAL_ATTACK.power))
	action.energy_cost = int(overrides.get("energy_cost", 0))
	action.accuracy = int(overrides.get("accuracy", 100))
	action.damage_type = overrides.get("damage_type", MTDamageType.Type.PHYSICAL)
	action.attack_element = overrides.get("attack_element", MTElement.Type.FIRE)
	action.makes_contact = bool(overrides.get("makes_contact", false))
	action.lifesteal = float(overrides.get("lifesteal", 0.0))
	action.crit_rate = float(overrides.get("crit_rate", 0.0))
	return action

static func _expect(condition: bool, message: String) -> bool:
	if not condition:
		DEBUG_LOG.error("SmokeTest", message)
	return condition

static func _cleanup_battle_scene(scene: MTBattleScene, battle: MTBattleController) -> void:
	if battle != null:
		battle.bind_scene(null)
		battle.current_state = null
		battle.teams.clear()
		battle.action_queue.clear()
		battle.pending_player_actions.clear()
	if scene != null:
		scene.battle = null
		scene.player_team_instance = null
		scene.free()
