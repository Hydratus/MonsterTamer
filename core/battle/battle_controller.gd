extends RefCounted
class_name BattleController

var scene
var teams: Array = []  # Array von MonsterTeam
var action_queue: Array[BattleAction] = []
var pending_player_actions := {}
var waiting_for_player := false
var current_state


func start_battle(team1_monsters: Array[MonsterInstance], team2_monsters: Array[MonsterInstance]):
	# Erstelle Teams aus den Monstern (MonsterTeam Klasse)
	teams = [
		MonsterTeam.new(team1_monsters),
		MonsterTeam.new(team2_monsters)
	]
	
	# Debug: Zeige wie viele Monster in jedem Team sind
	print("DEBUG start_battle: Team 1 hat %d Monster" % teams[0].monsters.size())
	print("DEBUG start_battle: Team 2 hat %d Monster" % teams[1].monsters.size())
	
	change_state(BattleStartState.new())


func change_state(state):
	if current_state:
		current_state.exit(self)
	current_state = state
	current_state.enter(self)


# --------------------------------------------------
# Player Action (über BattleMenu + AttackData)
# --------------------------------------------------

func submit_player_attack(monster: MonsterInstance, attack: AttackData):
	var target: MonsterInstance = get_opponent(monster)
	if target == null:
		return

	var action := AttackAction.new()
	action.battle = self
	action.actor = monster
	action.target = target

	# ✅ Initiative ist bufffähig
	action.speed = monster.get_speed()
	action.priority = attack.priority

	action.name = attack.name
	action.power = attack.power
	action.energy_cost = attack.energy_cost
	action.accuracy = attack.accuracy
	action.attack_element = attack.element
	action.damage_type = attack.damage_type

	# ✅ Crit korrekt
	action.crit_rate = attack.crit_rate
	action.crit_multiplier = monster.crit_damage_multiplier

	# 🔥 HIER WAR DER FEHLER
	action.stat_changes = attack.stat_changes.duplicate()

	pending_player_actions[monster] = action
	check_all_player_actions()




func check_all_player_actions():
	# Prüfe ob beide aktiven Monster Aktionen eingeplant haben
	for team in teams:
		var monster = team.get_active_monster()
		if monster != null and monster.is_alive():
			if monster.decision != null and monster.decision is PlayerDecision:
				if not pending_player_actions.has(monster):
					return

	for action in pending_player_actions.values():
		action_queue.append(action)

	pending_player_actions.clear()
	sort_actions()
	change_state(ResolveActionsState.new())


# --------------------------------------------------
# Helpers
# --------------------------------------------------

# Bekomme das aktive Monster eines Teams
func get_active_monster(team_index: int) -> MonsterInstance:
	if team_index < 0 or team_index >= teams.size():
		return null
	return teams[team_index].get_active_monster()

# Bekomme das gegnerische Team
func get_opponent_team(team_index: int):
	if team_index == 0:
		return teams[1]
	elif team_index == 1:
		return teams[0]
	return null

# Bekomme das aktive gegnerische Monster
func get_opponent(monster: MonsterInstance) -> MonsterInstance:
	for i in range(teams.size()):
		if teams[i].get_active_monster() == monster:
			var opponent_team = get_opponent_team(i)
			return opponent_team.get_active_monster()
	return null

# Wechsle ein Monster für ein Team
func switch_monster(team_index: int, monster_index: int) -> bool:
	if team_index < 0 or team_index >= teams.size():
		return false
	return teams[team_index].switch_to_monster(monster_index)

func sort_actions():
	action_queue.sort_custom(func(a, b):
		return a.get_initiative() > b.get_initiative())
