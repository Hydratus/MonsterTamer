extends Resource
class_name MTTraitData

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

@export var name: String
@export var description: String
@export var unlock_level: int = 1

# ----------------------------
# STAT MODIFIERS
# ----------------------------
@export var stat_modifiers: Array[MTTraitStatModifier] = []

# ----------------------------
# DAMAGE MODIFIERS
# ----------------------------
@export var damage_multiplier: float = 1.0

@export var filter_damage_type: bool = false
@export var affected_damage_type: MTDamageType.Type = MTDamageType.Type.PHYSICAL

@export var filter_element: bool = false
@export var affected_element: MTElement.Type = MTElement.Type.FIRE

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
@export var round_start_stat_stage_modifiers: Array[MTTraitStatStageModifier] = []

# ----------------------------
# CONDITIONS
# ----------------------------
@export_range(0.0, 1.0)
var active_below_hp_ratio: float = 1.0

@export var only_when_attacking: bool = true
@export var only_when_defending: bool = false

# ----------------------------
# CONTACT EFFECTS
# ----------------------------
@export_range(0.0, 1.0, 0.01)
var contact_thorns_ratio: float = 0.0

@export var contact_stat_stage_modifiers: Array[MTTraitStatStageModifier] = []

func get_localized_name() -> String:
	if name == "":
		return ""
	return TranslationServer.translate(name)

func get_localized_description() -> String:
	if description == "":
		return ""
	return TranslationServer.translate(description)


# =========================================================
# DAMAGE MODIFICATION
# =========================================================
func modify_damage(
	attacker: MTMonsterInstance,
	_defender: MTMonsterInstance,
	base_damage: float,
	action: MTBattleAction
) -> float:
	if attacker == null:
		return base_damage
	if attacker.max_hp <= 0:
		return base_damage

	# ----------------------------
	# CONTEXT CHECK
	# ----------------------------
	# MTDamageCalculator = Angriff
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
		if action == null:
			return base_damage
		if action.damage_type != affected_damage_type:
			return base_damage

	# ----------------------------
	# ELEMENT FILTER
	# ----------------------------
	if filter_element:
		if action == null:
			return base_damage
		if action.attack_element != affected_element:
			return base_damage

	# ----------------------------
	# APPLY MULTIPLIER
	# ----------------------------
	return base_damage * damage_multiplier


# =========================================================
# CONTACT HOOKS
# =========================================================
func on_contact_made(
	_attacker: MTMonsterInstance,
	_target: MTMonsterInstance,
	_action: MTBattleAction
) -> void:
	# Für zukünftige offensive Kontakt-Traits reserviert.
	return

func on_contact_taken(
	owner: MTMonsterInstance,
	attacker: MTMonsterInstance,
	action: MTBattleAction
) -> void:
	if owner == null or attacker == null:
		return

	if contact_thorns_ratio > 0.0:
		var source_damage := 0
		if action != null and "last_damage_dealt" in action:
			source_damage = int(action.last_damage_dealt)

		if source_damage <= 0:
			source_damage = max(1, int(ceil(float(attacker.get_max_hp()) * 0.04)))

		var reflected: int = max(1, int(ceil(float(source_damage) * contact_thorns_ratio)))
		attacker.take_damage(reflected)
		attacker.clamp_resources()
		_log_contact(
			action,
			TranslationServer.translate("%s is hurt by %s's %s for %d contact damage!")
			% [attacker.data.name, owner.data.name, get_localized_name(), reflected]
		)

	for stat_modifier in contact_stat_stage_modifiers:
		if stat_modifier == null or stat_modifier.stage_change == 0:
			continue

		var delta := attacker.modify_stat_stage(
			stat_modifier.stat,
			stat_modifier.stage_change
		)
		if delta != 0:
			var stat_name: String = _localize_stat_name(MTMonsterInstance.StatType.keys()[stat_modifier.stat])
			var sign_prefix := "+" if delta > 0 else ""
			_log_contact(
				action,
				TranslationServer.translate("%s's %s changed by %s%d due to %s's %s!")
				% [attacker.data.name, stat_name, sign_prefix, delta, owner.data.name, get_localized_name()]
			)

func _localize_stat_name(stat_key: String) -> String:
	match stat_key:
		"MAX_HP":
			return TranslationServer.translate("HP")
		"MAX_ENERGY":
			return TranslationServer.translate("EN")
		"STRENGTH":
			return TranslationServer.translate("STR")
		"MAGIC":
			return TranslationServer.translate("MAG")
		"DEFENSE":
			return TranslationServer.translate("DEF")
		"RESISTANCE":
			return TranslationServer.translate("RES")
		"SPEED":
			return TranslationServer.translate("SPD")
		"CRIT_RATE":
			return TranslationServer.translate("Crit Rate")
		"CRIT_DAMAGE":
			return TranslationServer.translate("Crit Damage")
		_:
			return TranslationServer.translate(stat_key)

func _log_contact(action: MTBattleAction, text: String) -> void:
	if action != null and action.has_method("battle_log"):
		action.battle_log(text)
		if action.battle != null:
			action.battle.flush_action_messages()
	else:
		DEBUG_LOG.warning("TraitData", text)
