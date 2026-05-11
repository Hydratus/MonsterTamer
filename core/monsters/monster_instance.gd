extends RefCounted
class_name MTMonsterInstance

const BalanceConstants = preload("res://core/systems/game_balance_constants.gd")
const StatusAilmentClass = preload("res://core/battle/status/status_ailment.gd")

# Cache for effective stats (includes stat stages + trait modifiers)
# Only recalculated when stat stages change or traits change
var _cached_effective_stats: Dictionary = {}
var _stat_cache_valid := false

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
var data: MTMonsterData
var level: int  # Instanz-spezifisches Level (nicht von MTMonsterData)
var decision: MTBattleDecision = null  # Wird vom Battle gesetzt (MTPlayerDecision oder MTAIDecision)

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
var active_effects: Array[MTBattleEffect] = []
var passive_traits: Array[MTTraitData] = []
var status_durations: Dictionary = {}

# ------------------------
# ATTACKS
# ------------------------
var attacks: Array[MTAttackData] = []

# ------------------------
# EXPERIENCE & LEVELING
# ------------------------
var current_exp: int = 0
var exp_to_next_level: int = 0

# Tracking für Gegner, die dieses Monster bekämpft haben
var opponents_fought: Array[MTMonsterInstance] = []
var attack_forget_selector: Callable = Callable()
var trait_forget_selector: Callable = Callable()

# ------------------------
# INIT
# ------------------------
func _init(monster_data: MTMonsterData):
	# Keep shared monster data resource and only store instance-specific runtime state.
	data = monster_data
	level = data.level  # Start with the configured base level from data
	attacks = []
	for base_attack in data.attacks:
		_learn_attack_with_limit(base_attack, Callable(), false)
	_apply_learnable_attacks_up_to_level()

	for trait_effect in data.passive_traits:
		_learn_trait_with_limit(trait_effect, Callable(), false)
	_apply_learnable_traits_up_to_level()

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
	_invalidate_stat_cache()  # Invalidate after recalculation

# Calculate actual stats based on base stats and level
func _apply_level_scaling():
	# Nutze das instanz-spezifische Level
	# HP: ((STAT_SCALE_MULTIPLIER × base_max_hp × level) / STAT_SCALE_DIVISOR) + level + HP_LEVEL_BONUS
	max_hp = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_max_hp * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + level + BalanceConstants.HP_LEVEL_BONUS
	
	# Energy: ((STAT_SCALE_MULTIPLIER × base_max_energy × level) / STAT_SCALE_DIVISOR) + ENERGY_BASE_BONUS + floor(level / ENERGY_LEVEL_BONUS_STEP)
	max_energy = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_max_energy * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.ENERGY_BASE_BONUS + int(floor(float(level) / float(BalanceConstants.ENERGY_LEVEL_BONUS_STEP)))
	
	# Stats: ((STAT_SCALE_MULTIPLIER × base_stat × level) / STAT_SCALE_DIVISOR) + STAT_BASE_BONUS
	strength = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_strength * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.STAT_BASE_BONUS
	magic = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_magic * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.STAT_BASE_BONUS
	defense = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_defense * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.STAT_BASE_BONUS
	resistance = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_resistance * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.STAT_BASE_BONUS
	speed = int(ceil((BalanceConstants.STAT_SCALE_MULTIPLIER * data.base_speed * level) / BalanceConstants.STAT_SCALE_DIVISOR)) + BalanceConstants.STAT_BASE_BONUS


# ------------------------
# STAT STAGES
# ------------------------
func reset_stat_stages():
	for key in stat_stages.keys():
		stat_stages[key] = 0
	_invalidate_stat_cache()

func modify_stat_stage(stat: int, amount: int) -> int:
	var before: int = stat_stages[stat]
	var after: int = MTStatStage.clamp_stage(before + amount)
	stat_stages[stat] = after
	_invalidate_stat_cache()  # Cache invalidated when stages change
	return after - before

## Invalidate stat cache - call when traits change or stat stages change
func _invalidate_stat_cache() -> void:
	_stat_cache_valid = false
	_cached_effective_stats.clear()

