extends MTBattleAction
class_name MTAttackAction

# See GameBalanceConstants for the centralized versions
const TEAM_EXP_BONUS_PER_EXTRA_MEMBER := 0.375
const TEAM_EXP_MAX_MULTIPLIER := 2.5
const TEAM_EXP_CATCHUP_LEVEL_SPAN := 10.0
const TEAM_EXP_CATCHUP_MAX_BONUS := 1.0
const TEAM_EXP_ACTIVE_FIGHTER_BONUS := 0.10

# --------------------------------------------------
# ATTACK DATA
# --------------------------------------------------
var power: int = 0
var energy_cost: int = 0

@export_range(0, 100)
var accuracy: int = 100

var attack_element: MTElement.Type = MTElement.Type.FIRE
var damage_type: MTDamageType.Type = MTDamageType.Type.PHYSICAL
var makes_contact: bool = false
var requires_contact_for_effect: bool = false
var last_damage_dealt: int = 0

# 🩸 Attack-eigener Lifesteal (z. B. Drain Bite)
@export_range(0.0, 1.0, 0.01)
var lifesteal: float = 0.0

# --------------------------------------------------
# CRIT SYSTEM
# --------------------------------------------------
@export_range(0.0, 1.0)
var crit_rate: float = 0.10  # See GameBalanceConstants.CRIT_RATE_DEFAULT
var crit_multiplier: float = 1.5  # See GameBalanceConstants.CRIT_DAMAGE_MULTIPLIER_DEFAULT

# --------------------------------------------------
# STAT CHANGES (BUFFS / DEBUFFS)
# --------------------------------------------------
var stat_changes: Array[MTStatChangeData] = []

# --------------------------------------------------
# TARGET TEAM (statt target direkt, um dynamische Wechsel zu unterstützen)
# --------------------------------------------------
var opponent_team: MTMonsterTeam = null  # Das gegnerische Team
var _phase_dealt_damage: int = 0
var _phase_target_was_ko_before_action: bool = false
var _phase_actor_was_ko_before_action: bool = false

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
	var localized_action_name: String = TranslationServer.translate(action_name)

	# �🔋 Energy Check
	if not actor.spend_energy(energy_cost):
		battle_log(
			TranslationServer.translate("%s tried to use %s, but doesn't have enough energy!")
			% [_monster_name(actor), localized_action_name]
		)
		return null

	# 🎯 Accuracy Check
	if not _roll_hit():
		battle_log(
			TranslationServer.translate("%s uses %s on %s, but it misses!")
			% [_monster_name(actor), localized_action_name, _monster_name(target)]
		)
		return null

	# --------------------------------------------------
	# 🗣️ ATTACK HEADER
	# --------------------------------------------------
	battle_log(TranslationServer.translate("%s uses %s!") % [_monster_name(actor), localized_action_name])

	# --------------------------------------------------
	# 💥 STEP 1: DAMAGE
	# --------------------------------------------------
	_phase_dealt_damage = 0
	last_damage_dealt = 0
	_phase_target_was_ko_before_action = target != null and not target.is_alive()
	_phase_actor_was_ko_before_action = actor != null and not actor.is_alive()

	_execute_damage_step()
	_queue_next_step(Callable(self, "_execute_contact_step"))

	return null

func _queue_next_step(step: Callable) -> void:
	if _has_battle():
		battle.queue_message_step(step)
		return
	if step.is_valid():
		step.call()

func _flush_step_messages() -> void:
	if _has_battle() and battle.has_pending_action_messages():
		battle.flush_action_messages()

func _has_battle() -> bool:
	return battle != null

func _execute_damage_step() -> void:
	if power > 0 and damage_type != MTDamageType.Type.STATUS:
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
			_phase_dealt_damage = max(0, hp_before - target.hp)

			var line := TranslationServer.translate("%s takes %d damage.") % [
				_monster_name(target),
				_phase_dealt_damage
			]

			if effectiveness_text != "":
				line += " " + effectiveness_text

			if is_crit:
				line += " " + TranslationServer.translate("A critical hit!")

			if result.stab > 1.0:
				line += TranslationServer.translate(" (STAB)")

			line += TranslationServer.translate(" (%d/%d HP | %d/%d EN)") % [
				target.hp,
				target.get_max_hp(),
				actor.energy,
				actor.get_max_energy()
			]

			battle_log(line)

	last_damage_dealt = _phase_dealt_damage
	_flush_step_messages()

func _execute_contact_step() -> void:
	if makes_contact:
		_trigger_contact_hooks()
	_queue_next_step(Callable(self, "_execute_lifesteal_step"))

