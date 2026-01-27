extends RefCounted
class_name BattleController

var scene
var participants: Array[MonsterInstance] = []
var action_queue: Array[BattleAction] = []
var pending_player_actions := {}
var waiting_for_player := false
var current_state


func start_battle(monsters: Array[MonsterInstance]):
	participants = monsters
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
	for monster in participants:
		if not monster.is_alive():
			continue
		if monster.decision is PlayerDecision:
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

func get_opponent(monster: MonsterInstance):
	for m in participants:
		if m != monster and m.is_alive():
			return m
	return null


func sort_actions():
	action_queue.sort_custom(func(a, b):
		return a.get_initiative() > b.get_initiative())
