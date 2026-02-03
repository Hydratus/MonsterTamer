extends Node2D
class_name BattleScene

signal battle_finished(winner_team_index: int)

@onready var menu: BattleMenu = $BattleMenu

var hud: BattleHUD
var message_box: BattleMessageBox
var evolution_layer: CanvasLayer
var evolution_panel: PanelContainer
var evolution_label: Label
var evolution_yes_button: Button
var evolution_no_button: Button
var _pending_learning: Array = []
var _pending_exp_steps: Array = []
var _evolution_decision_callback: Callable

# Team-Konfiguration im Inspector
@export var player_team: Array[MonsterData] = []
@export var enemy_team: Array[MonsterData] = []
@export var auto_start: bool = true

var battle: BattleController
var battle_started := false  # Flag um doppelte Starts zu verhindern
var player_team_instance: MonsterTeam  # Referenz auf das Spieler-Team


func _ready():
	# Erstelle HUD als CanvasLayer
	var hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	
	hud = BattleHUD.new()
	hud_layer.add_child(hud)
	hud.anchor_right = 1.0
	hud.anchor_bottom = 1.0
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Erstelle Message Box
	var message_layer = CanvasLayer.new()
	add_child(message_layer)
	
	message_box = BattleMessageBox.new()
	message_layer.add_child(message_box)
	message_box.all_messages_completed.connect(_on_messages_completed)

	_create_evolution_prompt_ui()
	
	# Starte automatisch einen Kampf wenn Teams im Inspector konfiguriert sind
	# (Nur wenn die Szene direkt geladen wird, nicht wenn sie von außen gestartet wird)
	if auto_start and player_team.size() > 0 and enemy_team.size() > 0 and not battle_started:
		# Konvertiere MonsterData zu MonsterInstance
		var team1: Array[MonsterInstance] = []
		var team2: Array[MonsterInstance] = []
		
		for monster_data in player_team:
			if monster_data != null:
				var monster_instance = MonsterInstance.new(monster_data)
				monster_instance.decision = PlayerDecision.new()  # Spieler kontrolliert Team 1
				team1.append(monster_instance)
		
		for monster_data in enemy_team:
			if monster_data != null:
				var monster_instance = MonsterInstance.new(monster_data)
				monster_instance.decision = AIDecision.new()  # KI kontrolliert Team 2
				team2.append(monster_instance)
		
		# Starte Kampf
		if team1.size() > 0 and team2.size() > 0:
			start_battle(team1, team2)


func start_battle(team1: Array[MonsterInstance], team2: Array[MonsterInstance]):
	battle_started = true
	battle = BattleController.new()
	battle.scene = self
	
	# Debug: Zeige wie viele Monster in jedem Team sind
	print("Team 1: %d Monster" % team1.size())
	print("Team 2: %d Monster" % team2.size())
	
	# Erstelle Teams SOFORT und speichere Referenz BEVOR battle.start_battle() aufgerufen wird
	player_team_instance = MonsterTeam.new(team1)
	var enemy_team_instance = MonsterTeam.new(team2)
	
	# Übergebe die Teams an BattleController
	battle.teams = [player_team_instance, enemy_team_instance]
	
	# Starte Battle (wird jetzt show_player_menu() aufrufen, aber player_team_instance ist schon gesetzt)
	battle.change_state(BattleStartState.new())


func show_player_menu(monster: MonsterInstance):
	print("DEBUG show_player_menu: monster=%s, player_team_instance ist %s" % [monster.data.name, "null" if player_team_instance == null else "gesetzt"])
	
	# Aktualisiere HUD
	if hud != null:
		var opponent = battle.get_opponent(monster)
		hud.update_monsters(monster, opponent)
		print("HUD aktualisiert: player=%s, opponent=%s" % [
			monster.data.name,
			opponent.data.name if opponent else "null"
		])
	
	# Trenne alte Signale wenn noch verbunden
	if menu.action_selected.is_connected(Callable(self, "_on_menu_action_selected")):
		menu.action_selected.disconnect(Callable(self, "_on_menu_action_selected"))
	if menu.escape_battle.is_connected(Callable(self, "_on_menu_escape_battle")):
		menu.escape_battle.disconnect(Callable(self, "_on_menu_escape_battle"))
	if menu.menu_changed.is_connected(Callable(self, "_on_menu_changed")):
		menu.menu_changed.disconnect(Callable(self, "_on_menu_changed"))
	
	# Verbinde neue Signale
	menu.action_selected.connect(Callable(self, "_on_menu_action_selected"))
	menu.escape_battle.connect(Callable(self, "_on_menu_escape_battle"))
	menu.menu_changed.connect(Callable(self, "_on_menu_changed"))
	
	menu.show_main_menu(monster, player_team_instance, battle)

func _on_menu_action_selected(attack: AttackData):
	# Nutze das aktuell aktive Monster aus dem Menu
	var active_monster = menu.current_monster
	if active_monster == null:
		push_error("Kein aktives Monster im Menu!")
		return
	
	print("DEBUG: Angriff ausgewählt für %s: %s" % [active_monster.data.name, attack.name])
	menu.hide_menu()
	battle.submit_player_attack(active_monster, attack)

func _on_menu_escape_battle():
	print("DEBUG: Escape-Button geklickt")
	menu.hide_menu()
	# Hier könnte später die Fluchtlogik implementiert werden

func _on_menu_changed(menu_name: String):
	# Verberge HUD wenn Team oder Inventory geöffnet werden
	if menu_name in ["team", "inventory"]:
		if hud != null:
			hud.visible = false
	else:
		if hud != null:
			hud.visible = true

