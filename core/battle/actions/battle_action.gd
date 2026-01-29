extends RefCounted
class_name BattleAction

var battle: BattleController
var actor: MonsterInstance
var target: MonsterInstance

var speed: int = 0
var priority: int = 0
var initiative: int = 0  # Initiative für Tiebreaker bei gleicher Priorität
var action_name: String = "Action"  # Umbenennt von "name" da das reserviert ist

func get_initiative() -> int:
	return priority * 1000 + speed

func execute(controller = null) -> Variant:
	return null
