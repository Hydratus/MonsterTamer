extends RefCounted
class_name BattleController


var scene
var teams: Array = []  # Array von MonsterTeam
var action_queue: Array = []  # Gemischte Actions: BattleAction, SwitchAction, etc.
var pending_player_actions := {}
var waiting_for_player := false
var current_state
var pending_evolutions: Array = []

# Prioritäten-Konstanten (höher = früher ausgeführt)
const PRIORITY_ESCAPE := 300
const PRIORITY_ITEM := 200
const PRIORITY_SWITCH := 100
const PRIORITY_ATTACK := 0

# Helper-Funktion um Messages zur UI hinzuzufügen
func log_message(text: String):
	if scene != null and scene.has_method("add_battle_message"):
		scene.add_battle_message(text)
	else:
		print(text)  # Fallback für Debug

func queue_evolution(monster: MonsterInstance, learning_cb: Callable) -> void:
	if monster == null:
		return
	pending_evolutions.append({"monster": monster, "learning_cb": learning_cb})


func start_battle(team1_monsters: Array[MonsterInstance], team2_monsters: Array[MonsterInstance]):
	# Teams werden jetzt direkt von BattleScene erstellt und über die 'teams' Variable gesetzt
	# Diese Funktion wird nicht mehr verwendet, aber bleibt für Kompatibilität
	
	# Nur für den Fall, dass sie noch von irgendwo aufgerufen wird:
	if teams.is_empty():
		teams = [
			MonsterTeam.new(team1_monsters),
			MonsterTeam.new(team2_monsters)
		]
	
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
	var opponent_team = get_opponent_team(0)  # Team 0 ist Spieler
	if opponent_team == null:
		return

	var action := AttackAction.new()
	action.battle = self
	action.actor = monster
	action.opponent_team = opponent_team  # Speichere das gegnerische Team statt direktes Ziel
	action.target = get_opponent(monster)  # Fallback für Kompatibilität

	# ✅ Priority und Initiative setzen
	action.priority = PRIORITY_ATTACK + attack.priority  # attack.priority ist relativ
	action.initiative = monster.get_speed()

	action.action_name = attack.name
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


# Spieler wechselt ein Monster (wird als Aktion beendet behandelt)
func submit_player_switch(monster: MonsterInstance):
	# Der Switch ist die komplette Action für diese Runde
	# Wir markieren, dass dieser Spieler seine Action "fertig" hat
	pending_player_actions[monster] = null  # null bedeutet: Wechsel durchgeführt
	check_all_player_actions()

func submit_player_item(monster: MonsterInstance, item: ItemData, target: MonsterInstance) -> void:
	if monster == null or item == null:
		return
	var action := ItemAction.new()
	action.battle = self
	action.actor = monster
	action.target = target if target != null else monster
	action.item = item
	action.priority = PRIORITY_ITEM
	action.initiative = monster.get_speed()
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

	# Füge alle Aktionen zur Queue hinzu (BattleAction, SwitchAction, etc.)
	for monster_key in pending_player_actions.keys():
		var action = pending_player_actions[monster_key]
		if action != null:
			action_queue.append(action)
	
	pending_player_actions.clear()
	# Jetzt zur Auflösung
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

# Neue API: Reiche eine Action ein (kann BattleAction, SwitchAction, etc. sein)
func submit_action(action) -> void:
	if action == null:
		return
	action_queue.append(action)

# Führe alle Aktionen mit Prioritäts-Sortierung aus
func resolve_actions() -> void:
	# Sortiere nach priority desc, dann initiative desc
	action_queue.sort_custom(func(a, b):
		# Priority vergleichen (höher = früher)
		if a.priority > b.priority:
			return true  # a kommt zuerst
		elif a.priority < b.priority:
			return false  # b kommt zuerst
		
		# Bei gleicher Priorität: Initiative vergleichen (höher = früher)
		if a.initiative > b.initiative:
			return true
		else:
			return false
	)
	
	# Führe alle Aktionen aus
	for action in action_queue:
		if action == null:
			continue
		
		# Überprüfe ob der Akteur noch lebt
		if action.actor != null and not action.actor.is_alive():
			log_message("%s kann nicht angreifen, ist bereits besiegt!" % action.actor.data.name)
			continue
		
		if action.has_method("execute"):
			# Übergebe Battle Controller an die Action, damit sie log_message nutzen kann
			action.battle = self
			action.execute(self)
	
	action_queue.clear()

# Führe einen Wechsel durch (wird von SwitchAction aufgerufen)
func perform_switch(team_index: int, monster_index: int, _initiator: MonsterInstance) -> bool:
	if teams == null or team_index < 0 or team_index >= teams.size():
		return false
	
	var team = teams[team_index]
	if team == null:
		return false
	
	var success = team.switch_to(monster_index)
	if success:
		var team_name = "Player" if team_index == 0 else "Enemy"
		print("--- %s sent out %s! ---" % [team_name, team.get_active_monster().data.name])
	
	return success

func sort_actions():
	action_queue.sort_custom(func(a, b):
		if a.has_method("get_initiative"):
			return a.get_initiative() > b.get_initiative()
		return false)