# Helper, damit UI sauber Aktionen an den Controller übergeben kann
func submit_action_to_battle(action) -> void:
	if battle == null:
		push_error("Battle nicht initialisiert - kann Aktion nicht einreichen")
		return
	if battle.has_method("submit_action"):
		battle.submit_action(action)

func hide_ui() -> void:
	menu.hide_menu()

func update_hud_with_active() -> void:
	if hud == null or battle == null:
		return
	var player_active = battle.get_active_monster(0)
	var enemy_active = battle.get_active_monster(1)
	if player_active != null and enemy_active != null:
		hud.update_monsters(player_active, enemy_active)

func on_battle_finished(winner_team_index: int) -> void:
	battle_finished.emit(winner_team_index)

func add_battle_message(text: String):
	if message_box != null:
		message_box.add_message(text)

func show_battle_messages():
	if message_box != null:
		menu.hide_menu()
		if hud != null:
			hud.visible = true
		# Starte nur wenn es Messages gibt
		if message_box.message_queue.size() > 0:
			message_box.start_displaying()
		else:
			# Keine Messages, gehe sofort weiter
			_on_messages_completed()

func _on_messages_completed():
	# Alle Messages wurden angezeigt, gehe zurück zum Battle Controller
	message_box.clear_messages()  # Bereite MessageBox für nächste Action vor
	if _try_handle_pending_learning():
		return
	if _try_handle_pending_evolution():
		return
	if _try_handle_pending_exp():
		return
	if battle != null and battle.current_state != null:
		if battle.current_state.has_method("on_messages_completed"):
			battle.current_state.on_messages_completed(battle)

func _create_evolution_prompt_ui() -> void:
	evolution_layer = CanvasLayer.new()
	add_child(evolution_layer)

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	evolution_layer.add_child(root)

	evolution_panel = PanelContainer.new()
	evolution_panel.anchor_left = 0.5
	evolution_panel.anchor_top = 0.5
	evolution_panel.anchor_right = 0.5
	evolution_panel.anchor_bottom = 0.5
	evolution_panel.offset_left = -180
	evolution_panel.offset_top = -80
	evolution_panel.offset_right = 180
	evolution_panel.offset_bottom = 80
	root.add_child(evolution_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	evolution_panel.add_child(vbox)

	evolution_label = Label.new()
	evolution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(evolution_label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	evolution_yes_button = Button.new()
	evolution_yes_button.text = "Yes"
	hbox.add_child(evolution_yes_button)
	evolution_yes_button.pressed.connect(_on_evolution_yes_pressed)

	evolution_no_button = Button.new()
	evolution_no_button.text = "No"
	hbox.add_child(evolution_no_button)
	evolution_no_button.pressed.connect(_on_evolution_no_pressed)

	evolution_layer.visible = false

func _show_evolution_prompt(monster: MonsterInstance, on_decision: Callable) -> void:
	var evolved_name := monster.data.name
	if monster.data != null and monster.data.evolution != null:
		var evolution_data := monster.data.evolution as EvolutionData
		if evolution_data != null and evolution_data.evolved_monster != null:
			evolved_name = evolution_data.evolved_monster.name
	evolution_label.text = "%s tries to evolve into %s.\nDo you want to evolve %s?" % [monster.data.name, evolved_name, monster.data.name]
	evolution_layer.visible = true
	evolution_yes_button.grab_focus()
	_evolution_decision_callback = on_decision

func _on_evolution_yes_pressed() -> void:
	evolution_layer.visible = false
	if _evolution_decision_callback.is_valid():
		_evolution_decision_callback.call(true)

func _on_evolution_no_pressed() -> void:
	evolution_layer.visible = false
	if _evolution_decision_callback.is_valid():
		_evolution_decision_callback.call(false)

func _try_handle_pending_evolution() -> bool:
	if battle == null:
		return false
	if battle.pending_evolutions.is_empty():
		return false

	var item = battle.pending_evolutions.pop_front()
	var monster: MonsterInstance = item.monster
	var learning_cb: Callable = item.learning_cb
	_show_evolution_prompt(monster, func(accept: bool):
		if accept:
			monster.apply_evolution(Callable(battle, "log_message"))
		else:
			battle.log_message("%s did not evolve." % monster.data.name)

		if message_box != null:
			message_box.flush_action_messages()
			show_battle_messages()

		if learning_cb.is_valid():
			_pending_learning.append({"cb": learning_cb, "monster": monster})
	)

	return true

func _try_handle_pending_learning() -> bool:
	if _pending_learning.is_empty():
		return false

	var item = _pending_learning.pop_front()
	var cb: Callable = item.cb
	var monster: MonsterInstance = item.monster
	if cb.is_valid():
		cb.call(monster)

	if message_box != null and message_box.message_queue.size() > 0:
		show_battle_messages()
		return true

	return false

func queue_exp_step(cb: Callable, args: Array) -> void:
	_pending_exp_steps.append({"cb": cb, "args": args})

func queue_exp_step_front(cb: Callable, args: Array) -> void:
	_pending_exp_steps.insert(0, {"cb": cb, "args": args})

func start_pending_exp_processing() -> void:
	_try_handle_pending_exp()

func _try_handle_pending_exp() -> bool:
	if _pending_exp_steps.is_empty():
		return false

	var item = _pending_exp_steps.pop_front()
	var cb: Callable = item.cb
	var args: Array = item.args
	if cb.is_valid():
		cb.callv(args)

	if message_box != null and message_box.message_queue.size() > 0:
		show_battle_messages()
		return true

	if not _pending_exp_steps.is_empty():
		return _try_handle_pending_exp()

	return false