## Recalculate and cache all effective stats at once
func _rebuild_stat_cache() -> void:
	if _stat_cache_valid:
		return  # Cache is still valid
	
	_cached_effective_stats[StatType.MAX_HP] = _apply_trait_stat(StatType.MAX_HP, 
		int(ceil(max_hp * MTStatStage.get_multiplier(stat_stages[StatType.MAX_HP]))))
	_cached_effective_stats[StatType.MAX_ENERGY] = _apply_trait_stat(StatType.MAX_ENERGY,
		int(ceil(max_energy * MTStatStage.get_multiplier(stat_stages[StatType.MAX_ENERGY]))))
	_cached_effective_stats[StatType.STRENGTH] = _apply_trait_stat(StatType.STRENGTH,
		int(ceil(strength * MTStatStage.get_multiplier(stat_stages[StatType.STRENGTH]))))
	_cached_effective_stats[StatType.MAGIC] = _apply_trait_stat(StatType.MAGIC,
		int(ceil(magic * MTStatStage.get_multiplier(stat_stages[StatType.MAGIC]))))
	_cached_effective_stats[StatType.DEFENSE] = _apply_trait_stat(StatType.DEFENSE,
		int(ceil(defense * MTStatStage.get_multiplier(stat_stages[StatType.DEFENSE]))))
	_cached_effective_stats[StatType.RESISTANCE] = _apply_trait_stat(StatType.RESISTANCE,
		int(ceil(resistance * MTStatStage.get_multiplier(stat_stages[StatType.RESISTANCE]))))
	_cached_effective_stats[StatType.SPEED] = _apply_trait_stat(StatType.SPEED,
		int(ceil(speed * MTStatStage.get_multiplier(stat_stages[StatType.SPEED]))))
	
	_stat_cache_valid = true

func _emit_log(logger: Callable, message: String) -> void:
	if logger.is_valid():
		logger.call(message)

# ------------------------
# EFFECTIVE STATS (STAT STAGES + TRAITS)
# ------------------------
func _apply_trait_stat(stat: int, value: int) -> int:
	var result := value

	for trait_effect in passive_traits:
		if trait_effect == null:
			continue
		for mod in trait_effect.stat_modifiers:
			if mod == null:
				continue
			if mod.stat != stat:
				continue

			# Flat zuerst
			result += mod.flat_bonus
			# Danach Multiplier
			result = int(ceil(result * mod.multiplier))

	return result

func get_max_hp() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.MAX_HP, max_hp)
	
func get_max_energy() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.MAX_ENERGY, max_energy)

func get_strength() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.STRENGTH, strength)

func get_magic() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.MAGIC, magic)

func get_defense() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.DEFENSE, defense)

func get_resistance() -> int:
	_rebuild_stat_cache()
	return _cached_effective_stats.get(StatType.RESISTANCE, resistance)

func get_speed() -> int:
	_rebuild_stat_cache()
	var base_speed: int = _cached_effective_stats.get(StatType.SPEED, speed)
	return max(1, int(ceil(float(base_speed) * get_speed_multiplier_from_status())))

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
	return crit_damage_multiplier * MTStatStage.get_multiplier(
		stat_stages[StatType.CRIT_DAMAGE]
	)

# ------------------------
# 🩸 LIFESTEAL (TRAIT-BASED)
# ------------------------
func get_lifesteal() -> float:
	if has_status(StatusAilmentClass.Type.CURSED):
		return 0.0

	var total: float = 0.0

	for trait_effect in passive_traits:
		if trait_effect == null:
			continue
		total += trait_effect.lifesteal_ratio

	return clamp(total, 0.0, 1.0)

func has_status(status_type: int) -> bool:
	if status_type == StatusAilmentClass.Type.NONE:
		return false
	return status_durations.has(status_type)

func get_status_duration(status_type: int) -> int:
	if not has_status(status_type):
		return 0
	return int(status_durations[status_type])

func apply_status(status_type: int, duration: int = 0) -> bool:
	if not StatusAilmentClass.is_persistent(status_type):
		return false

	var final_duration := duration
	if final_duration <= 0:
		final_duration = StatusAilmentClass.default_duration(status_type)
	if final_duration <= 0:
		return false

	if has_status(status_type):
		status_durations[status_type] = max(int(status_durations[status_type]), final_duration)
		return false

	status_durations[status_type] = final_duration
	# Wet is removed when frozen
	if status_type == StatusAilmentClass.Type.FREEZE:
		remove_status(StatusAilmentClass.Type.WET)
	return true

func remove_status(status_type: int) -> bool:
	if not has_status(status_type):
		return false
	status_durations.erase(status_type)
	return true

func clear_negative_statuses() -> int:
	var removed := 0
	for status_type in status_durations.keys().duplicate():
		if int(status_type) == StatusAilmentClass.Type.NONE:
			continue
		status_durations.erase(status_type)
		removed += 1
	return removed

