extends MTBattleAction
class_name MTEscapeAction

const BalanceConstants = preload("res://core/systems/game_balance_constants.gd")

var opponent: MTMonsterInstance

func _resolve_battle_ref(controller = null) -> MTBattleController:
	if controller != null:
		return controller as MTBattleController
	return battle

func execute(controller = null) -> Variant:
	var battle_ref: MTBattleController = _resolve_battle_ref(controller)
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

	battle_ref.log_message(TranslationServer.translate("%s attempts to flee!") % _monster_name(actor))
	battle_ref.log_message(TranslationServer.translate("Escape chance: %d%%") % int(round(chance)))

	if roll <= chance:
		battle_ref.log_message(TranslationServer.translate("Escape successful!"))
		battle_ref.escape_resolved = true
		battle_ref.forced_battle_result = -1
	else:
		battle_ref.log_message(TranslationServer.translate("Escape failed!"))

	return null

static func calculate_escape_chance(player_monster: MTMonsterInstance, wild_monster: MTMonsterInstance) -> float:
	var player_initiative: float = float(player_monster.get_speed())
	var enemy_initiative: float = float(wild_monster.get_speed())
	var player_level: float = float(player_monster.level)
	var enemy_level: float = float(wild_monster.level)

	var initiative_diff: float = player_initiative - enemy_initiative
	var level_diff: float = player_level - enemy_level

	# Base chance plus scaling from initiative and level differences.
	var chance: float = BalanceConstants.ESCAPE_BASE_CHANCE + initiative_diff * BalanceConstants.ESCAPE_SPEED_DIFF_COEFFICIENT + level_diff * BalanceConstants.ESCAPE_LEVEL_DIFF_COEFFICIENT
	return clampf(chance, BalanceConstants.ESCAPE_MIN_CHANCE, BalanceConstants.ESCAPE_MAX_CHANCE)

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name
