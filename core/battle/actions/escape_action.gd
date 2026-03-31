extends MTBattleAction
class_name MTEscapeAction

var opponent: MTMonsterInstance

func execute(controller = null) -> Variant:
	var battle_ref: MTBattleController = controller if controller != null else battle
	if battle_ref == null or actor == null:
		return null
	if opponent == null or not opponent.is_alive():
		opponent = battle_ref.get_opponent(actor)
	if opponent == null:
		return null

	var chance: float = calculate_escape_chance(actor, opponent)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll: float = rng.randf_range(0.0, 100.0)

	battle_ref.log_message("%s attempts to flee!" % actor.data.name)
	battle_ref.log_message("Escape chance: %d%%" % int(round(chance)))

	if roll <= chance:
		battle_ref.log_message("Escape successful!")
		battle_ref.escape_resolved = true
		battle_ref.forced_battle_result = -1
	else:
		battle_ref.log_message("Escape failed!")

	return null

static func calculate_escape_chance(player_monster: MTMonsterInstance, wild_monster: MTMonsterInstance) -> float:
	var player_initiative: float = float(player_monster.get_speed())
	var enemy_initiative: float = float(wild_monster.get_speed())
	var player_level: float = float(player_monster.level)
	var enemy_level: float = float(wild_monster.level)

	var initiative_diff: float = player_initiative - enemy_initiative
	var level_diff: float = player_level - enemy_level

	# Base chance plus scaling from initiative and level differences.
	var chance: float = 45.0 + initiative_diff * 2.5 + level_diff * 3.0
	return clampf(chance, 10.0, 95.0)