func get_status_labels() -> Array[String]:
	var labels: Array[String] = []
	for raw_status in status_durations.keys():
		var status_type := int(raw_status)
		var turns := int(status_durations[raw_status])
		labels.append("%s(%d)" % [StatusAilmentClass.display_name(status_type), turns])
	labels.sort()
	return labels

func get_accuracy_multiplier_from_status() -> float:
	var multiplier := 1.0
	if has_status(StatusAilmentClass.Type.BLIND):
		multiplier *= 0.70
	if has_status(StatusAilmentClass.Type.DAZE):
		multiplier *= 0.85
	if has_status(StatusAilmentClass.Type.BIND):
		multiplier *= 0.90
	return multiplier

func get_speed_multiplier_from_status() -> float:
	var multiplier := 1.0
	if has_status(StatusAilmentClass.Type.PARALYZE):
		multiplier *= 0.75
	if has_status(StatusAilmentClass.Type.ROOT):
		multiplier *= 0.80
	if has_status(StatusAilmentClass.Type.BIND):
		multiplier *= 0.90
	if has_status(StatusAilmentClass.Type.BLEED):
		multiplier *= 0.85
	return multiplier

func can_switch_out() -> bool:
	return not has_status(StatusAilmentClass.Type.ROOT) and not has_status(StatusAilmentClass.Type.BIND)

func get_outgoing_damage_multiplier(action) -> float:
	if action == null:
		return 1.0

	var multiplier := 1.0
	if has_status(StatusAilmentClass.Type.BURN) and action.damage_type == MTDamageType.Type.PHYSICAL:
		multiplier *= 0.67
	if has_status(StatusAilmentClass.Type.WET) and action.attack_element == MTElement.Type.FIRE:
		multiplier *= 0.67
	return multiplier

func get_incoming_damage_multiplier(action) -> float:
	if action == null:
		return 1.0

	var multiplier := 1.0
	if has_status(StatusAilmentClass.Type.WET):
		if action.attack_element == MTElement.Type.FIRE:
			multiplier *= 0.67
		elif action.attack_element == MTElement.Type.ELECTRIC:
			multiplier *= 1.33
	return multiplier

func can_receive_healing() -> bool:
	return not has_status(StatusAilmentClass.Type.CURSED)

func process_pre_action_status(logger: Callable = Callable()) -> bool:
	if has_status(StatusAilmentClass.Type.STAGGER):
		remove_status(StatusAilmentClass.Type.STAGGER)
		_emit_log(logger, "%s staggers and loses the turn!" % data.name)
		return false

	if has_status(StatusAilmentClass.Type.SLEEP):
		if randf() <= 0.20:
			remove_status(StatusAilmentClass.Type.SLEEP)
			_emit_log(logger, "%s woke up on its own and can act!" % data.name)
		else:
			_emit_log(logger, "%s is asleep and cannot move!" % data.name)
			return false

	if has_status(StatusAilmentClass.Type.FREEZE):
		if randf() <= 0.75:
			_emit_log(logger, "%s is frozen solid!" % data.name)
			return false
		remove_status(StatusAilmentClass.Type.FREEZE)
		_emit_log(logger, "%s thawed out!" % data.name)

	if has_status(StatusAilmentClass.Type.PARALYZE) and randf() <= 0.30:
		_emit_log(logger, "%s is paralyzed and cannot act!" % data.name)
		return false

	if has_status(StatusAilmentClass.Type.FEAR) and randf() <= 0.25:
		_emit_log(logger, "%s is afraid and hesitates!" % data.name)
		return false

	if has_status(StatusAilmentClass.Type.DAZE) and randf() <= 0.33:
		_emit_log(logger, "%s is dazed and loses focus!" % data.name)
		return false

	return true

func _decrement_status_durations() -> void:
	for raw_status in status_durations.keys().duplicate():
		var remaining := int(status_durations[raw_status]) - 1
		if remaining <= 0:
			status_durations.erase(raw_status)
		else:
			status_durations[raw_status] = remaining

