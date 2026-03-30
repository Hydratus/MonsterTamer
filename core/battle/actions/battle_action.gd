extends RefCounted
class_name MTBattleAction

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
func battle_log(text: String):
	if battle != null and battle.has_method("log_message"):
		battle.log_message(text)
	else:
		print(text)  # Fallback