func _execute_lifesteal_step() -> void:
	if _phase_dealt_damage > 0 and actor != null and actor.is_alive():
		var secondary_effects_enabled := true
		if requires_contact_for_effect and not makes_contact:
			secondary_effects_enabled = false

		var total_lifesteal: float = lifesteal

		# Trait-Lifesteal vom Monster
		if actor.has_method("get_lifesteal"):
			total_lifesteal += actor.get_lifesteal()

		if secondary_effects_enabled and total_lifesteal > 0.0:
			var heal_amount: int = int(ceil(_phase_dealt_damage * total_lifesteal))

			if heal_amount > 0:
				var before: int = actor.hp
				actor.hp += heal_amount
				actor.clamp_resources()

				var healed: int = actor.hp - before
				if healed > 0:
					battle_log(
						TranslationServer.translate("%s steals %d HP through lifesteal!")
						% [_monster_name(actor), healed]
					)

	_flush_step_messages()
	_queue_next_step(Callable(self, "_execute_final_step"))

func _execute_final_step() -> void:
	for change in stat_changes:
		if actor == null or not actor.is_alive():
			break
		if requires_contact_for_effect and not makes_contact:
			continue
		var receiver := actor if change.target_self else target
		if receiver == null or not receiver.is_alive():
			continue

		var delta: int = receiver.modify_stat_stage(
			change.stat,
			change.stages
		)

		var stat_name: String = _localize_stat_name(MTMonsterInstance.StatType.keys()[change.stat])

		if delta == 0:
			if change.stages > 0:
				battle_log(TranslationServer.translate("%s's %s won't go any higher!") % [
					_monster_name(receiver),
					stat_name
				])
			else:
				battle_log(TranslationServer.translate("%s's %s won't go any lower!") % [
					_monster_name(receiver),
					stat_name
				])
		else:
			var sign_prefix := "+" if delta > 0 else ""
			battle_log(
				TranslationServer.translate("%s's %s changed by %s%d!")
				% [
					_monster_name(receiver),
					stat_name,
					sign_prefix,
					delta
				]
			)

	actor.clamp_resources()
	target.clamp_resources()
	_handle_post_attack_knockouts(
		_phase_target_was_ko_before_action,
		_phase_actor_was_ko_before_action
	)
	_flush_step_messages()

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

func _trigger_contact_hooks() -> void:
	if actor != null and actor.passive_traits != null:
		for trait_effect in actor.passive_traits:
			if trait_effect == null:
				continue
			if trait_effect.has_method("on_contact_made"):
				trait_effect.on_contact_made(actor, target, self)

	if target != null and target.passive_traits != null:
		for trait_effect in target.passive_traits:
			if trait_effect == null:
				continue
			if trait_effect.has_method("on_contact_taken"):
				trait_effect.on_contact_taken(target, actor, self)

func _handle_post_attack_knockouts(target_was_ko_before_action: bool, actor_was_ko_before_action: bool) -> void:
	if target != null and not target_was_ko_before_action and not target.is_alive():
		_distribute_exp_with_flush(target)

	if actor != null and not actor_was_ko_before_action and not actor.is_alive():
		# Die KO-Meldung und ein möglicher Wechsel werden zentral in MTCheckEndState behandelt.
		return

# --------------------------------------------------
# EXP DISTRIBUTION WITH FLUSH
# --------------------------------------------------
func _distribute_exp_with_flush(defeated_monster: MTMonsterInstance):
	if defeated_monster == null:
		return

	var defeated_team_index := _find_team_index_for_monster(defeated_monster)
	if defeated_team_index == -1:
		return
	var exp_receiver_team_index := 1 if defeated_team_index == 0 else 0
	var exp_receiver_team: MTMonsterTeam = null
	if _has_battle() and battle.teams.size() > exp_receiver_team_index:
		exp_receiver_team = battle.teams[exp_receiver_team_index]
	if exp_receiver_team == null:
		return
	
	# Teamweite EXP: alle lebenden Monster im Siegerteam bekommen Anteile.
	var alive_team_members: Array[MTMonsterInstance] = []
	for member in exp_receiver_team.monsters:
		if member != null and member.is_alive():
			alive_team_members.append(member)

	if alive_team_members.is_empty():
		return

	var base_exp: int = defeated_monster._calculate_earned_exp(defeated_monster)
	var team_bonus_multiplier: float = 1.0 + TEAM_EXP_BONUS_PER_EXTRA_MEMBER * float(max(0, alive_team_members.size() - 1))
	team_bonus_multiplier = min(team_bonus_multiplier, TEAM_EXP_MAX_MULTIPLIER)
	var total_exp: int = int(ceil(float(base_exp) * team_bonus_multiplier))

	var highest_level: int = 1
	for member in alive_team_members:
		highest_level = max(highest_level, member.level)

	var active_receiver: MTMonsterInstance = exp_receiver_team.get_active_monster()
	var weighted_members: Array = []
	var total_weight: float = 0.0
	for member in alive_team_members:
		var level_delta: int = max(0, highest_level - member.level)
		var catchup_ratio: float = min(1.0, float(level_delta) / TEAM_EXP_CATCHUP_LEVEL_SPAN)
		var weight: float = 1.0 + catchup_ratio * TEAM_EXP_CATCHUP_MAX_BONUS
		if member == active_receiver:
			weight *= 1.0 + TEAM_EXP_ACTIVE_FIGHTER_BONUS
		weighted_members.append({"monster": member, "weight": weight})
		total_weight += weight

	if total_weight <= 0.0:
		return

	var ordered_opponents: Array[MTMonsterInstance] = _order_exp_recipients(alive_team_members)
	var exp_by_monster: Dictionary = {}
	for entry in weighted_members:
		var receiver: MTMonsterInstance = entry["monster"] as MTMonsterInstance
		var receiver_weight: float = float(entry["weight"])
		var raw_share: float = float(total_exp) * (receiver_weight / total_weight)
		exp_by_monster[receiver] = int(ceil(raw_share))

	if _has_battle():
		for opponent in ordered_opponents:
			if not exp_by_monster.has(opponent):
				continue
			battle.queue_exp_step(
				Callable(self, "_process_exp_gain_with_flush").bind(opponent, int(exp_by_monster[opponent]))
			)
	else:
		for opponent in ordered_opponents:
			if not exp_by_monster.has(opponent):
				continue
			_process_exp_gain_with_flush(opponent, int(exp_by_monster[opponent]))