func _apply_dot_statuses(logger: Callable = Callable()) -> void:
	if not is_alive():
		return

	var dot_total := 0
	if has_status(StatusAilmentClass.Type.BURN):
		dot_total += int(ceil(get_max_hp() * 0.06))
	if has_status(StatusAilmentClass.Type.POISON):
		dot_total += int(ceil(get_max_hp() * 0.12))
	if has_status(StatusAilmentClass.Type.BLEED):
		dot_total += int(ceil(get_max_hp() * 0.05))
	if has_status(StatusAilmentClass.Type.CURSED):
		dot_total += int(ceil(get_max_hp() * 0.04))

	if dot_total <= 0:
		return

	var before: int = hp
	take_damage(dot_total)
	clamp_resources()
	var dealt: int = max(0, before - hp)
	if dealt > 0:
		_emit_log(logger, "%s suffers %d damage from status effects." % [data.name, dealt])


# ------------------------
# TRAITS
# ------------------------
func add_trait(trait_effect: MTTraitData):
	_learn_trait_with_limit(trait_effect, Callable(), false)

# ------------------------
# EFFECT HANDLING
# ------------------------
func apply_effect(effect: MTBattleEffect):
	effect.target = self
	active_effects.append(effect)
	effect.on_apply()

func clear_effects():
	for effect in active_effects:
		effect.on_remove()
	active_effects.clear()
	_invalidate_stat_cache()  # Effects cleared, may affect stats

# ------------------------
# COMBAT
# ------------------------
func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int):
	hp = max(hp - amount, 0)
	# EXP-Verteilung wird NICHT mehr hier gemacht, sondern in MTAttackAction nach der Nachricht

func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


# ------------------------
# ROUND END (REGEN TRAITS)
# ------------------------
func on_round_end(logger: Callable = Callable()):
	_apply_dot_statuses(logger)

	for trait_effect in passive_traits:
		if trait_effect == null:
			continue
		var healed_hp := 0
		var restored_energy := 0

		if trait_effect.regen_hp_ratio > 0.0:
			var heal := int(round(get_max_hp() * trait_effect.regen_hp_ratio))
			if not can_receive_healing():
				heal = 0
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
			_emit_log(logger, msg)

	_decrement_status_durations()

# ------------------------
# LEVELING UP
# ------------------------
func level_up(logger: Callable = Callable()) -> void:
	if level >= 100:
		var max_level_msg: String = "%s is already at max level!" % data.name
		_emit_log(logger, max_level_msg)
		return
	
	level += 1
	_recalculate_stats()
	hp = get_max_hp()
	energy = get_max_energy()
	
	var level_up_msg: String = "🎉 %s leveled up to level %d! (HP: %d | EN: %d)" % [
		data.name, level, hp, energy
	]
	_emit_log(logger, level_up_msg)
	
	# Check for evolution
	evolve_if_ready(logger)
	
	# Check for new attacks
	_check_attack_learning(logger)
	
	# Check for new traits
	_check_trait_learning(logger)
# Check if the monster can evolve and apply it
func evolve_if_ready(logger: Callable = Callable()) -> bool:
	var available_evolutions := get_available_evolutions()
	if available_evolutions.is_empty():
		return false
	var target_monster: MTMonsterData = available_evolutions[0].get("target_monster", null)
	return apply_evolution(logger, target_monster)

func can_evolve(context: Dictionary = {}) -> bool:
	return not get_available_evolutions(context).is_empty()

func get_available_evolutions(context: Dictionary = {}) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for raw_entry in _get_evolution_entries():
		var evolution_entry := _extract_evolution_data(raw_entry)
		if evolution_entry.is_empty():
			continue
		if not _evolution_conditions_met(evolution_entry, context):
			continue
		available.append(evolution_entry)
	return available

func apply_evolution(logger: Callable = Callable(), target_monster: MTMonsterData = null, context: Dictionary = {}) -> bool:
	var selected_evolution := _select_evolution(target_monster, context)
	if selected_evolution.is_empty():
		return false
	
	var evolved_data: MTMonsterData = selected_evolution.get("target_monster", null)
	if evolved_data == null:
		return false
	
	var old_name := data.name
	var prev_hp := hp
	var prev_energy := energy
	var prev_max_hp := get_max_hp()
	var prev_max_energy := get_max_energy()
	data = evolved_data
	_recalculate_stats()
	var hp_gain := get_max_hp() - prev_max_hp
	var energy_gain := get_max_energy() - prev_max_energy
	hp = clamp(prev_hp + hp_gain, 0, get_max_hp())
	energy = clamp(prev_energy + energy_gain, 0, get_max_energy())
	
	var msg := "✨ %s evolved into %s!" % [old_name, data.name]
	_emit_log(logger, msg)
	return true

