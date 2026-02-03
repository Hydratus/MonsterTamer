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
var level: int  # Instanz-spezifisches Level (nicht von MonsterData)
var decision: BattleDecision = null  # Wird vom Battle gesetzt (PlayerDecision oder AIDecision)

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
# EXPERIENCE & LEVELING
# ------------------------
var current_exp: int = 0
var exp_to_next_level: int = 0

# Tracking für Gegner, die dieses Monster bekämpft haben
var opponents_fought: Array[MonsterInstance] = []

# ------------------------
# INIT
# ------------------------
func _init(monster_data: MonsterData):
	# Dupliziere MonsterData, damit jede Instanz ihre eigene Kopie hat
	# Dies verhindert, dass Änderungen in einer Instanz andere Instanzen beeinflussen
	data = monster_data.duplicate()
	level = data.level  # Kopiere das Start-Level von MonsterData
	attacks = data.attacks.duplicate()
	_apply_learnable_attacks_up_to_level()

	for trait_effect in data.passive_traits:
		add_trait(trait_effect)

	_recalculate_stats()

	hp = get_max_hp()
	energy = get_max_energy()
	
	# Initialize EXP requirements
	exp_to_next_level = _get_required_exp_for_level(level + 1)

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
	# Nutze das instanz-spezifische Level
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
	# EXP-Verteilung wird NICHT mehr hier gemacht, sondern in AttackAction nach der Nachricht

func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


# ------------------------
# ROUND END (REGEN TRAITS)
# ------------------------
func on_round_end(logger: Callable = Callable()):
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

			var msg := "%s gains %s due to Trait \"%s\"." % [
				data.name,
				" and ".join(parts),
				trait_effect.name
			]
			if logger.is_valid():
				logger.call(msg)
			else:
				print(msg)

# ------------------------
# LEVELING UP
# ------------------------
func level_up(logger: Callable = Callable()) -> void:
	if level >= 100:
		var msg = "%s is already at max level!" % data.name
		if logger.is_valid():
			logger.call(msg)
		else:
			print(msg)
		return
	
	level += 1
	_recalculate_stats()
	hp = get_max_hp()
	energy = get_max_energy()
	
	var msg = "🎉 %s leveled up to level %d! (HP: %d | EN: %d)" % [
		data.name, level, hp, energy
	]
	if logger.is_valid():
		logger.call(msg)
	else:
		print(msg)
	
	# Check for evolution
	evolve_if_ready(logger)
	
	# Check for new attacks
	_check_attack_learning(logger)
	
	# Check for new traits
	_check_trait_learning(logger)
# Check if the monster can evolve and apply it
func evolve_if_ready(logger: Callable = Callable()) -> bool:
	if not can_evolve():
		return false
	return apply_evolution(logger)

func can_evolve() -> bool:
	if data.evolution == null:
		return false
	
	var evolution_data := data.evolution as EvolutionData
	if evolution_data == null:
		return false
	
	if level < evolution_data.evolution_level:
		return false
	
	var evolved_data := evolution_data.evolved_monster as MonsterData
	return evolved_data != null

func apply_evolution(logger: Callable = Callable()) -> bool:
	if not can_evolve():
		return false
	
	var evolution_data := data.evolution as EvolutionData
	var evolved_data := evolution_data.evolved_monster as MonsterData
	
	var old_name := data.name
	var prev_hp := hp
	var prev_energy := energy
	var prev_max_hp := get_max_hp()
	var prev_max_energy := get_max_energy()
	data = evolved_data.duplicate()
	_recalculate_stats()
	var hp_gain := get_max_hp() - prev_max_hp
	var energy_gain := get_max_energy() - prev_max_energy
	hp = clamp(prev_hp + hp_gain, 0, get_max_hp())
	energy = clamp(prev_energy + energy_gain, 0, get_max_energy())
	
	var msg := "✨ %s evolved into %s!" % [old_name, data.name]
	if logger.is_valid():
		logger.call(msg)
	else:
		print(msg)
	return true

# Get all attacks the monster can learn at current level
func get_available_attacks_to_learn() -> Array[Resource]:
	var available: Array[Resource] = []
	
	for learn_data in data.learnable_attacks:
		if learn_data == null:
			continue
		if learn_data.learn_level == level:
			available.append(learn_data)
	
	return available

func _apply_learnable_attacks_up_to_level() -> void:
	if data == null:
		return
	for learn_data in data.learnable_attacks:
		if learn_data == null:
			continue
		if learn_data.learn_level <= level and learn_data.attack != null:
			if not attacks.has(learn_data.attack):
				attacks.append(learn_data.attack)

