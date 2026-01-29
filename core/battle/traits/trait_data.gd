extends Resource
class_name TraitData

@export var name: String
@export var description: String
@export var unlock_level: int = 1

# ----------------------------
# STAT MODIFIERS
# ----------------------------
@export var stat_modifiers: Array[TraitStatModifier] = []

# ----------------------------
# DAMAGE MODIFIERS
# ----------------------------
@export var damage_multiplier: float = 1.0

@export var filter_damage_type: bool = false
@export var affected_damage_type: DamageType.Type = DamageType.Type.PHYSICAL

@export var filter_element: bool = false
@export var affected_element: Element.Type = Element.Type.NORMAL

@export_range(0.0, 1.0, 0.01)
var lifesteal_ratio: float = 0.0

# ----------------------------
# TURN BASED EFFECTS
# ----------------------------
@export_range(0.0, 1.0, 0.01)
var regen_hp_ratio: float = 0.0

@export_range(0.0, 1.0, 0.01)
var regen_energy_ratio: float = 0.0

# ----------------------------
# ROUND START EFFECTS
# ----------------------------
@export var round_start_stat: MonsterInstance.StatType = -1

@export_range(-6, 6)
var round_start_stages: int = 0

# ----------------------------
# CONDITIONS
# ----------------------------
@export_range(0.0, 1.0)
var active_below_hp_ratio: float = 1.0

@export var only_when_attacking: bool = true
@export var only_when_defending: bool = false


# =========================================================
# DAMAGE MODIFICATION
# =========================================================
func modify_damage(
	attacker: MonsterInstance,
	defender: MonsterInstance,
	base_damage: float,
	action: BattleAction
) -> float:

	# ----------------------------
	# CONTEXT CHECK
	# ----------------------------
	# DamageCalculator = Angriff
	if only_when_defending:
		return base_damage

	if not only_when_attacking:
		return base_damage

	# ----------------------------
	# HP CONDITION
	# ----------------------------
	var hp_ratio := attacker.hp / float(attacker.max_hp)
	if hp_ratio > active_below_hp_ratio:
		return base_damage

	# ----------------------------
	# DAMAGE TYPE FILTER
	# ----------------------------
	if filter_damage_type:
		if action.damage_type != affected_damage_type:
			return base_damage

	# ----------------------------
	# ELEMENT FILTER
	# ----------------------------
	if filter_element:
		if action.attack_element != affected_element:
			return base_damage

	# ----------------------------
	# APPLY MULTIPLIER
	# ----------------------------
	return base_damage * damage_multiplier
