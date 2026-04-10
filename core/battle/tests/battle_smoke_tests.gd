extends RefCounted
class_name MTBattleSmokeTests

const RestActionClass = preload("res://core/battle/actions/rest_action.gd")
const EscapeActionClass = preload("res://core/battle/actions/escape_action.gd")
const AttackActionClass = preload("res://core/battle/actions/attack_action.gd")

const SLIME_DATA: MTMonsterData = preload("res://data/monsters/slime/slime.tres")
const WOLF_DATA: MTMonsterData = preload("res://data/monsters/wolf/wolf.tres")
const INFERNO_ATTACK: MTAttackData = preload("res://data/moves/Inferno.tres")
const NORMAL_ATTACK: MTAttackData = preload("res://data/moves/NormalAttack.tres")
const THORN_HIDE_TRAIT: MTTraitData = preload("res://data/traits/ThornHide.tres")
const WEAKENING_HIDE_TRAIT: MTTraitData = preload("res://data/traits/WeakeningHide.tres")
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
		"player_item_submit_heals_self": _test_player_item_submit_heals_self(),
		"player_action_gating_requires_all_human_inputs": _test_player_action_gating_requires_all_human_inputs(),
		"perform_switch_updates_active_monster": _test_perform_switch_updates_active_monster(),
		"adapter_message_bridge": _test_adapter_message_bridge(),
		"adapter_ui_bridge": _test_adapter_ui_bridge(),
		"adapter_item_bridge": _test_adapter_item_bridge(),
		"reserve_regen_skips_ko": _test_reserve_regen_skips_ko(),
		"contact_thorns_reflects_damage": _test_contact_thorns_reflects_damage(),
		"contact_weakening_lowers_strength": _test_contact_weakening_lowers_strength(),
		"thorns_ko_stops_lifesteal": _test_thorns_ko_stops_lifesteal()
	}
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

static func _test_player_item_submit_heals_self() -> bool:
	var player := MTMonsterInstance.new(SLIME_DATA)
	var enemy := MTMonsterInstance.new(WOLF_DATA)
	player.decision = MTPlayerDecision.new()
	enemy.decision = MTAIDecision.new()
	player.hp = max(1, player.hp - 5)
	var hp_before := player.hp

	var battle := MTBattleController.new()
	battle.teams = [
		MTMonsterTeam.new([player]),
		MTMonsterTeam.new([enemy])
	]

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
	var player_a := MTMonsterInstance.new(SLIME_DATA)
	var player_b := MTMonsterInstance.new(WOLF_DATA)
	player_a.decision = MTPlayerDecision.new()
	player_b.decision = MTPlayerDecision.new()

	var battle := MTBattleController.new()
	battle.teams = [
		MTMonsterTeam.new([player_a]),
		MTMonsterTeam.new([player_b])
	]

	battle.submit_player_rest(player_a)
	var waiting_ok := battle.pending_player_actions.has(player_a) and battle.action_queue.is_empty() and battle.current_state == null

	battle.submit_player_rest(player_b)
	var resolved_ok := battle.pending_player_actions.is_empty() and battle.current_state is MTResolveActionsState

	return _expect(waiting_ok and resolved_ok, "Controller should wait for all human-player inputs before resolving actions")

static func _test_perform_switch_updates_active_monster() -> bool:
	var active := MTMonsterInstance.new(SLIME_DATA)
	var bench := MTMonsterInstance.new(WOLF_DATA)
	var enemy := MTMonsterInstance.new(SLIME_DATA)
	var battle := MTBattleController.new()
	battle.teams = [
		MTMonsterTeam.new([active, bench]),
		MTMonsterTeam.new([enemy])
	]

	var messages: Array[String] = []
	battle.message_logged.connect(func(text: String):
		messages.append(text)
	)

	var switched: bool = battle.perform_switch(0, 1, active)
	var active_ok: bool = battle.teams[0].get_active_monster() == bench
	var msg_ok: bool = not messages.is_empty() and messages[0].find("sent out") >= 0
	return _expect(switched and active_ok and msg_ok, "perform_switch should activate selected monster and emit switch message")

