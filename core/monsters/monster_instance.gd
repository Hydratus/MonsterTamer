extends RefCounted
class_name MonsterInstance

# ------------------------
# ENUMS
# ------------------------
enum StatType {
	MAX_HP,
	MAX_ENERGY,
	STRENGTH,
	MAGIC,
	DEFENSE,
	RESISTANCE,
	SPEED,
	CRIT_RATE,
	CRIT_DAMAGE
}

# ------------------------
# DATA
# ------------------------
var data: MonsterData
var decision: BattleDecision

# ------------------------
# BASE STATS
# ------------------------
var max_hp: int
var hp: int

var max_energy: int
var energy: int

var strength: int
var magic: int
var defense: int
var resistance: int
var speed: int

# ------------------------
# MODIFIERS
# ------------------------
var accuracy_modifier: float = 1.0
var evasion_modifier: float = 1.0
var crit_damage_multiplier: float = 1.5

# ------------------------
# STAT STAGES
# ------------------------
var stat_stages := {
	StatType.MAX_HP: 0,
	StatType.MAX_ENERGY: 0,
	StatType.STRENGTH: 0,
	StatType.MAGIC: 0,
	StatType.DEFENSE: 0,
	StatType.RESISTANCE: 0,
	StatType.SPEED: 0,
	StatType.CRIT_RATE: 0,
	StatType.CRIT_DAMAGE: 0
}

# ------------------------
# EFFECTS & TRAITS
# ------------------------
var active_effects: Array[BattleEffect] = []
var passive_traits: Array[TraitData] = []

# ------------------------
# ATTACKS
# ------------------------
var attacks: Array[AttackData] = []

# ------------------------
# INIT
# ------------------------
func _init(monster_data: MonsterData):
	data = monster_data
	attacks = monster_data.attacks.duplicate()

	for trait_effect in monster_data.passive_traits:
		add_trait(trait_effect)

	_recalculate_stats()

	hp = get_max_hp()
	energy = get_max_energy()

# ------------------------
# BASE STAT RESET
# ------------------------
func _recalculate_stats():
	_apply_level_scaling()
	reset_stat_stages()
	clear_effects()
	clamp_resources()

# Calculate actual stats based on base stats and level
func _apply_level_scaling():
	var level = data.level
	
	# HP: ((2 × base_max_hp × level) / 100) + level + 5
	max_hp = int(ceil((2 * data.base_max_hp * level) / 100.0)) + level + 5
	
	# Energy: ((2 × base_max_energy × level) / 100) + 3
	max_energy = int(ceil((2 * data.base_max_energy * level) / 100.0)) + 3
	
	# Stats: ((2 × base_stat × level) / 100) + 5
	strength = int(ceil((2 * data.base_strength * level) / 100.0)) + 5
	magic = int(ceil((2 * data.base_magic * level) / 100.0)) + 5
	defense = int(ceil((2 * data.base_defense * level) / 100.0)) + 5
	resistance = int(ceil((2 * data.base_resistance * level) / 100.0)) + 5
	speed = int(ceil((2 * data.base_speed * level) / 100.0)) + 5


# ------------------------
# STAT STAGES
# ------------------------
func reset_stat_stages():
	for key in stat_stages.keys():
		stat_stages[key] = 0

func modify_stat_stage(stat: int, amount: int) -> int:
	var before: int = stat_stages[stat]
	var after: int = StatStage.clamp_stage(before + amount)
	stat_stages[stat] = after
	return after - before

# ------------------------
# EFFECTIVE STATS (STAT STAGES + TRAITS)
# ------------------------
func _apply_trait_stat(stat: int, value: int) -> int:
	var result := value

	for trait_effect in passive_traits:
		for mod in trait_effect.stat_modifiers:
			if mod.stat != stat:
				continue

			# Flat zuerst
			result += mod.flat_bonus
			# Danach Multiplier
			result = int(ceil(result * mod.multiplier))

	return result

