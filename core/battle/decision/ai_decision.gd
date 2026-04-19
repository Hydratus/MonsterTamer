extends MTBattleDecision
class_name MTAIDecision

const RestActionClass = preload("res://core/battle/actions/rest_action.gd")
const SwitchActionClass = preload("res://core/battle/actions/switch_action.gd")
const AttackActionClass = preload("res://core/battle/actions/attack_action.gd")

const KO_SCORE_BONUS := 40.0
const SWITCH_MIN_ADVANTAGE := 12.0
const BAD_MATCHUP_THREAT := 0.60

func decide(monster: MTMonsterInstance, battle: MTBattleController) -> MTBattleAction:
	var team_index := _find_team_index(monster, battle)
	if team_index == -1:
		return _create_rest_action(monster)

	var opponent: MTMonsterInstance = battle.get_opponent(monster)
	if opponent == null or not opponent.is_alive():
		return _create_rest_action(monster)

	var best_attack: MTAttackData = _choose_best_attack(monster, opponent)
	var best_attack_score := -INF
	if best_attack != null:
		best_attack_score = _score_attack(monster, opponent, best_attack)

	var switch_plan := _find_best_switch(monster, battle, team_index, opponent)
	var current_threat := _estimate_incoming_threat(opponent, monster)

	if switch_plan["action"] != null:
		var switch_score: float = float(switch_plan["score"])
		if switch_score > best_attack_score + SWITCH_MIN_ADVANTAGE and (current_threat >= BAD_MATCHUP_THREAT or best_attack == null):
			return switch_plan["action"]

	if best_attack != null:
		return _create_attack_action(monster, best_attack, battle)

	if switch_plan["action"] != null:
		return switch_plan["action"]

	return _create_rest_action(monster)

func _choose_best_attack(monster: MTMonsterInstance, opponent: MTMonsterInstance) -> MTAttackData:
	var usable_attacks: Array[MTAttackData] = []
	for attack in monster.attacks:
		if attack == null:
			continue
		if monster.energy >= attack.energy_cost:
			usable_attacks.append(attack)

	if usable_attacks.is_empty():
		return null

	var best_attack: MTAttackData = null
	var best_score := -INF
	for attack in usable_attacks:
		var score := _score_attack(monster, opponent, attack)
		if score > best_score:
			best_score = score
			best_attack = attack

	return best_attack

func _score_attack(monster: MTMonsterInstance, opponent: MTMonsterInstance, attack: MTAttackData) -> float:
	if monster == null or opponent == null or attack == null:
		return -INF
	var expected_damage: int = _estimate_expected_damage(monster, opponent, attack)
	var damage_ratio: float = float(expected_damage) / max(1.0, float(opponent.get_max_hp()))
	var score: float = damage_ratio * 90.0

	if expected_damage >= opponent.hp:
		score += KO_SCORE_BONUS

	if attack.damage_type != MTDamageType.Type.STATUS:
		var defender_elements: Array = _get_monster_elements(opponent)
		var type_multiplier: float = MTTypeChart.get_multiplier(attack.element, defender_elements)
		if type_multiplier > 1.0:
			score += 8.0 * type_multiplier
		elif type_multiplier == 0.0:
			score -= 40.0
		elif type_multiplier < 1.0:
			score -= 8.0
	else:
		score += 3.0

	var accuracy_factor: float = clamp(float(attack.accuracy) / 100.0, 0.0, 1.0)
	score *= lerp(0.6, 1.0, accuracy_factor)

	if attack.energy_cost > 0:
		var energy_penalty: float = float(attack.energy_cost) / max(1.0, float(monster.get_max_energy())) * 8.0
		score -= energy_penalty

	score += _score_stat_changes(monster, opponent, attack)
	return score

