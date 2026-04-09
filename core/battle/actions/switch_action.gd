extends MTBattleAction
class_name MTSwitchAction

var team_index: int
var monster_index: int

func _init(_team_index: int, _monster_index: int, _initiator: MTMonsterInstance) -> void:
	team_index = _team_index
	monster_index = _monster_index
	actor = _initiator
	priority = 100  # Switch-Priorität (höher = früher)
	
	# Initiative aus Speed des aktiven Monsters
	if actor != null:
		initiative = actor.get_speed()

func execute(controller = null) -> Variant:
	# controller ist die MTBattleController-Instanz
	if controller == null:
		return null
	var success = controller.perform_switch(team_index, monster_index, actor)
	if success:
		var team = controller.teams[team_index]
		var new_monster = team.get_active_monster()
		var team_name = TranslationServer.translate("Player") if team_index == 0 else TranslationServer.translate("Enemy")
		controller.log_message(TranslationServer.translate("%s switched to %s!") % [team_name, new_monster.data.name])
	return null
