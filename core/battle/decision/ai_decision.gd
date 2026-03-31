extends MTBattleDecision
class_name MTAIDecision

const RestActionClass = preload("res://core/battle/actions/rest_action.gd")

func decide(monster: MTMonsterInstance, battle: MTBattleController) -> MTBattleAction:
	if monster.attacks.is_empty():
		return _create_rest_action(monster, battle)

	var attack: MTAttackData = _choose_attack(monster)
	if attack == null:
		return _create_rest_action(monster, battle)

	return _create_attack_action(monster, attack, battle)


# --------------------------------------------------
# Fallback: einfacher Angriff
# --------------------------------------------------
func _basic_attack(
	monster: MTMonsterInstance,
	battle: MTBattleController
) -> MTBattleAction:

	# Bestimme das gegnerische Team dynamisch
	var team_index: int = -1
	for i in range(battle.teams.size()):
		if battle.teams[i].get_active_monster() == monster:
			team_index = i
			break
	
	if team_index == -1:
		return null
	
	var opponent_team: MTMonsterTeam = battle.get_opponent_team(team_index)
	if opponent_team == null:
		return null

	var action := MTAttackAction.new()
	action.battle = battle
	action.actor = monster
	action.opponent_team = opponent_team
	action.target = battle.get_opponent(monster)

	# ✅ Initiative ist bufffähig
	action.speed = monster.get_speed()
	action.priority = 0

	action.action_name = "Attack"
	action.power = 3
	action.energy_cost = 0
	action.accuracy = 100
	action.attack_element = monster.data.element
	action.damage_type = MTDamageType.Type.PHYSICAL
	action.crit_rate = 0.10

	return action


# --------------------------------------------------
# Angriffsauswahl
# --------------------------------------------------
func _choose_attack(monster: MTMonsterInstance) -> MTAttackData:
	var usable_attacks: Array[MTAttackData] = []
	for attack in monster.attacks:
		if attack == null:
			continue
		if monster.energy >= attack.energy_cost:
			usable_attacks.append(attack)
	if usable_attacks.is_empty():
		return null
	return usable_attacks.pick_random()

func _create_rest_action(monster: MTMonsterInstance, _battle: MTBattleController) -> MTBattleAction:
	var action: MTBattleAction = RestActionClass.new()
	action.actor = monster
	action.priority = 0
	action.initiative = monster.get_speed()
	return action


# --------------------------------------------------
# MTAttackData → MTAttackAction
# --------------------------------------------------
func _create_attack_action(
	monster: MTMonsterInstance,
	attack: MTAttackData,
	battle: MTBattleController
) -> MTBattleAction:

	# Bestimme das gegnerische Team dynamisch
	var team_index: int = -1
	for i in range(battle.teams.size()):
		if battle.teams[i].get_active_monster() == monster:
			team_index = i
			break
	
	if team_index == -1:
		return null
	
	var opponent_team: MTMonsterTeam = battle.get_opponent_team(team_index)
	if opponent_team == null:
		return null

	var action := MTAttackAction.new()
	action.battle = battle
	action.actor = monster
	action.opponent_team = opponent_team
	action.target = battle.get_opponent(monster)

	# ✅ Initiative berücksichtigt Speed-Buffs
	action.speed = monster.get_speed()
	action.priority = attack.priority

	action.action_name = attack.name
	action.power = attack.power
	action.energy_cost = attack.energy_cost
	action.accuracy = attack.accuracy
	action.attack_element = attack.element
	action.damage_type = attack.damage_type
	action.crit_rate = attack.crit_rate

	# ✅ BUFFS / DEBUFFS KORREKT ÜBERNEHMEN
	action.stat_changes = attack.stat_changes.duplicate()

	return action