func _score_stat_changes(monster: MTMonsterInstance, opponent: MTMonsterInstance, attack: MTAttackData) -> float:
	if attack.stat_changes.is_empty():
		return 0.0

	var score := 0.0
	var threat := _estimate_incoming_threat(opponent, monster)

	for change in attack.stat_changes:
		if change == null:
			continue

		var receiver: MTMonsterInstance = monster if change.target_self else opponent
		var current_stage: int = int(receiver.stat_stages.get(change.stat, 0))
		var future_stage: int = MTStatStage.clamp_stage(current_stage + change.stages)
		var effective_delta: int = future_stage - current_stage
		if effective_delta == 0:
			continue

		var is_beneficial: bool = (change.target_self and effective_delta > 0) or (not change.target_self and effective_delta < 0)
		var stage_weight: float = _get_stat_weight(change.stat)
		var tactical_factor: float = 1.0

		if change.target_self and threat > 0.5:
			tactical_factor = 0.75
		if not change.target_self and threat > 0.5:
			tactical_factor = 1.15

		var delta_score: float = abs(float(effective_delta)) * stage_weight * tactical_factor
		score += delta_score if is_beneficial else -delta_score

	return score

func _get_stat_weight(stat: int) -> float:
	if stat == MTMonsterInstance.StatType.STRENGTH or stat == MTMonsterInstance.StatType.MAGIC:
		return 7.0
	if stat == MTMonsterInstance.StatType.DEFENSE or stat == MTMonsterInstance.StatType.RESISTANCE:
		return 6.5
	if stat == MTMonsterInstance.StatType.SPEED:
		return 5.5
	if stat == MTMonsterInstance.StatType.CRIT_RATE or stat == MTMonsterInstance.StatType.CRIT_DAMAGE:
		return 4.5
	return 3.0

func _estimate_expected_damage(attacker: MTMonsterInstance, defender: MTMonsterInstance, attack: MTAttackData) -> int:
	if attacker == null or defender == null:
		return 0
	if attack == null or attack.power <= 0:
		return 0
	if attack.damage_type == MTDamageType.Type.STATUS:
		return 0

	var attack_stat: int
	var defense_stat: int
	if attack.damage_type == MTDamageType.Type.PHYSICAL:
		attack_stat = attacker.get_strength()
		defense_stat = defender.get_defense()
	else:
		attack_stat = attacker.get_magic()
		defense_stat = defender.get_resistance()

	var base_damage: float = (float(attack.power) * float(attack_stat)) / (float(defense_stat) + 10.0) + 1.0
	var simulated_action = AttackActionClass.new()
	simulated_action.damage_type = attack.damage_type
	simulated_action.attack_element = attack.element
	for trait_effect in attacker.passive_traits:
		if trait_effect == null:
			continue
		base_damage = trait_effect.modify_damage(attacker, defender, base_damage, simulated_action)

	var defender_elements: Array = _get_monster_elements(defender)
	var effectiveness: float = MTTypeChart.get_multiplier(attack.element, defender_elements)
	if effectiveness == 0.0:
		return 0

	var attacker_elements: Array = _get_monster_elements(attacker)
	var stab: float = 1.5 if attacker_elements.has(attack.element) else 1.0
	var crit_chance: float = clamp(attack.crit_rate + attacker.get_crit_rate_bonus(), 0.0, 1.0)
	var expected_crit: float = 1.0 + crit_chance * (attacker.get_crit_damage_multiplier() - 1.0)

	var final_damage: int = int(ceil(base_damage * effectiveness * stab * expected_crit))
	return max(1, final_damage)

func _estimate_incoming_threat(attacker: MTMonsterInstance, defender: MTMonsterInstance) -> float:
	var best_damage := 0
	for attack in attacker.attacks:
		if attack == null:
			continue
		if attacker.energy < attack.energy_cost:
			continue
		best_damage = max(best_damage, _estimate_expected_damage(attacker, defender, attack))

	if best_damage == 0:
		best_damage = _estimate_struggle_damage(attacker, defender)

	return float(best_damage) / max(1.0, float(defender.hp))