func _find_team_index_for_monster(monster: MTMonsterInstance) -> int:
	if not _has_battle() or monster == null:
		return -1
	for i in range(battle.teams.size()):
		var team: MTMonsterTeam = battle.teams[i]
		if team == null:
			continue
		if team.monsters.has(monster):
			return i
	return -1

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
	if _has_battle():
		battle.update_hud_with_active()
	
	# Level-Up Nachricht mit allen Stat-Erhöhungen (auch +0)
	var levelup_stat_changes: Array[String] = []
	levelup_stat_changes.append(TranslationServer.translate("HP+%d") % hp_gain)
	levelup_stat_changes.append(TranslationServer.translate("Energy+%d") % energy_gain)
	levelup_stat_changes.append(TranslationServer.translate("Strength+%d") % str_gain)
	levelup_stat_changes.append(TranslationServer.translate("Magic+%d") % mag_gain)
	levelup_stat_changes.append(TranslationServer.translate("Defense+%d") % def_gain)
	levelup_stat_changes.append(TranslationServer.translate("Resistance+%d") % res_gain)
	levelup_stat_changes.append(TranslationServer.translate("Speed+%d") % spd_gain)
	
	var stat_text = " | ".join(levelup_stat_changes)
	
	battle_log(TranslationServer.translate("%s leveled up to level %d!") % [_monster_name(monster), monster.level])
	battle_log(stat_text)

	var queued_evolution := false
	if monster.can_evolve():
		if _has_battle():
			battle.queue_evolution(monster, Callable(self, "_check_learning_with_flush"))
			queued_evolution = true
		else:
			monster.apply_evolution(Callable(self, "battle_log"))
	
	# Flush Level-Up Block BEVOR Lern-Messages kommen
	if _has_battle():
		battle.flush_action_messages()

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

	battle_log(TranslationServer.translate("%s gained %d EXP! (Total: %d/%d)") % [
		_monster_name(monster), gain,
		monster.current_exp, monster.exp_to_next_level
	])
	if _has_battle():
		battle.flush_action_messages()

	var remaining = exp_remaining - gain
	if monster.current_exp >= monster.exp_to_next_level:
		monster.current_exp -= monster.exp_to_next_level
		_level_up_with_flush(monster)
		monster.exp_to_next_level = monster._get_required_exp_for_level(monster.level + 1)
		if remaining > 0 and _has_battle():
			battle.queue_exp_step_front(
				Callable(self, "_process_exp_gain_with_flush").bind(monster, remaining)
			)

func _order_exp_recipients(opponents: Array[MTMonsterInstance]) -> Array[MTMonsterInstance]:
	if not _has_battle() or opponents.is_empty():
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
		var attack_learned: bool = monster.learn_attack_with_limit(learn_data.attack as MTAttackData, Callable(self, "battle_log"))
		if attack_learned and _has_battle():
			# Flush nach jeder Lernentscheidung für separaten Block
			battle.flush_action_messages()
	
	# Check traits
	var available_traits = monster.get_available_traits_to_learn()
	for learn_data in available_traits:
		var trait_learned: bool = monster.learn_trait_with_limit(learn_data.trait_data as MTTraitData, Callable(self, "battle_log"))
		if trait_learned and _has_battle():
			# Flush nach jeder Lernentscheidung für separaten Block
			battle.flush_action_messages()

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name


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