# Check for new attacks to learn
func _check_attack_learning(logger: Callable = Callable()) -> void:
	var available_attacks = get_available_attacks_to_learn()
	
	if available_attacks.is_empty():
		return
	
	for learn_data in available_attacks:
		if learn_data.attack != null and not attacks.has(learn_data.attack):
			attacks.append(learn_data.attack)
			var msg = "⚔️ %s learned %s!" % [data.name, learn_data.attack.name]
			if logger.is_valid():
				logger.call(msg)
			else:
				print(msg)
# Get all traits the monster can learn at current level
func get_available_traits_to_learn() -> Array[Resource]:
	var available: Array[Resource] = []
	
	for learn_data in data.learnable_traits:
		if learn_data == null:
			continue
		if learn_data.learn_level == level:
			available.append(learn_data)
	
	return available

# Check for new traits to learn
func _check_trait_learning(logger: Callable = Callable()) -> void:
	var available_traits = get_available_traits_to_learn()
	
	if available_traits.is_empty():
		return
	
	for learn_data in available_traits:
		add_trait(learn_data.trait_data as TraitData)
		var msg = "✨ %s learned trait %s!" % [data.name, learn_data.trait_data.name]
		if logger.is_valid():
			logger.call(msg)
		else:
			print(msg)
# ------------------------
# EXPERIENCE SYSTEM
# ------------------------

# Gain EXP von einem besiegten Monster
# Verteilt EXP auf mehrere Monster basierend auf wer es bekämpft hat
func gain_exp(defeated_monster: MonsterInstance, contributing_monsters: Array[MonsterInstance]) -> void:
	# Filtere nur lebende Monster
	var alive_contributors: Array[MonsterInstance] = []
	for monster in contributing_monsters:
		if monster != null and monster.is_alive():
			alive_contributors.append(monster)
	
	# Wenn kein lebendes Monster den Kampf gekämpft hat, gib niemandem EXP
	if alive_contributors.is_empty():
		return
	
	var total_exp = _calculate_earned_exp(defeated_monster)
	var exp_per_monster = int(total_exp / float(alive_contributors.size()))
	
	# Verteile EXP auf alle lebenden Monster
	for monster in alive_contributors:
		if monster.is_alive():
			monster.current_exp += exp_per_monster
			print(
				"%s gained %d EXP! (Total: %d/%d)"
				% [monster.data.name, exp_per_monster, monster.current_exp, monster.exp_to_next_level]
			)
			monster._check_level_up()

# Tracking: Markiere ein Monster als Gegner in diesem Kampf
func register_opponent(opponent: MonsterInstance) -> void:
	if opponent != null and opponent not in opponents_fought:
		opponents_fought.append(opponent)

# Calculate EXP earned from defeating a monster
# Formula: (baseExp × (level + 5)) / 7
func _calculate_earned_exp(defeated_monster: MonsterInstance) -> int:
	var base_exp = defeated_monster.data.base_exp
	var defeated_level = defeated_monster.level
	
	var earned = int((base_exp * (defeated_level + 5)) / 7.0)
	return max(earned, 1)  # Minimum 1 EXP

# Check if monster(s) should level up
func _check_level_up(logger: Callable = Callable()) -> void:
	while current_exp >= exp_to_next_level and level < 100:
		current_exp -= exp_to_next_level
		level_up(logger)
		exp_to_next_level = _get_required_exp_for_level(level + 1)

# Helper function to calculate required EXP for a level
func _get_required_exp_for_level(level: int) -> int:
	# Growth rates: FAST (×12), NORMAL (×18), SLOW (×24), VERY_SLOW (×30)
	# 2-3 Kämpfe pro Level-up durchschnittlich
	var multiplier = 18
	match data.growth_rate:
		MonsterData.GrowthType.FAST: multiplier = 12
		MonsterData.GrowthType.NORMAL: multiplier = 18
		MonsterData.GrowthType.SLOW: multiplier = 24
		MonsterData.GrowthType.VERY_SLOW: multiplier = 30
	
	return level * multiplier

# Verteile EXP wenn dieses Monster stirbt (Legacy - wird nicht mehr verwendet)
# Die EXP-Verteilung wird jetzt direkt in AttackAction gehandhabt
func _distribute_exp_on_death(logger: Callable = Callable()) -> void:
	pass  # Wird nicht mehr benutzt, aber bleibt für Kompatibilität

# Helper um battle.scene.message_box.flush zu rufen wenn verfügbar
func _flush_if_battle_available(logger: Callable):
	pass  # Nicht mehr benötigt