func _get_evolution_entries() -> Array:
	if data == null:
		return []
	if not data.evolutions.is_empty():
		return data.evolutions
	if data.evolution != null:
		return [data.evolution]
	return []

func _extract_evolution_data(raw_entry) -> Dictionary:
	if raw_entry == null:
		return {}
	if _is_evolution_entry_resource(raw_entry):
		var target_monster: MTMonsterData = _resource_prop(raw_entry, "target_monster", null)
		if target_monster == null:
			return {}
		var normalized := {
			"target_monster": target_monster,
			"min_level": max(1, int(_resource_prop(raw_entry, "min_level", 1)))
		}
		var label := str(_resource_prop(raw_entry, "label", "")).strip_edges()
		if label != "":
			normalized["label"] = label
		var required_attack: MTAttackData = _resource_prop(raw_entry, "required_attack", null)
		if required_attack != null:
			normalized["required_attack"] = required_attack
		var required_trait: MTTraitData = _resource_prop(raw_entry, "required_trait", null)
		if required_trait != null:
			normalized["required_trait"] = required_trait
		var required_item_ids: Array[String] = []
		var single_item_id := str(_resource_prop(raw_entry, "required_item_id", "")).strip_edges()
		if single_item_id != "":
			required_item_ids.append(single_item_id)
		for item_value in _resource_prop(raw_entry, "required_item_ids", []):
			var item_id := str(item_value).strip_edges()
			if item_id != "" and not required_item_ids.has(item_id):
				required_item_ids.append(item_id)
		if not required_item_ids.is_empty():
			normalized["required_item_ids"] = required_item_ids
		var raw_required_elements: Array = _resource_prop(raw_entry, "required_elements", [])
		if not raw_required_elements.is_empty():
			var required_elements: Array[int] = []
			for element_value in raw_required_elements:
				required_elements.append(int(element_value))
			normalized["required_elements"] = required_elements
		var required_flags: Array[String] = []
		var single_flag := str(_resource_prop(raw_entry, "required_flag", "")).strip_edges()
		if single_flag != "":
			required_flags.append(single_flag)
		for flag_value in _resource_prop(raw_entry, "required_flags", []):
			var flag_name := str(flag_value).strip_edges()
			if flag_name != "" and not required_flags.has(flag_name):
				required_flags.append(flag_name)
		if not required_flags.is_empty():
			normalized["required_flags"] = required_flags
		return normalized
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var target_monster: MTMonsterData = entry.get("target_monster", entry.get("evolved_monster", entry.get("monster", null)))
		if target_monster == null:
			return {}
		var normalized := {
			"target_monster": target_monster,
			"min_level": max(1, int(entry.get("min_level", entry.get("evolution_level", 1))))
		}
		var label := str(entry.get("label", "")).strip_edges()
		if label != "":
			normalized["label"] = label
		var required_attack: MTAttackData = entry.get("required_attack", entry.get("attack", null))
		if required_attack != null:
			normalized["required_attack"] = required_attack
		var required_trait: MTTraitData = entry.get("required_trait", entry.get("trait_data", entry.get("trait", null)))
		if required_trait != null:
			normalized["required_trait"] = required_trait
		var required_item_ids: Array[String] = []
		for item_value in entry.get("required_item_ids", []):
			var item_id := str(item_value).strip_edges()
			if item_id != "":
				required_item_ids.append(item_id)
		var single_item_id := str(entry.get("required_item_id", "")).strip_edges()
		if single_item_id != "":
			required_item_ids.append(single_item_id)
		if not required_item_ids.is_empty():
			normalized["required_item_ids"] = required_item_ids
		if entry.has("required_elements"):
			var required_elements: Array[int] = []
			for element_value in entry.get("required_elements", []):
				required_elements.append(int(element_value))
			if not required_elements.is_empty():
				normalized["required_elements"] = required_elements
		var required_flags: Array[String] = []
		for flag_value in entry.get("required_flags", []):
			var flag_name := str(flag_value).strip_edges()
			if flag_name != "":
				required_flags.append(flag_name)
		var single_flag := str(entry.get("required_flag", "")).strip_edges()
		if single_flag != "":
			required_flags.append(single_flag)
		if not required_flags.is_empty():
			normalized["required_flags"] = required_flags
		return normalized
	var legacy_evolution := raw_entry as MTEvolutionData
	if legacy_evolution == null:
		return {}
	var legacy_target := legacy_evolution.evolved_monster as MTMonsterData
	if legacy_target == null:
		return {}
	return {
		"target_monster": legacy_target,
		"min_level": max(1, legacy_evolution.evolution_level)
	}

