extends BattleDecision
class_name AIDecision

func decide(monster: MonsterInstance, battle: BattleController):
	if monster.attacks.is_empty():
		return _basic_attack(monster, battle)

	var attack: AttackData = _choose_attack(monster)
	if attack == null:
		return _basic_attack(monster, battle)

	return _create_attack_action(monster, attack, battle)


# --------------------------------------------------
# Fallback: einfacher Angriff
# --------------------------------------------------
func _basic_attack(
	monster: MonsterInstance,
	battle: BattleController
) -> AttackAction:

	var target: MonsterInstance = battle.get_opponent(monster)
	if target == null:
		return null

	var action := AttackAction.new()
	action.battle = battle
	action.actor = monster
	action.target = target

	# ✅ Initiative ist bufffähig
	action.speed = monster.get_speed()
	action.priority = 0

	action.name = "Attack"
	action.power = 3
	action.energy_cost = 0
	action.accuracy = 100
	action.attack_element = monster.data.element
	action.damage_type = DamageType.Type.PHYSICAL
	action.crit_rate = 0.10

	return action


# --------------------------------------------------
# Angriffsauswahl
# --------------------------------------------------
func _choose_attack(monster: MonsterInstance) -> AttackData:
	return monster.attacks.pick_random()


# --------------------------------------------------
# AttackData → AttackAction
# --------------------------------------------------
func _create_attack_action(
	monster: MonsterInstance,
	attack: AttackData,
	battle: BattleController
) -> AttackAction:

	var target: MonsterInstance = battle.get_opponent(monster)
	if target == null:
		return null

	var action := AttackAction.new()
	action.battle = battle
	action.actor = monster
	action.target = target

	# ✅ Initiative berücksichtigt Speed-Buffs
	action.speed = monster.get_speed()
	action.priority = attack.priority

	action.name = attack.name
	action.power = attack.power
	action.energy_cost = attack.energy_cost
	action.accuracy = attack.accuracy
	action.attack_element = attack.element
	action.damage_type = attack.damage_type
	action.crit_rate = attack.crit_rate

	# ✅ BUFFS / DEBUFFS KORREKT ÜBERNEHMEN
	action.stat_changes = attack.stat_changes.duplicate()

	return action
