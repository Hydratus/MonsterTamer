extends RefCounted
class_name MTBattleController

const EscapeActionClass = preload("res://core/battle/actions/escape_action.gd")
const RestActionClass = preload("res://core/battle/actions/rest_action.gd")
const AttackActionClass = preload("res://core/battle/actions/attack_action.gd")
const SceneAdapterClass = preload("res://core/battle/ui/battle_scene_adapter.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")


var _scene_adapter = null
var teams: Array = []  # Array von MTMonsterTeam
var action_queue: Array = []  # Gemischte Actions: MTBattleAction, MTSwitchAction, etc.
var pending_player_actions := {}
var waiting_for_player := false
var current_state
var pending_evolutions: Array = []
var escape_resolved := false
var forced_battle_result: int = -2

signal message_logged(text: String)

# Prioritäten-Konstanten (höher = früher ausgeführt)
const PRIORITY_ESCAPE := 300
const PRIORITY_ITEM := 200
const PRIORITY_SWITCH := 100
const PRIORITY_ATTACK := 0

# Helper-Funktion um Messages zur UI hinzuzufügen
func log_message(text: String):
	var has_subscribers := message_logged.get_connections().size() > 0
	message_logged.emit(text)
	if not has_subscribers:
		var scene_adapter = _get_scene_adapter()
		if scene_adapter != null:
			scene_adapter.add_battle_message(text)
		else:
			DEBUG_LOG.warning("BattleController", text)

func bind_scene(scene_ref) -> void:
	_scene_adapter = SceneAdapterClass.new(scene_ref) if scene_ref != null else null

func _get_scene_adapter():
	return _scene_adapter

func clear_all_messages() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.clear_all_messages()

func clear_current_action_messages() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.clear_current_action_messages()

func flush_action_messages() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.flush_action_messages()

func show_battle_messages() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.show_battle_messages()

func queue_message_step(step: Callable) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.queue_message_step(step)

func queue_exp_step(step: Callable) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.queue_exp_step(step)

func queue_exp_step_front(step: Callable) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.queue_exp_step_front(step)

func update_hud_with_active() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.update_hud_with_active()

func has_pending_action_messages() -> bool:
	var scene_adapter = _get_scene_adapter()
	return scene_adapter != null and scene_adapter.has_pending_action_messages()

func has_queued_messages() -> bool:
	var scene_adapter = _get_scene_adapter()
	return scene_adapter != null and scene_adapter.has_queued_messages()

func show_player_menu(monster: MTMonsterInstance) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.show_player_menu(monster)

func show_forced_switch_menu(team_index: int) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.show_forced_switch_menu(team_index)

func hide_ui() -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.hide_ui()

func finish_battle(winner_team_index: int) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.finish_battle(winner_team_index)

func perform_capture_attempt(actor: MTMonsterInstance, target: MTMonsterInstance, item: MTItemData) -> void:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		scene_adapter.perform_capture_attempt(actor, target, item)

func get_item_user_name(actor: MTMonsterInstance) -> String:
	var scene_adapter = _get_scene_adapter()
	if scene_adapter != null:
		return scene_adapter.get_item_user_name(actor)
	if actor != null and actor.data != null:
		return actor.data.name
	return TranslationServer.translate("Player")

func queue_evolution(monster: MTMonsterInstance, learning_cb: Callable) -> void:
	if monster == null:
		return
	pending_evolutions.append({"monster": monster, "learning_cb": learning_cb})


func start_battle(team1_monsters: Array[MTMonsterInstance], team2_monsters: Array[MTMonsterInstance]):
	# Teams werden jetzt direkt von MTBattleScene erstellt und über die 'teams' Variable gesetzt
	# Diese Funktion wird nicht mehr verwendet, aber bleibt für Kompatibilität
	
	# Nur für den Fall, dass sie noch von irgendwo aufgerufen wird:
	if teams.is_empty():
		teams = [
			MTMonsterTeam.new(team1_monsters),
			MTMonsterTeam.new(team2_monsters)
		]
	
	change_state(MTBattleStartState.new())


func change_state(state):
	if current_state:
		current_state.exit(self)
	current_state = state
	current_state.enter(self)


# --------------------------------------------------
# Player Action (über MTBattleMenu + MTAttackData)
# --------------------------------------------------

func submit_player_attack(monster: MTMonsterInstance, attack: MTAttackData):
	var opponent_team = get_opponent_team(0)  # Team 0 ist Spieler
	if opponent_team == null:
		return

	var action = AttackActionClass.new()
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
	action.makes_contact = attack.makes_contact
	action.requires_contact_for_effect = attack.requires_contact_for_effect

	# ✅ Crit korrekt
	action.crit_rate = attack.crit_rate
	action.crit_multiplier = monster.crit_damage_multiplier

	# 🔥 HIER WAR DER FEHLER
	action.stat_changes = attack.stat_changes.duplicate()

	pending_player_actions[monster] = action
	check_all_player_actions()


