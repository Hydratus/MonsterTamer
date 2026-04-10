extends RefCounted
class_name MTBattleAction

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

var battle: MTBattleController
var actor: MTMonsterInstance
var target: MTMonsterInstance

var speed: int = 0
var priority: int = 0
var initiative: int = 0  # Initiative für Tiebreaker bei gleicher Priorität
var action_name: String = "Action"  # Umbenennt von "name" da das reserviert ist

func get_initiative() -> int:
	return priority * 1000 + speed

func execute(_controller = null) -> Variant:
	return null

# Helper-Funktion um Messages zu loggen
func battle_log(text: String) -> void:
	if battle != null:
		battle.log_message(text)
	else:
		DEBUG_LOG.warning("BattleAction", text)
