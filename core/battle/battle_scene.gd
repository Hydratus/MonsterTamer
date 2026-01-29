extends Node2D
class_name BattleScene

@onready var menu: BattleMenu = $BattleMenu

# Team-Konfiguration im Inspector
@export var player_team: Array[MonsterData] = []
@export var enemy_team: Array[MonsterData] = []

var battle: BattleController
var battle_started := false  # Flag um doppelte Starts zu verhindern
var player_team_instance: MonsterTeam  # Referenz auf das Spieler-Team


func _ready():
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
	
	# Trenne alte Signale wenn noch verbunden
	if menu.action_selected.is_connected(Callable(self, "_on_menu_action_selected")):
		menu.action_selected.disconnect(Callable(self, "_on_menu_action_selected"))
	if menu.escape_battle.is_connected(Callable(self, "_on_menu_escape_battle")):
		menu.escape_battle.disconnect(Callable(self, "_on_menu_escape_battle"))
	
	# Verbinde neue Signale
	menu.action_selected.connect(Callable(self, "_on_menu_action_selected"))
	menu.escape_battle.connect(Callable(self, "_on_menu_escape_battle"))
	
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

# Helper, damit UI sauber Aktionen an den Controller übergeben kann
func submit_action_to_battle(action) -> void:
	if battle == null:
		push_error("Battle nicht initialisiert - kann Aktion nicht einreichen")
		return
	if battle.has_method("submit_action"):
		battle.submit_action(action)

func hide_ui() -> void:
	menu.hide_menu()
