extends MTBattleAction
class_name MTAttackAction

# --------------------------------------------------
# ATTACK DATA
# --------------------------------------------------
var power: int = 0
var energy_cost: int = 0

@export_range(0, 100)
var accuracy: int = 100

var attack_element: MTElement.Type = MTElement.Type.NORMAL
var damage_type: MTDamageType.Type = MTDamageType.Type.PHYSICAL

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
var stat_changes: Array[MTStatChangeData] = []

# --------------------------------------------------
# TARGET TEAM (statt target direkt, um dynamische Wechsel zu unterstützen)
# --------------------------------------------------
var opponent_team: MTMonsterTeam = null  # Das gegnerische Team

# --------------------------------------------------
# EXECUTE
# --------------------------------------------------
func execute(_controller = null) -> Variant:
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
		var result := MTDamageCalculator.calculate_damage(self)

		var damage: int = result.damage
		var effectiveness_text: String = result.effectiveness_text
		var is_crit: bool = result.is_crit

		if damage == 0:
			if effectiveness_text != "":
				battle_log(effectiveness_text)
		else:
			var hp_before: int = target.hp
			target.take_damage(damage)
			target.clamp_resources()
			dealt_damage = max(0, hp_before - target.hp)

			var line := "%s takes %d damage." % [
				target.data.name,
				dealt_damage
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

		var stat_name: String = MTMonsterInstance.StatType.keys()[change.stat]

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
func _distribute_exp_with_flush(defeated_monster: MTMonsterInstance):
	if defeated_monster.opponents_fought.is_empty():
		return
	
	# Sammle lebende Gegner
	var alive_opponents: Array[MTMonsterInstance] = []
	for opponent in defeated_monster.opponents_fought:
		if opponent != null and opponent.is_alive():
			alive_opponents.append(opponent)
	
	if alive_opponents.is_empty():
		return
	
	# Berechne EXP
	var total_exp = defeated_monster._calculate_earned_exp(defeated_monster)
	var exp_per_monster = int(total_exp / float(alive_opponents.size()))
	
	var ordered_opponents := _order_exp_recipients(alive_opponents)
	# Verteile EXP (levelweise) über die Szene
	if battle != null and battle.scene != null:
		for opponent in ordered_opponents:
			battle.scene.queue_exp_step(
				Callable(self, "_process_exp_gain_with_flush"),
				[opponent, exp_per_monster]
			)
	else:
		for opponent in ordered_opponents:
			_process_exp_gain_with_flush(opponent, exp_per_monster)

func _check_level_up_with_flush(monster: MTMonsterInstance):
	while monster.current_exp >= monster.exp_to_next_level and monster.level < 100:
		monster.current_exp -= monster.exp_to_next_level
		_level_up_with_flush(monster)
		monster.exp_to_next_level = monster._get_required_exp_for_level(monster.level + 1)

func _level_up_with_flush(monster: MTMonsterInstance):
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
	
	# HP und Energy nur um Zugewinn erhöhen (nicht vollheilen)
	monster.hp = clamp(monster.hp + hp_gain, 0, monster.get_max_hp())
	monster.energy = clamp(monster.energy + energy_gain, 0, monster.get_max_energy())
	if battle != null and battle.scene != null and battle.scene.has_method("update_hud_with_active"):
		battle.scene.update_hud_with_active()
	
	# Level-Up Nachricht mit allen Stat-Erhöhungen (auch +0)
	var levelup_stat_changes: Array[String] = []
	levelup_stat_changes.append("HP+%d" % hp_gain)
	levelup_stat_changes.append("Energy+%d" % energy_gain)
	levelup_stat_changes.append("Strength+%d" % str_gain)
	levelup_stat_changes.append("Magic+%d" % mag_gain)
	levelup_stat_changes.append("Defense+%d" % def_gain)
	levelup_stat_changes.append("Resistance+%d" % res_gain)
	levelup_stat_changes.append("Speed+%d" % spd_gain)
	
	var stat_text = " | ".join(levelup_stat_changes)
	
	battle_log("🎉 %s leveled up to level %d!" % [monster.data.name, monster.level])
	battle_log(stat_text)

	var queued_evolution := false
	if monster.can_evolve():
		if battle != null:
			battle.queue_evolution(monster, Callable(self, "_check_learning_with_flush"))
			queued_evolution = true
		else:
			monster.apply_evolution(Callable(self, "battle_log"))
	
	# Flush Level-Up Block BEVOR Lern-Messages kommen
	if battle != null and battle.scene != null:
		battle.scene.message_box.flush_action_messages()

	if queued_evolution:
		return

	# Check for new attacks/traits (jedes als eigener Block)
	_check_learning_with_flush(monster)

func _process_exp_gain_with_flush(monster: MTMonsterInstance, exp_remaining: int):
	if monster == null or exp_remaining <= 0:
		return

	var to_next = monster.exp_to_next_level - monster.current_exp
	if to_next <= 0:
		to_next = monster.exp_to_next_level
	var gain = min(exp_remaining, to_next)
	monster.current_exp += gain

	battle_log("%s gained %d EXP! (Total: %d/%d)" % [
		monster.data.name, gain,
		monster.current_exp, monster.exp_to_next_level
	])
	if battle != null and battle.scene != null:
		battle.scene.message_box.flush_action_messages()

	var remaining = exp_remaining - gain
	if monster.current_exp >= monster.exp_to_next_level:
		monster.current_exp -= monster.exp_to_next_level
		_level_up_with_flush(monster)
		monster.exp_to_next_level = monster._get_required_exp_for_level(monster.level + 1)
		if remaining > 0 and battle != null and battle.scene != null:
			battle.scene.queue_exp_step_front(
				Callable(self, "_process_exp_gain_with_flush"),
				[monster, remaining]
			)

func _order_exp_recipients(opponents: Array[MTMonsterInstance]) -> Array[MTMonsterInstance]:
	if battle == null or opponents.is_empty():
		return opponents

	var active_first: Array[MTMonsterInstance] = []
	var bench: Array[MTMonsterInstance] = []
	for opponent in opponents:
		var is_active := false
		for team in battle.teams:
			if team == null:
				continue
			if team.monsters.has(opponent) and team.get_active_monster() == opponent:
				is_active = true
				break
		if is_active:
			active_first.append(opponent)
		else:
			bench.append(opponent)

	return active_first + bench

func _check_learning_with_flush(monster: MTMonsterInstance):
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
		monster.add_trait(learn_data.trait_data as MTTraitData)
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