# Spieler wechselt ein Monster (wird als Aktion beendet behandelt)
func submit_player_switch(monster: MTMonsterInstance):
	# Der Switch ist die komplette Action für diese Runde
	# Wir markieren, dass dieser Spieler seine Action "fertig" hat
	pending_player_actions[monster] = null  # null bedeutet: Wechsel durchgeführt
	check_all_player_actions()

func submit_player_item(monster: MTMonsterInstance, item: MTItemData, target: MTMonsterInstance) -> void:
	if monster == null or item == null:
		return
	var action := MTItemAction.new()
	action.battle = self
	action.actor = monster
	action.target = target if target != null else monster
	action.item = item
	action.priority = PRIORITY_ITEM
	action.initiative = monster.get_speed()
	pending_player_actions[monster] = action
	check_all_player_actions()

func submit_player_escape(monster: MTMonsterInstance) -> void:
	if monster == null:
		return
	var action: MTBattleAction = EscapeActionClass.new()
	action.battle = self
	action.actor = monster
	action.opponent = get_opponent(monster)
	action.priority = PRIORITY_ESCAPE
	action.initiative = monster.get_speed()
	pending_player_actions[monster] = action
	check_all_player_actions()

func submit_player_rest(monster: MTMonsterInstance) -> void:
	if monster == null:
		return
	var action: MTBattleAction = RestActionClass.new()
	action.battle = self
	action.actor = monster
	action.priority = PRIORITY_ATTACK
	action.initiative = monster.get_speed()
	pending_player_actions[monster] = action
	check_all_player_actions()


func check_all_player_actions():
	# Prüfe ob beide aktiven Monster Aktionen eingeplant haben
	for team in teams:
		var monster = team.get_active_monster()
		if monster != null and monster.is_alive():
			if monster.decision != null and monster.decision is MTPlayerDecision:
				if not pending_player_actions.has(monster):
					return

	# Füge alle Aktionen zur Queue hinzu (MTBattleAction, MTSwitchAction, etc.)
	for monster_key in pending_player_actions.keys():
		var action = pending_player_actions[monster_key]
		if action != null:
			action_queue.append(action)
	
	pending_player_actions.clear()
	# Jetzt zur Auflösung
	change_state(MTResolveActionsState.new())


# --------------------------------------------------
# Helpers
# --------------------------------------------------

# Bekomme das aktive Monster eines Teams
func get_active_monster(team_index: int) -> MTMonsterInstance:
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
func get_opponent(monster: MTMonsterInstance) -> MTMonsterInstance:
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

# Neue API: Reiche eine Action ein (kann MTBattleAction, MTSwitchAction, etc. sein)
func submit_action(action) -> void:
	if action == null:
		return
	action_queue.append(action)

# Führe alle Aktionen mit Prioritäts-Sortierung aus
func resolve_actions() -> void:
	sort_action_queue()
	
	# Führe alle Aktionen aus
	for action in action_queue:
		if action == null:
			continue
		
		# Überprüfe ob der Akteur noch lebt
		if action.actor != null and not action.actor.is_alive():
			log_message(TranslationServer.translate("%s cannot act because it has already been defeated!") % action.actor.data.name)
			continue
		
		if action.has_method("execute"):
			# Übergebe Battle Controller an die Action, damit sie log_message nutzen kann
			action.battle = self
			action.execute(self)
	
	action_queue.clear()

# Führe einen Wechsel durch (wird von MTSwitchAction aufgerufen)
func perform_switch(team_index: int, monster_index: int, _initiator: MTMonsterInstance) -> bool:
	if teams == null or team_index < 0 or team_index >= teams.size():
		return false
	
	var team = teams[team_index]
	if team == null:
		return false
	
	var success = team.switch_to(monster_index)
	if success:
		var team_name = "Player" if team_index == 0 else "Enemy"
		log_message("--- %s sent out %s! ---" % [team_name, team.get_active_monster().data.name])
	
	return success

func sort_actions():
	sort_action_queue()

func sort_action_queue() -> void:
	action_queue.sort_custom(Callable(self, "_is_action_before"))

func _is_action_before(a, b) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	if a.priority != b.priority:
		return a.priority > b.priority
	if a.initiative != b.initiative:
		return a.initiative > b.initiative
	if a.has_method("get_instance_id") and b.has_method("get_instance_id"):
		return a.get_instance_id() < b.get_instance_id()
	return false
