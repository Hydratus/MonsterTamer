extends CanvasLayer
class_name BattleMenu

signal action_selected(attack: AttackData)
signal escape_battle

@onready var control := $Control
@onready var vbox := $Control/VBoxContainer

var current_monster: MonsterInstance
var current_team: MonsterTeam
var battle_controller: BattleController  # Referenz zum BattleController für Aktionen
var current_menu: String = "main"  # "main", "attacks", "team", "inventory", "escape"
var _is_showing_menu := false  # Flag um doppelte show_main_menu() Aufrufe zu verhindern
var _connected_monster: MonsterInstance = null  # Trackiere welches Monster die Signale verbunden hat

func _ready():
	# Verstecke das Menu initial
	visible = false

func show_main_menu(monster: MonsterInstance, team: MonsterTeam = null, controller: BattleController = null):
	# Verhindere gleichzeitige Aufrufe
	if _is_showing_menu:
		return
	
	_is_showing_menu = true
	
	current_monster = monster
	current_team = team
	battle_controller = controller
	current_menu = "main"
	
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
	
	_is_showing_menu = false

func show_attacks(monster: MonsterInstance):
	current_monster = monster
	current_menu = "attacks"
	_clear_menu()
	
	for attack in monster.attacks:
		var button := Button.new()
		button.text = attack.name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func():
			# Emitiere mit dem aktuellen Monster (zur Ausführungszeit)
			action_selected.emit(attack)
		)
		vbox.add_child(button)
	
	# Back-Button
	_add_back_button()
	visible = true

func show_team(team: MonsterTeam):
	current_team = team
	current_menu = "team"
	_clear_menu()
	
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
		button.text = "%s %s | Lvl %d | %d/%d HP" % [
			monster.data.name,
			status,
			monster.data.level,
			monster.hp,
			monster.get_max_hp()
		]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Button für Monster-Details und Switch
		button.pressed.connect(func():
			_show_monster_options(team, i, monster)
		)
		
		vbox.add_child(button)
	
	# Back-Button
	_add_back_button()
	visible = true

func show_inventory():
	current_menu = "inventory"
	_clear_menu()
	
	var label := Label.new()
	label.text = "🎒 Inventory\n\n(Noch nicht implementiert)"
	vbox.add_child(label)
	
	# Back-Button
	_add_back_button()
	visible = true

func show_escape_menu():
	current_menu = "escape"
	_clear_menu()
	
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
	
	var no_button := Button.new()
	no_button.text = "Nein, zurück"
	no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_button.pressed.connect(func():
		show_main_menu(current_monster, current_team)
	)
	vbox.add_child(no_button)
	visible = true

# Private Hilfsfunktionen

func _show_menu_options(options: Array) -> void:
	_clear_menu()
	
	print("DEBUG _show_menu_options: %d Optionen werden hinzugefügt" % options.size())
	
	for option in options:
		var button := Button.new()
		button.text = option["label"]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var action = option["action"]
		button.pressed.connect(func():
			_handle_menu_action(action)
		)
		
		vbox.add_child(button)
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
	
	print("DEBUG: Zeige Monster-Options für %s (Index: %d, aktiv: %s)" % [
		monster.data.name,
		index,
		"ja" if monster == team.get_active_monster() else "nein"
	])
	
	var label := Label.new()
	label.text = "%s - Level %d\n\nHP: %d/%d\nSTR: %d | MAG: %d\nDEF: %d | RES: %d\nSPD: %d" % [
		monster.data.name,
		monster.data.level,
		monster.hp,
		monster.get_max_hp(),
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
	else:
		print("DEBUG: Einwechsel-Button wird NICHT angezeigt (lebendig: %s, aktiv: %s)" % [
			"ja" if monster.is_alive() else "nein",
			"ja" if monster == team.get_active_monster() else "nein"
		])
	
	# Back-Button
	_add_back_button()

func _clear_menu() -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

func _add_back_button() -> void:
	var separator := HSeparator.new()
	vbox.add_child(separator)
	
	var back_button := Button.new()
	back_button.text = "← Zurück"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.pressed.connect(func():
		if current_menu == "main":
			hide_menu()
		else:
			show_main_menu(current_monster, current_team, battle_controller)
	)
	vbox.add_child(back_button)

func hide_menu():
	_clear_menu()  # Lösche alle Buttons bevor das Menu versteckt wird
	_is_showing_menu = false  # Stelle sicher, dass das Flag zurückgesetzt wird
	visible = false