func _estimate_struggle_damage(attacker: MTMonsterInstance, defender: MTMonsterInstance) -> int:
	if attacker == null or defender == null:
		return 0
	var base: float = (3.0 * float(attacker.get_strength())) / (float(defender.get_defense()) + 10.0) + 1.0
	var attack_element: MTElement.Type = _get_primary_element(attacker)
	var defender_elements: Array = _get_monster_elements(defender)
	var effectiveness: float = MTTypeChart.get_multiplier(attack_element, defender_elements)
	if effectiveness == 0.0:
		return 0
	var attacker_elements: Array = _get_monster_elements(attacker)
	var stab: float = 1.5 if attacker_elements.has(attack_element) else 1.0
	return max(1, int(ceil(base * effectiveness * stab)))

func _get_monster_elements(monster: MTMonsterInstance) -> Array:
	if monster == null or monster.data == null:
		return []
	if monster.data.elements == null:
		return []
	return monster.data.elements

func _get_primary_element(monster: MTMonsterInstance) -> MTElement.Type:
	var elements: Array = _get_monster_elements(monster)
	if elements.is_empty():
		return MTElement.Type.FIRE
	return elements[0]

func _find_best_switch(monster: MTMonsterInstance, battle: MTBattleController, team_index: int, opponent: MTMonsterInstance) -> Dictionary:
	var result := {
		"action": null,
		"score": -INF
	}

	if team_index < 0 or team_index >= battle.teams.size():
		return result

	var team: MTMonsterTeam = battle.teams[team_index]
	for i in range(team.monsters.size()):
		var candidate: MTMonsterInstance = team.monsters[i]
		if candidate == null or candidate == monster:
			continue
		if not candidate.is_alive():
			continue

		var candidate_score := _score_switch_candidate(candidate, opponent)
		if candidate_score > result["score"]:
			result["score"] = candidate_score
			result["action"] = SwitchActionClass.new(team_index, i, monster)

	return result

func _score_switch_candidate(candidate: MTMonsterInstance, opponent: MTMonsterInstance) -> float:
	var outgoing_best := 0
	for attack in candidate.attacks:
		if attack == null:
			continue
		if candidate.energy < attack.energy_cost:
			continue
		outgoing_best = max(outgoing_best, _estimate_expected_damage(candidate, opponent, attack))

	var offense_score: float = float(outgoing_best) / max(1.0, float(opponent.get_max_hp())) * 70.0
	var defense_penalty: float = _estimate_incoming_threat(opponent, candidate) * 55.0
	var hp_score: float = float(candidate.hp) / max(1.0, float(candidate.get_max_hp())) * 20.0

	return offense_score + hp_score - defense_penalty

func _find_team_index(monster: MTMonsterInstance, battle: MTBattleController) -> int:
	for i in range(battle.teams.size()):
		if battle.teams[i].get_active_monster() == monster:
			return i
	return -1

func _create_rest_action(monster: MTMonsterInstance) -> MTBattleAction:
	var action: MTBattleAction = RestActionClass.new()
	action.actor = monster
	action.priority = 0
	action.initiative = monster.get_speed()
	return action

func _create_attack_action(
	monster: MTMonsterInstance,
	attack: MTAttackData,
	battle: MTBattleController
) -> MTBattleAction:
	var team_index: int = _find_team_index(monster, battle)
	if team_index == -1:
		return null

	var opponent_team: MTMonsterTeam = battle.get_opponent_team(team_index)
	if opponent_team == null:
		return null

	var action = AttackActionClass.new()
	action.battle = battle
	action.actor = monster
	action.opponent_team = opponent_team
	action.target = battle.get_opponent(monster)
	action.speed = monster.get_speed()
	action.priority = attack.priority
	action.action_name = attack.name
	action.power = attack.power
	action.energy_cost = attack.energy_cost
	action.accuracy = attack.accuracy
	action.attack_element = attack.element
	action.damage_type = attack.damage_type
	action.makes_contact = attack.makes_contact
	action.requires_contact_for_effect = attack.requires_contact_for_effect
	action.lifesteal = attack.lifesteal
	action.crit_rate = attack.crit_rate
	action.stat_changes = attack.stat_changes.duplicate()
	return action
