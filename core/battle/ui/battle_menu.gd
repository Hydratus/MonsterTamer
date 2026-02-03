extends CanvasLayer
class_name BattleMenu

signal action_selected(attack: AttackData)
signal escape_battle
signal menu_changed(menu_name: String)  # Neues Signal für HUD-Sichtbarkeit

@onready var control := $Control
@onready var vbox := $Control/VBoxContainer

const MENU_OFFSET_TOP_DEFAULT := -80.0
const MENU_OFFSET_TOP_ATTACKS := -140.0

var current_monster: MonsterInstance
var current_team: MonsterTeam
var battle_controller: BattleController  # Referenz zum BattleController für Aktionen
var current_menu: String = "main"  # "main", "attacks", "team", "inventory", "escape"
var _is_showing_menu := false  # Flag um doppelte show_main_menu() Aufrufe zu verhindern
var _connected_monster: MonsterInstance = null  # Trackiere welches Monster die Signale verbunden hat

# Attack-Info UI (Hover)
var attack_info_name: Label
var attack_info_description: Label
var attack_info_power: Label
var attack_info_element: Label
var attack_info_energy: Label
var attack_info_accuracy: Label
var attack_info_priority: Label

# Navigation
var _menu_buttons: Array[Button] = []
var _menu_columns: int = 1

func _ready():
	# Verstecke das Menu initial
	visible = false
	set_process_unhandled_input(true)
	_ensure_gamepad_accept()

func _ensure_gamepad_accept() -> void:
	if not InputMap.has_action("ui_accept"):
		InputMap.add_action("ui_accept")
	
	var a_event := InputEventJoypadButton.new()
	a_event.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", a_event):
		InputMap.action_add_event("ui_accept", a_event)

func show_main_menu(monster: MonsterInstance, team: MonsterTeam = null, controller: BattleController = null):
	# Verhindere gleichzeitige Aufrufe
	if _is_showing_menu:
		return
	
	_is_showing_menu = true
	
	current_monster = monster
	current_team = team
	battle_controller = controller
	current_menu = "main"
	
	menu_changed.emit("main")
	vbox.offset_top = MENU_OFFSET_TOP_DEFAULT
	
	print("DEBUG show_main_menu: monster=%s, team ist %s, controller ist %s" % [monster.data.name, "null" if team == null else "gesetzt", "null" if controller == null else "gesetzt"])
	print("DEBUG show_main_menu: vbox ist %s, vbox.get_child_count() = %d" % ["null" if vbox == null else "gesetzt", vbox.get_child_count() if vbox != null else -1])
	
	# Stelle sicher, dass die VBox wirklich leer ist
	_clear_menu()
	
	# Warte einen Frame, damit queue_free() die Buttons wirklich löscht
	await get_tree().process_frame
	
	_show_menu_options([
		{"label": "⚔️ Attack", "action": "attacks"},
		{"label": "👥 Team", "action": "team"},
		{"label": "🎒 Inventory", "action": "inventory"},
		{"label": "💨 Escape", "action": "escape"}
	])
	
	print("DEBUG show_main_menu: Nach _show_menu_options, vbox.get_child_count() = %d" % vbox.get_child_count())
	visible = true
	print("DEBUG show_main_menu: visible = true")
	
	_focus_first_button()
	_is_showing_menu = false