func _is_evolution_entry_resource(raw_entry) -> bool:
	if not raw_entry is Resource:
		return false
	var script_resource: Script = raw_entry.get_script()
	if script_resource == null:
		return false
	return script_resource.resource_path == "res://core/monsters/evolution_entry_data.gd"

func _resource_prop(resource: Resource, property_name: String, default_value = null):
	if resource == null:
		return default_value
	var value = resource.get(property_name)
	if value == null:
		return default_value
	return value

func _evolution_conditions_met(evolution_entry: Dictionary, context: Dictionary = {}) -> bool:
	var target_monster: MTMonsterData = evolution_entry.get("target_monster", null)
	if target_monster == null:
		return false
	var min_level: int = int(evolution_entry.get("min_level", 1))
	if level < min_level:
		return false
	var required_attack: MTAttackData = evolution_entry.get("required_attack", null)
	if required_attack != null and not attacks.has(required_attack):
		return false
	var required_trait: MTTraitData = evolution_entry.get("required_trait", null)
	if required_trait != null and not passive_traits.has(required_trait):
		return false
	var required_item_ids: Array = evolution_entry.get("required_item_ids", [])
	if not required_item_ids.is_empty():
		var used_item_id := str(context.get("used_item_id", "")).strip_edges()
		if used_item_id == "":
			return false
		var item_match := false
		for raw_item_id in required_item_ids:
			if str(raw_item_id) == used_item_id:
				item_match = true
				break
		if not item_match:
			return false
	for element_value in evolution_entry.get("required_elements", []):
		if data == null or not data.elements.has(int(element_value)):
			return false
	for flag_value in evolution_entry.get("required_flags", []):
		var flag_name := str(flag_value).strip_edges()
		if flag_name == "":
			continue
		if not bool(context.get(flag_name, false)):
			return false
	return true

func _select_evolution(target_monster: MTMonsterData, context: Dictionary = {}) -> Dictionary:
	var available_evolutions := get_available_evolutions(context)
	if available_evolutions.is_empty():
		return {}
	if target_monster == null:
		return available_evolutions[0]
	for evolution_entry in available_evolutions:
		var candidate: MTMonsterData = evolution_entry.get("target_monster", null)
		if candidate == target_monster:
			return evolution_entry
	return {}

func _extract_attack_learn_data(raw_entry) -> Dictionary:
	if raw_entry == null:
		return {}
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var attack: MTAttackData = entry.get("attack", null)
		var learn_level: int = int(entry.get("learn_level", 1))
		if attack == null:
			return {}
		return {
			"attack": attack,
			"learn_level": max(1, learn_level)
		}
	var attack_from_resource: MTAttackData = raw_entry.attack if raw_entry.get("attack") != null else null
	if attack_from_resource == null:
		return {}
	return {
		"attack": attack_from_resource,
		"learn_level": max(1, int(raw_entry.learn_level if raw_entry.get("learn_level") != null else 1))
	}

func _extract_trait_learn_data(raw_entry) -> Dictionary:
	if raw_entry == null:
		return {}
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var trait_effect: MTTraitData = entry.get("trait", entry.get("trait_data", null))
		var learn_level: int = int(entry.get("learn_level", 1))
		if trait_effect == null:
			return {}
		return {
			"trait_data": trait_effect,
			"learn_level": max(1, learn_level)
		}
	var trait_from_resource: MTTraitData = raw_entry.trait_data if raw_entry.get("trait_data") != null else null
	if trait_from_resource == null:
		return {}
	return {
		"trait_data": trait_from_resource,
		"learn_level": max(1, int(raw_entry.learn_level if raw_entry.get("learn_level") != null else 1))
	}

# Get all attacks the monster can learn at current level
func get_available_attacks_to_learn() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	
	for raw_entry in data.learnable_attacks:
		var learn_data: Dictionary = _extract_attack_learn_data(raw_entry)
		if learn_data.is_empty():
			continue
		if int(learn_data.get("learn_level", 1)) == level:
			available.append(learn_data)
	
	return available

func _apply_learnable_attacks_up_to_level() -> void:
	if data == null:
		return
	for raw_entry in data.learnable_attacks:
		var learn_data: Dictionary = _extract_attack_learn_data(raw_entry)
		if learn_data.is_empty():
			continue
		var learn_level: int = int(learn_data.get("learn_level", 1))
		var attack: MTAttackData = learn_data.get("attack", null)
		if learn_level <= level and attack != null:
			_learn_attack_with_limit(attack, Callable(), false)