static func _test_adapter_message_bridge() -> bool:
	var battle := MTBattleController.new()
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)
	battle.log_message("Adapter message test")

	var logged_ok := scene.logged_messages.size() == 1 and scene.logged_messages[0] == "Adapter message test"
	var has_pending_ok := battle.has_pending_action_messages()
	battle.flush_action_messages()
	var has_queue_ok := battle.has_queued_messages()
	return _expect(logged_ok and has_pending_ok and has_queue_ok, "Adapter should bridge message logging and queues")

static func _test_adapter_ui_bridge() -> bool:
	var battle := MTBattleController.new()
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)

	var monster := MTMonsterInstance.new(SLIME_DATA)
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
	var battle := MTBattleController.new()
	var scene := _DummyBattleScene.new()
	battle.bind_scene(scene)

	var actor := MTMonsterInstance.new(SLIME_DATA)
	var target := MTMonsterInstance.new(WOLF_DATA)
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
	return _expect(alive_ok and ko_ok, "Reserve regen should skip KO monsters and restore alive reserve")

static func _test_contact_thorns_reflects_damage() -> bool:
	var attacker := MTMonsterInstance.new(WOLF_DATA)
	var defender := MTMonsterInstance.new(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [THORN_HIDE_TRAIT]
	var before_hp: int = attacker.hp

	var action = AttackActionClass.new()
	action.actor = attacker
	action.target = defender
	action.action_name = NORMAL_ATTACK.name
	action.power = NORMAL_ATTACK.power
	action.energy_cost = 0
	action.accuracy = 100
	action.damage_type = MTDamageType.Type.PHYSICAL
	action.attack_element = MTElement.Type.NORMAL
	action.makes_contact = true
	action.crit_rate = 0.0
	action.execute()

	return _expect(attacker.hp < before_hp, "Contact attack should trigger thorns reflect damage")

static func _test_contact_weakening_lowers_strength() -> bool:
	var attacker := MTMonsterInstance.new(WOLF_DATA)
	var defender := MTMonsterInstance.new(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [WEAKENING_HIDE_TRAIT]
	var before_stage: int = int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH])

	var action = AttackActionClass.new()
	action.actor = attacker
	action.target = defender
	action.action_name = NORMAL_ATTACK.name
	action.power = NORMAL_ATTACK.power
	action.energy_cost = 0
	action.accuracy = 100
	action.damage_type = MTDamageType.Type.PHYSICAL
	action.attack_element = MTElement.Type.NORMAL
	action.makes_contact = true
	action.crit_rate = 0.0
	action.execute()

	var after_stage: int = int(attacker.stat_stages[MTMonsterInstance.StatType.STRENGTH])
	return _expect(after_stage < before_stage, "Contact attack should lower attacker strength from weakening hide")

static func _test_thorns_ko_stops_lifesteal() -> bool:
	var attacker := MTMonsterInstance.new(WOLF_DATA)
	var defender := MTMonsterInstance.new(SLIME_DATA)
	attacker.passive_traits = []
	defender.passive_traits = [THORN_HIDE_TRAIT]
	attacker.hp = 1

	var action = AttackActionClass.new()
	action.actor = attacker
	action.target = defender
	action.action_name = NORMAL_ATTACK.name
	action.power = NORMAL_ATTACK.power
	action.energy_cost = 0
	action.accuracy = 100
	action.damage_type = MTDamageType.Type.PHYSICAL
	action.attack_element = MTElement.Type.NORMAL
	action.makes_contact = true
	action.lifesteal = 1.0
	action.crit_rate = 0.0
	action.execute()

	return _expect(attacker.hp == 0, "Thorns should KO attacker before lifesteal can restore HP")

static func _expect(condition: bool, message: String) -> bool:
	if not condition:
		DEBUG_LOG.error("SmokeTest", message)
	return condition