func show_attacks(monster: MonsterInstance):
	current_monster = monster
	current_menu = "attacks"
	menu_changed.emit("attacks")
	vbox.offset_top = MENU_OFFSET_TOP_ATTACKS
	_clear_menu()
	
	# Layout: links Angriffe, rechts Info-Panel
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)
	
	# Angriffsbereich (links) mit Grid + Back-Button darunter
	var attacks_box := VBoxContainer.new()
	attacks_box.add_theme_constant_override("separation", 6)
	attacks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(attacks_box)

	# Erstelle GridContainer für mehrspaltige Anzeige
	var grid := GridContainer.new()
	grid.columns = 2  # Zwei Spalten für Angriffe
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 1)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attacks_box.add_child(grid)
	_menu_columns = 2
	
	# Info-Panel rechts
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(180, 0)
	info_panel.size_flags_horizontal = Control.SIZE_FILL
	hbox.add_child(info_panel)
	
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_panel.add_child(info_vbox)
	
	attack_info_name = Label.new()
	attack_info_name.text = "Hover: Attack"
	attack_info_name.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(attack_info_name)
	
	attack_info_power = Label.new()
	attack_info_power.text = "Power: -"
	info_vbox.add_child(attack_info_power)
	
	attack_info_element = Label.new()
	attack_info_element.text = "Element: -"
	info_vbox.add_child(attack_info_element)
	
	attack_info_energy = Label.new()
	attack_info_energy.text = "Energy Cost: -"
	info_vbox.add_child(attack_info_energy)
	
	attack_info_accuracy = Label.new()
	attack_info_accuracy.text = "Accuracy: -"
	info_vbox.add_child(attack_info_accuracy)
	
	attack_info_priority = Label.new()
	attack_info_priority.text = "Priority: -"
	info_vbox.add_child(attack_info_priority)

	# Beschreibung ganz rechts
	var desc_panel := PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(220, 0)
	desc_panel.size_flags_horizontal = Control.SIZE_FILL
	hbox.add_child(desc_panel)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.add_theme_constant_override("separation", 4)
	desc_panel.add_child(desc_vbox)

	var desc_title := Label.new()
	desc_title.text = "Description"
	desc_title.add_theme_font_size_override("font_size", 12)
	desc_vbox.add_child(desc_title)

	attack_info_description = Label.new()
	attack_info_description.text = ""
	attack_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(attack_info_description)
	
	var attack_button_width := 220
	for attack in monster.attacks:
		var button := Button.new()
		button.text = attack.name
		button.custom_minimum_size = Vector2(attack_button_width, 22)  # Breite wie Description
		button.add_theme_font_size_override("font_size", 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			# Emitiere mit dem aktuellen Monster (zur Ausführungszeit)
			action_selected.emit(attack)
		)
		button.mouse_entered.connect(func():
			_update_attack_info(attack)
		)
		button.mouse_exited.connect(func():
			_clear_attack_info()
		)
		button.focus_entered.connect(func():
			_update_attack_info(attack)
		)
		button.focus_exited.connect(func():
			_clear_attack_info()
		)
		grid.add_child(button)
		_register_menu_button(button)
	
	# Back-Button zentriert unter den Attacks
	var back_row := HBoxContainer.new()
	back_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attacks_box.add_child(back_row)

	var back_spacer_left := Control.new()
	back_spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer_left)

	var back_button := Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(attack_button_width, 0)
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.pressed.connect(func():
		show_main_menu(current_monster, current_team, battle_controller)
	)
	back_row.add_child(back_button)

	var back_spacer_right := Control.new()
	back_spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_row.add_child(back_spacer_right)
	_register_menu_button(back_button)
	
	visible = true
	_focus_first_button()

func show_team(team: MonsterTeam):
	current_team = team
	current_menu = "team"
	menu_changed.emit("team")
	vbox.offset_top = MENU_OFFSET_TOP_DEFAULT
	_clear_menu()
	_menu_columns = 1
	
	# Debug: Prüfe ob Team null ist
	if team == null:
		print("ERROR: Team ist null! Kann Team-Menü nicht anzeigen")
		var label := Label.new()
		label.text = "ERROR: Team ist null"
		vbox.add_child(label)
		_add_back_button()
		visible = true
		return
	
	print("DEBUG: Zeige Team mit %d Monstern" % team.monsters.size())
	
	for i in range(team.monsters.size()):
		var monster = team.monsters[i]
		if monster == null:
			continue
		
		var button := Button.new()
		var status = "[KO]" if not monster.is_alive() else "[OK]"
		button.text = "%s %s | Lvl %d | %d/%d HP | %d/%d EN" % [
			monster.data.name,
			status,
			monster.data.level,
			monster.hp,
			monster.get_max_hp(),
			monster.energy,
			monster.get_max_energy()
		]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Button für Monster-Details und Switch
		button.pressed.connect(func():
			_show_monster_options(team, i, monster)
		)
		
		vbox.add_child(button)
		_register_menu_button(button)
	
	# Back-Button
	_add_back_button()
	visible = true
	_focus_first_button()

