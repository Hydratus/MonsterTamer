extends RefCounted
class_name SwitchAction

var team_index: int
var monster_index: int
var initiator: MonsterInstance
var priority: int = 100  # Switch-Priorität (höher = früher)
var initiative: int = 0  # Initiative zum Tiebreak (Speed des aktuellen Monsters)

func _init(_team_index: int, _monster_index: int, _initiator: MonsterInstance) -> void:
	team_index = _team_index
	monster_index = _monster_index
	initiator = _initiator
	
	# Initiative aus Speed des aktiven Monsters
	if initiator != null:
		initiative = initiator.get_speed()

func execute(controller) -> void:
	# controller ist die BattleController-Instanz
	var success = controller.perform_switch(team_index, monster_index, initiator)
	if success:
		var team = controller.teams[team_index]
		var new_monster = team.get_active_monster()
		var team_name = "Player" if team_index == 0 else "Enemy"
		controller.log_message("%s switched to %s!" % [team_name, new_monster.data.name])
