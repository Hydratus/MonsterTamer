extends Node2D
class_name BattleScene

@onready var menu: BattleMenu = $BattleMenu

var hud: BattleHUD
var message_box: BattleMessageBox

# Team-Konfiguration im Inspector
@export var player_team: Array[MonsterData] = []
@export var enemy_team: Array[MonsterData] = []

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
	
	# Starte automatisch einen Kampf wenn Teams im Inspector konfiguriert sind
	# (Nur wenn die Szene direkt geladen wird, nicht wenn sie von außen gestartet wird)
	if player_team.size() > 0 and enemy_team.size() > 0 and not battle_started:
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
	if battle != null and battle.current_state != null:
		if battle.current_state.has_method("on_messages_completed"):
			battle.current_state.on_messages_completed(battle)