func show_inventory():
	current_menu = "inventory"
	vbox.offset_top = MENU_OFFSET_TOP_DEFAULT
	_clear_menu()
	_menu_columns = 1
	
	var label := Label.new()
	label.text = "🎒 Inventory\n\n(Noch nicht implementiert)"
	vbox.add_child(label)
	
	# Back-Button
	_add_back_button()
	visible = true
	_focus_first_button()

func show_escape_menu():
	current_menu = "escape"
	vbox.offset_top = MENU_OFFSET_TOP_DEFAULT
	_clear_menu()
	_menu_columns = 1
	
	var label := Label.new()
	label.text = "Willst du wirklich fliehen?"
	vbox.add_child(label)
	
	var yes_button := Button.new()
	yes_button.text = "Ja, fliehen!"
	yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_button.pressed.connect(func():
		escape_battle.emit()
	)
	vbox.add_child(yes_button)
	_register_menu_button(yes_button)
	
	var no_button := Button.new()
	no_button.text = "Nein, zurück"
	no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_button.pressed.connect(func():
		show_main_menu(current_monster, current_team)
	)
	vbox.add_child(no_button)
	_register_menu_button(no_button)
	visible = true
	_focus_first_button()

# Private Hilfsfunktionen

func _show_menu_options(options: Array) -> void:
	_clear_menu()
	
	print("DEBUG _show_menu_options: %d Optionen werden hinzugefügt" % options.size())
	
	# Erstelle GridContainer für 2x2 Layout
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)
	_menu_columns = 2
	
	for option in options:
		var button := Button.new()
		button.text = option["label"]
		button.custom_minimum_size = Vector2(140, 0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var action = option["action"]
		button.pressed.connect(func():
			_handle_menu_action(action)
		)
		
		grid.add_child(button)
		_register_menu_button(button)
		print("DEBUG _show_menu_options: Button hinzugefügt: %s" % option["label"])

func _handle_menu_action(action: String) -> void:
	print("DEBUG: Menu-Aktion: %s | current_team ist %s" % [action, "null" if current_team == null else "gesetzt"])
	
	match action:
		"attacks":
			show_attacks(current_monster)
		"team":
			if current_team != null:
				show_team(current_team)
			else:
				print("ERROR: Team ist null, kann Team-Menü nicht anzeigen")
		"inventory":
			show_inventory()
		"escape":
			show_escape_menu()

func _show_monster_options(team: MonsterTeam, index: int, monster: MonsterInstance) -> void:
	_clear_menu()
	_menu_columns = 1
	
	print("DEBUG: Zeige Monster-Options für %s (Index: %d, aktiv: %s)" % [
		monster.data.name,
		index,
		"ja" if monster == team.get_active_monster() else "nein"
	])
	
	var label := Label.new()
	label.text = "%s - Level %d\n\nHP: %d/%d\nEN: %d/%d\nSTR: %d | MAG: %d\nDEF: %d | RES: %d\nSPD: %d" % [
		monster.data.name,
		monster.data.level,
		monster.hp,
		monster.get_max_hp(),
		monster.energy,
		monster.get_max_energy(),
		monster.strength,
		monster.magic,
		monster.defense,
		monster.resistance,
		monster.speed
	]
	vbox.add_child(label)
	
	# Switch-Button (nur wenn Monster lebt und nicht bereits aktiv)
	if monster.is_alive() and monster != team.get_active_monster():
		print("DEBUG: Zeige Einwechsel-Button für %s" % monster.data.name)
		var switch_button := Button.new()
		switch_button.text = "Einwechseln"
		switch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		switch_button.pressed.connect(func():
			print("DEBUG: Einwechsel-Button geklickt für %s (Index: %d)" % [monster.data.name, index])
			if battle_controller == null:
				print("ERROR: battle_controller ist null!")
				return
			
			# Bestimme Team-Index (0 = Player, 1 = Enemy)
			var team_index = 0
			if battle_controller.teams.size() > 1:
				if battle_controller.teams[1] == team:
					team_index = 1
			
			# Erstelle SwitchAction
			var switch_action = SwitchAction.new(team_index, index, current_monster)
			print("DEBUG: Reiche SwitchAction ein für Team %d, Monster Index %d" % [team_index, index])
			
			# Registriere als Spieler-Aktion (nicht direkt zur Queue)
			battle_controller.pending_player_actions[current_monster] = switch_action
			battle_controller.check_all_player_actions()
			hide_menu()
		)
		vbox.add_child(switch_button)
		_register_menu_button(switch_button)
	else:
		print("DEBUG: Einwechsel-Button wird NICHT angezeigt (lebendig: %s, aktiv: %s)" % [
			"ja" if monster.is_alive() else "nein",
			"ja" if monster == team.get_active_monster() else "nein"
		])
	
	# Back-Button
	_add_back_button()
	_focus_first_button()

func _clear_menu() -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
	_clear_attack_info()
	_menu_buttons.clear()
	_menu_columns = 1

func _add_back_button() -> void:
	# Erstelle HBoxContainer für Back-Button rechts neben Grid
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	vbox.add_child(hbox)
	
	# Spacer links (nimmt restlichen Platz)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	var back_button := Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(140, 0)
	back_button.add_theme_font_size_override("font_size", 12)
	back_button.pressed.connect(func():
		if current_menu == "main":
			hide_menu()
		else:
			show_main_menu(current_monster, current_team, battle_controller)
	)
	hbox.add_child(back_button)
	_register_menu_button(back_button)

func hide_menu():
	_clear_menu()  # Lösche alle Buttons bevor das Menu versteckt wird
	_is_showing_menu = false  # Stelle sicher, dass das Flag zurückgesetzt wird
	visible = false

func _update_attack_info(attack: AttackData) -> void:
	if attack_info_name == null:
		return
	attack_info_name.text = attack.name
	attack_info_description.text = attack.description
	attack_info_power.text = "Power: %d" % attack.power
	attack_info_element.text = "Element: %s" % Element.Type.keys()[attack.element]
	attack_info_energy.text = "Energy Cost: %d" % attack.energy_cost
	attack_info_accuracy.text = "Accuracy: %d%%" % attack.accuracy
	attack_info_priority.text = "Priority: %d" % attack.priority

func _clear_attack_info() -> void:
	if attack_info_name == null:
		return
	attack_info_name.text = "Hover: Attack"
	attack_info_description.text = ""
	attack_info_power.text = "Power: -"
	attack_info_element.text = "Element: -"
	attack_info_energy.text = "Energy Cost: -"
	attack_info_accuracy.text = "Accuracy: -"
	attack_info_priority.text = "Priority: -"

func _register_menu_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_ALL
	_menu_buttons.append(button)

func _focus_first_button() -> void:
	if _menu_buttons.size() > 0:
		_menu_buttons[0].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_up"):
		_move_focus(0, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_focus(0, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_move_focus(-1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move_focus(1, 0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_activate_focused_button()
		get_viewport().set_input_as_handled()

func _move_focus(dx: int, dy: int) -> void:
	var count: int = _menu_buttons.size()
	if count == 0:
		return
	var columns: int = max(1, _menu_columns)
	var rows: int = int(ceil(count / float(columns)))

	var current_index: int = 0
	for i in range(count):
		if _menu_buttons[i].has_focus():
			current_index = i
			break

	var row: int = current_index / columns
	var col: int = current_index % columns
	var new_row: int = row + dy
	var new_col: int = col + dx

	if new_row < 0 or new_row >= rows:
		return
	new_col = clamp(new_col, 0, columns - 1)

	var target: int = new_row * columns + new_col
	while target >= count and new_col > 0:
		new_col -= 1
		target = new_row * columns + new_col
	if target >= count:
		return

	_menu_buttons[target].grab_focus()

func _activate_focused_button() -> void:
	for button in _menu_buttons:
		if button.has_focus():
			button.emit_signal("pressed")
			return