func get_max_hp() -> int:
	var v := int(ceil(max_hp * StatStage.get_multiplier(stat_stages[StatType.MAX_HP])))
	return _apply_trait_stat(StatType.MAX_HP, v)
	
func get_max_energy() -> int:
	var v := int(ceil(max_energy * StatStage.get_multiplier(stat_stages[StatType.MAX_ENERGY])))
	return _apply_trait_stat(StatType.MAX_ENERGY, v)

func get_strength() -> int:
	var v := int(ceil(strength * StatStage.get_multiplier(stat_stages[StatType.STRENGTH])))
	return _apply_trait_stat(StatType.STRENGTH, v)

func get_magic() -> int:
	var v := int(ceil(magic * StatStage.get_multiplier(stat_stages[StatType.MAGIC])))
	return _apply_trait_stat(StatType.MAGIC, v)

func get_defense() -> int:
	var v := int(ceil(defense * StatStage.get_multiplier(stat_stages[StatType.DEFENSE])))
	return _apply_trait_stat(StatType.DEFENSE, v)

func get_resistance() -> int:
	var v := int(ceil(resistance * StatStage.get_multiplier(stat_stages[StatType.RESISTANCE])))
	return _apply_trait_stat(StatType.RESISTANCE, v)

func get_speed() -> int:
	var v := int(ceil(speed * StatStage.get_multiplier(stat_stages[StatType.SPEED])))
	return _apply_trait_stat(StatType.SPEED, v)

# ------------------------
# RESOURCE SAFETY
# ------------------------

func clamp_resources():
	hp = clamp(hp, 0, get_max_hp())
	energy = clamp(energy, 0, get_max_energy())

# ------------------------
# CRIT
# ------------------------
func get_crit_rate_bonus() -> float:
	return stat_stages[StatType.CRIT_RATE] * 0.05

func get_crit_damage_multiplier() -> float:
	return crit_damage_multiplier * StatStage.get_multiplier(
		stat_stages[StatType.CRIT_DAMAGE]
	)

# ------------------------
# 🩸 LIFESTEAL (TRAIT-BASED)
# ------------------------
func get_lifesteal() -> float:
	var total: float = 0.0

	for trait_effect in passive_traits:
		total += trait_effect.lifesteal_ratio

	return clamp(total, 0.0, 1.0)


# ------------------------
# TRAITS
# ------------------------
func add_trait(trait_effect: TraitData):
	if passive_traits.has(trait_effect):
		return
	passive_traits.append(trait_effect)

# ------------------------
# EFFECT HANDLING
# ------------------------
func apply_effect(effect: BattleEffect):
	effect.target = self
	active_effects.append(effect)
	effect.on_apply()

func clear_effects():
	for effect in active_effects:
		effect.on_remove()
	active_effects.clear()

# ------------------------
# COMBAT
# ------------------------
func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int):
	hp = max(hp - amount, 0)

func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


# ------------------------
# ROUND END (REGEN TRAITS)
# ------------------------
func on_round_end():
	for trait_effect in passive_traits:
		var healed_hp := 0
		var restored_energy := 0

		if trait_effect.regen_hp_ratio > 0.0:
			var heal := int(round(get_max_hp() * trait_effect.regen_hp_ratio))
			var before := hp
			hp += heal
			healed_hp = hp - before

		if trait_effect.regen_energy_ratio > 0.0:
			var restore := int(round(get_max_energy() * trait_effect.regen_energy_ratio))
			var before := energy
			energy += restore
			restored_energy = energy - before

		clamp_resources()

		if healed_hp > 0 or restored_energy > 0:
			var parts := []
			if healed_hp > 0:
				parts.append("+%d HP" % healed_hp)
			if restored_energy > 0:
				parts.append("+%d EN" % restored_energy)

			print(
				"%s gains %s due to Trait \"%s\"."
				% [data.name, " and ".join(parts), trait_effect.name]
			)
