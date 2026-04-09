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

static func run_all() -> Dictionary:
	var results: Dictionary = {
		"rest_recovers_energy": _test_rest_recovers_energy(),
		"ai_uses_rest_when_exhausted": _test_ai_uses_rest_when_exhausted(),
		"escape_chance_scales": _test_escape_chance_scales(),
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
		push_error("[SmokeTest] " + message)
	return condition
