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
		battle_log(
			"%s tried to use %s — but doesn't have enough energy!"
			% [actor.data.name, action_name]
		)
		return null

	# 🎯 Accuracy Check
	if not _roll_hit():
		battle_log(
			"%s uses %s on %s — but it MISSES!"
			% [actor.data.name, action_name, target.data.name]
		)
		return null

	# --------------------------------------------------
	# 🗣️ ATTACK HEADER
	# --------------------------------------------------
	battle_log("%s uses %s!" % [actor.data.name, action_name])

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
				battle_log(effectiveness_text)
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

			battle_log(line)
			
			# Flush nach dem Schaden - Block 1 (Angriff + Schaden)
			if battle != null and battle.scene != null:
				battle.scene.message_box.flush_action_messages()
			
			# EXP verteilen, wenn das Ziel gestorben ist
			if target.hp <= 0:
				# Block 2: Monster besiegt
				battle_log("%s wurde besiegt!" % target.data.name)
				if battle != null and battle.scene != null:
					battle.scene.message_box.flush_action_messages()
				
				# Block 3+: EXP und Level-Ups (einzeln)
				_distribute_exp_with_flush(target)

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
					battle_log(
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
				battle_log("%s's %s won't go any higher!" % [
					receiver.data.name,
					stat_name
				])
			else:
				battle_log("%s's %s won't go any lower!" % [
					receiver.data.name,
					stat_name
				])
		else:
			var sign_prefix := "+" if delta > 0 else ""
			battle_log(
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
# EXP DISTRIBUTION WITH FLUSH
# --------------------------------------------------
func _distribute_exp_with_flush(defeated_monster: MonsterInstance):
	if defeated_monster.opponents_fought.is_empty():
		return
	
	# Sammle lebende Gegner
	var alive_opponents: Array[MonsterInstance] = []
	for opponent in defeated_monster.opponents_fought:
		if opponent != null and opponent.is_alive():
			alive_opponents.append(opponent)
	
	if alive_opponents.is_empty():
		return
	
	# Berechne EXP
	var total_exp = defeated_monster._calculate_earned_exp(defeated_monster)
	var exp_per_monster = int(total_exp / float(alive_opponents.size()))
	
	# Verteile EXP
	for opponent in alive_opponents:
		opponent.current_exp += exp_per_monster
		
		# Block 3: EXP-Gewinn
		battle_log("%s gained %d EXP! (Total: %d/%d)" % [
			opponent.data.name, exp_per_monster,
			opponent.current_exp, opponent.exp_to_next_level
		])
		if battle != null and battle.scene != null:
			battle.scene.message_box.flush_action_messages()
		
		# Block 4+: Jedes Level-Up einzeln
		_check_level_up_with_flush(opponent)

func _check_level_up_with_flush(monster: MonsterInstance):
	while monster.current_exp >= monster.exp_to_next_level and monster.level < 100:
		monster.current_exp -= monster.exp_to_next_level
		_level_up_with_flush(monster)
		monster.exp_to_next_level = monster._get_required_exp_for_level(monster.level + 1)

func _level_up_with_flush(monster: MonsterInstance):
	if monster.level >= 100:
		return
	
	# Speichere alte Stats
	var old_hp = monster.get_max_hp()
	var old_energy = monster.get_max_energy()
	var old_strength = monster.strength
	var old_magic = monster.magic
	var old_defense = monster.defense
	var old_resistance = monster.resistance
	var old_speed = monster.speed
	
	# Level erhöhen und Stats neu berechnen
	monster.level += 1
	monster._recalculate_stats()
	
	# Berechne Differenzen
	var hp_gain = monster.get_max_hp() - old_hp
	var energy_gain = monster.get_max_energy() - old_energy
	var str_gain = monster.strength - old_strength
	var mag_gain = monster.magic - old_magic
	var def_gain = monster.defense - old_defense
	var res_gain = monster.resistance - old_resistance
	var spd_gain = monster.speed - old_speed
	
	# HP und Energy auf neue Maximalwerte setzen
	monster.hp = monster.get_max_hp()
	monster.energy = monster.get_max_energy()
	
	# Level-Up Nachricht mit allen Stat-Erhöhungen (auch +0)
	var stat_changes = []
	stat_changes.append("HP+%d" % hp_gain)
	stat_changes.append("Energy+%d" % energy_gain)
	stat_changes.append("Strength+%d" % str_gain)
	stat_changes.append("Magic+%d" % mag_gain)
	stat_changes.append("Defense+%d" % def_gain)
	stat_changes.append("Resistance+%d" % res_gain)
	stat_changes.append("Speed+%d" % spd_gain)
	
	var stat_text = " | ".join(stat_changes)
	
	battle_log("🎉 %s leveled up to level %d!" % [monster.data.name, monster.level])
	battle_log(stat_text)
	
	# Flush Level-Up Block BEVOR Lern-Messages kommen
	if battle != null and battle.scene != null:
		battle.scene.message_box.flush_action_messages()
	
	# Check for new attacks/traits (jedes als eigener Block)
	_check_learning_with_flush(monster)

func _check_learning_with_flush(monster: MonsterInstance):
	# Check attacks
	var available_attacks = monster.get_available_attacks_to_learn()
	for learn_data in available_attacks:
		if learn_data.attack != null and not monster.attacks.has(learn_data.attack):
			monster.attacks.append(learn_data.attack)
			battle_log("⚔️ %s learned %s!" % [monster.data.name, learn_data.attack.name])
			# Flush nach jeder erlernten Attacke für separaten Block
			if battle != null and battle.scene != null:
				battle.scene.message_box.flush_action_messages()
	
	# Check traits
	var available_traits = monster.get_available_traits_to_learn()
	for learn_data in available_traits:
		monster.add_trait(learn_data.trait_data as TraitData)
		battle_log("✨ %s learned trait %s!" % [monster.data.name, learn_data.trait_data.name])
		# Flush nach jedem erlernten Trait für separaten Block
		if battle != null and battle.scene != null:
			battle.scene.message_box.flush_action_messages()


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