func learn_attack_with_limit(attack: MTAttackData, logger: Callable = Callable()) -> bool:
	return _learn_attack_with_limit(attack, logger, true)

func _learn_attack_with_limit(attack: MTAttackData, logger: Callable, emit_messages: bool) -> bool:
	if attack == null:
		return false
	if attacks.has(attack):
		return false

	var attack_name := TranslationServer.translate(attack.name)
	if attacks.size() < BalanceConstants.MAX_LEARNED_ATTACKS:
		attacks.append(attack)
		if emit_messages:
			var learned_msg := TranslationServer.translate("%s learned %s!") % [data.name, attack_name]
			_emit_log(logger, learned_msg)
		return true

	var candidates: Array[MTAttackData] = attacks.duplicate()
	candidates.append(attack)
	var forget_index := _choose_attack_forget_index(candidates)
	if forget_index < 0 or forget_index >= candidates.size():
		forget_index = candidates.size() - 1

	if forget_index == candidates.size() - 1:
		if emit_messages:
			var skip_msg := TranslationServer.translate("%s could not learn %s.") % [data.name, attack_name]
			_emit_log(logger, skip_msg)
		return true

	var forgotten_attack := attacks[forget_index]
	attacks[forget_index] = attack
	if emit_messages:
		var forgot_msg := TranslationServer.translate("%s forgot %s and learned %s!") % [
			data.name,
			TranslationServer.translate(forgotten_attack.name),
			attack_name
		]
		_emit_log(logger, forgot_msg)
	return true

func _choose_attack_forget_index(candidates: Array[MTAttackData]) -> int:
	if candidates.is_empty():
		return -1
	if attack_forget_selector.is_valid():
		return _resolve_forget_index(attack_forget_selector, candidates, candidates.size() - 1)

	var weakest_index := 0
	var weakest_score := _attack_keep_score(candidates[0])
	for i in range(1, candidates.size()):
		var score := _attack_keep_score(candidates[i])
		if score < weakest_score:
			weakest_score = score
			weakest_index = i
	return weakest_index

func _attack_keep_score(attack: MTAttackData) -> float:
	if attack == null:
		return -1000000.0
	var score := float(attack.power)
	score += clamp(float(attack.accuracy), 0.0, 100.0) * 0.01
	if attack.damage_type == MTDamageType.Type.STATUS:
		score -= 10.0
	return score

func _resolve_forget_index(selector: Callable, candidates: Array, fallback_index: int) -> int:
	if not selector.is_valid():
		return fallback_index
	var selected = selector.call(candidates, self)
	if selected is int:
		var selected_index := int(selected)
		if selected_index >= 0 and selected_index < candidates.size():
			return selected_index
	return fallback_index

# Check for new attacks to learn
func _check_attack_learning(logger: Callable = Callable()) -> void:
	var available_attacks = get_available_attacks_to_learn()
	
	if available_attacks.is_empty():
		return
	
	for learn_data in available_attacks:
		var attack: MTAttackData = learn_data.get("attack", null)
		if attack != null:
			learn_attack_with_limit(attack, logger)
# Get all traits the monster can learn at current level
func get_available_traits_to_learn() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	
	for raw_entry in data.learnable_traits:
		var learn_data: Dictionary = _extract_trait_learn_data(raw_entry)
		if learn_data.is_empty():
			continue
		if int(learn_data.get("learn_level", 1)) == level:
			available.append(learn_data)
	
	return available

func _apply_learnable_traits_up_to_level() -> void:
	if data == null:
		return
	for raw_entry in data.learnable_traits:
		var learn_data: Dictionary = _extract_trait_learn_data(raw_entry)
		if learn_data.is_empty():
			continue
		var learn_level: int = int(learn_data.get("learn_level", 1))
		var trait_data: MTTraitData = learn_data.get("trait_data", null)
		if learn_level <= level and trait_data != null:
			_learn_trait_with_limit(trait_data, Callable(), false)

# Check for new traits to learn
func _check_trait_learning(logger: Callable = Callable()) -> void:
	var available_traits = get_available_traits_to_learn()
	
	if available_traits.is_empty():
		return
	
	for learn_data in available_traits:
		var trait_data: MTTraitData = learn_data.get("trait_data", null)
		if trait_data != null:
			learn_trait_with_limit(trait_data, logger)

