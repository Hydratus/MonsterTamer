extends RefCounted
class_name DamageCalculator

static func calculate_damage(action: BattleAction) -> Dictionary:
	var attacker: MonsterInstance = action.actor
	var defender: MonsterInstance = action.target
	print("Traits:", attacker.passive_traits)

	# ----------------------------
	# ATTACK / DEFENSE
	# ----------------------------
	var attack_stat: int
	var defense_stat: int

	if action.damage_type == DamageType.Type.PHYSICAL:
		attack_stat = attacker.get_strength()
		defense_stat = defender.get_defense()
	else:
		attack_stat = attacker.get_magic()
		defense_stat = defender.get_resistance()

	var base_damage: float = (
		(float(action.power) * float(attack_stat))
		/ (float(defense_stat) + 10.0)
	) + 1.0

	# ----------------------------
	# PASSIVE TRAITS (DAMAGE)
	# ----------------------------
	for trait_effect in attacker.passive_traits:
		base_damage = trait_effect.modify_damage(
			attacker,
			defender,
			base_damage,
			action
		)

	# ----------------------------
	# EFFECTIVENESS
	# ----------------------------
	var effectiveness: float = TypeChart.get_multiplier(
		action.attack_element,
		defender.data.elements
	)

	# ----------------------------
	# STAB
	# ----------------------------
	var stab: float = 1.0
	if attacker.data.elements.has(action.attack_element):
		stab = 1.5

	# ----------------------------
	# CRIT
	# ----------------------------
	var crit_chance: float = clamp(
		action.crit_rate + attacker.get_crit_rate_bonus(),
		0.0,
		1.0
	)

	var is_crit: bool = randf() <= crit_chance
	var crit_multiplier: float = (
		attacker.get_crit_damage_multiplier()
		if is_crit
		else 1.0
	)

	# ----------------------------
	# RANDOM
	# ----------------------------
	var random_factor: float = randf_range(0.9, 1.1)

	# ----------------------------
	# FINAL DAMAGE
	# ----------------------------
	var final_damage: int = int(ceil(
		base_damage
		* effectiveness
		* stab
		* crit_multiplier
		* random_factor
	))

	if effectiveness == 0.0:
		final_damage = 0
	else:
		final_damage = max(final_damage, 1)

	return {
		"damage": final_damage,
		"effectiveness": effectiveness,
		"effectiveness_text": _get_effectiveness_text(effectiveness),
		"stab": stab,
		"is_crit": is_crit
	}

static func _get_effectiveness_text(value: float) -> String:
	match value:
		0.0: return "It has no effect!"
		0.25: return "It's barely effective…"
		0.5: return "It's not very effective…"
		2.0: return "It's very effective!"
		4.0: return "It's extremely effective!" 
	return ""
