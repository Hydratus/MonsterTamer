extends BattleAction
class_name AttackAction

# --------------------------------------------------
# ATTACK DATA
# --------------------------------------------------
var power: int = 0
var energy_cost: int = 0

@export_range(0, 100)
var accuracy: int = 100

var attack_element: Element.Type = Element.Type.NORMAL
var damage_type: DamageType.Type = DamageType.Type.PHYSICAL

# 🩸 Attack-eigener Lifesteal (z. B. Drain Bite)
@export_range(0.0, 1.0, 0.01)
var lifesteal: float = 0.0

# --------------------------------------------------
# CRIT SYSTEM
# --------------------------------------------------
@export_range(0.0, 1.0)
var crit_rate: float = 0.10
var crit_multiplier: float = 1.5

# --------------------------------------------------
# STAT CHANGES (BUFFS / DEBUFFS)
# --------------------------------------------------
var stat_changes: Array[StatChangeData] = []

# --------------------------------------------------
# TARGET TEAM (statt target direkt, um dynamische Wechsel zu unterstützen)
# --------------------------------------------------
var opponent_team: MonsterTeam = null  # Das gegnerische Team

# --------------------------------------------------
# EXECUTE
# --------------------------------------------------
func execute(controller = null) -> Variant:
	# Bestimme das aktive gegnerische Monster (zur Ausführungszeit, nicht Planungszeit!)
	if opponent_team == null:
		# Fallback: Verwende das alte target System
		if target == null or not target.is_alive():
			return null
	else:
		# Verwende das aktive Monster des gegnerischen Teams
		target = opponent_team.get_active_monster()
		if target == null or not target.is_alive():
			return null

	# � Trackiere, dass diese Monster gegeneinander kämpfen
	actor.register_opponent(target)
	target.register_opponent(actor)

	# �🔋 Energy Check
	if not actor.spend_energy(energy_cost):
		print(
			"%s tried to use %s — but doesn't have enough energy!"
			% [actor.data.name, action_name]
		)
		return null

	# 🎯 Accuracy Check
	if not _roll_hit():
		print(
			"%s uses %s on %s — but it MISSES!"
			% [actor.data.name, action_name, target.data.name]
		)
		return null

	# --------------------------------------------------
	# 🗣️ ATTACK HEADER
	# --------------------------------------------------
	print("%s uses %s!" % [actor.data.name, action_name])

	# --------------------------------------------------
	# 💥 DAMAGE
	# --------------------------------------------------
	var dealt_damage: int = 0

	if power > 0:
		var result := DamageCalculator.calculate_damage(self)

		var damage: int = result.damage
		var effectiveness_text: String = result.effectiveness_text
		var is_crit: bool = result.is_crit

		if damage == 0:
			if effectiveness_text != "":
				print(effectiveness_text)
		else:
			target.take_damage(damage)
			target.clamp_resources()
			dealt_damage = damage

			var line := "%s takes %d damage." % [
				target.data.name,
				damage
			]

			if effectiveness_text != "":
				line += " " + effectiveness_text

			if is_crit:
				line += " A critical hit!"

			if result.stab > 1.0:
				line += " (STAB)"

			line += " (%d/%d HP | %d/%d EN)" % [
				target.hp,
				target.get_max_hp(),
				actor.energy,
				actor.get_max_energy()
			]

			print(line)
			
			# EXP verteilen, wenn das Ziel gestorben ist
			if target.hp <= 0:
				target._distribute_exp_on_death()

	# --------------------------------------------------
	# 🩸 LIFESTEAL (IMMER AUFRUNDEN)
	# --------------------------------------------------
	if dealt_damage > 0:
		var total_lifesteal: float = lifesteal

		# Trait-Lifesteal vom Monster
		if actor.has_method("get_lifesteal"):
			total_lifesteal += actor.get_lifesteal()

		if total_lifesteal > 0.0:
			var heal_amount: int = int(
				ceil(dealt_damage * total_lifesteal)
			)

			if heal_amount > 0:
				var before: int = actor.hp
				actor.hp += heal_amount
				actor.clamp_resources()

				var healed: int = actor.hp - before
				if healed > 0:
					print(
						"%s steals %d HP through lifesteal!"
						% [actor.data.name, healed]
					)

	# --------------------------------------------------
	# 🔁 BUFFS / DEBUFFS (STAT STAGES)
	# --------------------------------------------------
	for change in stat_changes:
		var receiver := actor if change.target_self else target

		var delta: int = receiver.modify_stat_stage(
			change.stat,
			change.stages
		)

		var stat_name: String = MonsterInstance.StatType.keys()[change.stat]

		if delta == 0:
			if change.stages > 0:
				print("%s's %s won't go any higher!" % [
					receiver.data.name,
					stat_name
				])
			else:
				print("%s's %s won't go any lower!" % [
					receiver.data.name,
					stat_name
				])
		else:
			var sign_prefix := "+" if delta > 0 else ""
			print(
				"%s's %s changed by %s%d!"
				% [
					receiver.data.name,
					stat_name,
					sign_prefix,
					delta
				]
			)

	# --------------------------------------------------
	# 🔒 SAFETY CLAMP
	# --------------------------------------------------
	actor.clamp_resources()
	target.clamp_resources()

	return null


# --------------------------------------------------
# HIT ROLL
# --------------------------------------------------
func _roll_hit() -> bool:
	var final_accuracy: float = (
		float(accuracy)
		* actor.accuracy_modifier
		/ target.evasion_modifier
	)

	final_accuracy = clamp(final_accuracy, 0.0, 100.0)
	return randf_range(0.0, 100.0) <= final_accuracy