func learn_trait_with_limit(trait_effect: MTTraitData, logger: Callable = Callable()) -> bool:
	return _learn_trait_with_limit(trait_effect, logger, true)

func _learn_trait_with_limit(trait_effect: MTTraitData, logger: Callable, emit_messages: bool) -> bool:
	if trait_effect == null:
		return false
	if passive_traits.has(trait_effect):
		return false

	var prev_max_hp := get_max_hp()
	var prev_max_energy := get_max_energy()

	var trait_name := _get_localized_trait_name(trait_effect)
	if passive_traits.size() < BalanceConstants.MAX_LEARNED_TRAITS:
		passive_traits.append(trait_effect)
		_invalidate_stat_cache()  # Traits affect stat calculation
		_apply_trait_resource_gain(prev_max_hp, prev_max_energy)
		if emit_messages:
			var learned_msg := TranslationServer.translate("%s learned trait %s!") % [data.name, trait_name]
			_emit_log(logger, learned_msg)
		return true

	var candidates: Array[MTTraitData] = passive_traits.duplicate()
	candidates.append(trait_effect)
	var forget_index := _choose_trait_forget_index(candidates)
	if forget_index < 0 or forget_index >= candidates.size():
		forget_index = candidates.size() - 1

	if forget_index == candidates.size() - 1:
		if emit_messages:
			var skip_msg := TranslationServer.translate("%s could not learn trait %s.") % [data.name, trait_name]
			_emit_log(logger, skip_msg)
		return true

	var forgotten_trait := passive_traits[forget_index]
	passive_traits[forget_index] = trait_effect
	_invalidate_stat_cache()  # Traits affect stat calculation
	_apply_trait_resource_gain(prev_max_hp, prev_max_energy)
	if emit_messages:
		var forgot_msg := TranslationServer.translate("%s forgot trait %s and learned trait %s!") % [
			data.name,
			_get_localized_trait_name(forgotten_trait),
			trait_name
		]
		_emit_log(logger, forgot_msg)
	return true

func _apply_trait_resource_gain(prev_max_hp: int, prev_max_energy: int) -> void:
	var hp_gain := get_max_hp() - prev_max_hp
	var energy_gain := get_max_energy() - prev_max_energy
	if hp_gain > 0:
		hp = clamp(hp + hp_gain, 0, get_max_hp())
	if energy_gain > 0:
		energy = clamp(energy + energy_gain, 0, get_max_energy())

func _choose_trait_forget_index(candidates: Array[MTTraitData]) -> int:
	if candidates.is_empty():
		return -1
	var fallback_index := candidates.size() - 1
	return _resolve_forget_index(trait_forget_selector, candidates, fallback_index)

func _get_localized_trait_name(trait_data: MTTraitData) -> String:
	if trait_data == null:
		return TranslationServer.translate("Unknown")
	if trait_data.has_method("get_localized_name"):
		return str(trait_data.get_localized_name())
	return TranslationServer.translate(trait_data.name)
# ------------------------
# EXPERIENCE SYSTEM
# ------------------------

# Gain EXP von einem besiegten Monster
# Verteilt EXP auf mehrere Monster basierend auf wer es bekämpft hat
func gain_exp(defeated_monster: MTMonsterInstance, contributing_monsters: Array[MTMonsterInstance]) -> void:
	# Filtere nur lebende Monster
	var alive_contributors: Array[MTMonsterInstance] = []
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
			monster._check_level_up()

# Tracking: Markiere ein Monster als Gegner in diesem Kampf
func register_opponent(opponent: MTMonsterInstance) -> void:
	if opponent != null and opponent not in opponents_fought:
		opponents_fought.append(opponent)

# Calculate EXP earned from defeating a monster
# Formula: (baseExp × (level + 5)) / 7
func _calculate_earned_exp(defeated_monster: MTMonsterInstance) -> int:
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
func _get_required_exp_for_level(target_level: int) -> int:
	# Growth rates: FAST (×12), NORMAL (×18), SLOW (×24), VERY_SLOW (×30)
	# 2-3 Kämpfe pro Level-up durchschnittlich
	var multiplier = 18
	match data.growth_rate:
		MTMonsterData.GrowthType.FAST: multiplier = 12
		MTMonsterData.GrowthType.NORMAL: multiplier = 18
		MTMonsterData.GrowthType.SLOW: multiplier = 24
		MTMonsterData.GrowthType.VERY_SLOW: multiplier = 30
	
	return target_level * multiplier

