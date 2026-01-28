extends Node2D
class_name BattleScene

@onready var menu: BattleMenu = $BattleMenu

# Team-Konfiguration im Inspector
@export var player_team: Array[MonsterData] = []
@export var enemy_team: Array[MonsterData] = []

var battle: BattleController
var battle_started := false  # Flag um doppelte Starts zu verhindern


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
	
	battle.start_battle(team1, team2)


func show_player_menu(monster: MonsterInstance):
	menu.show_attacks(monster)

	menu.action_selected.connect(func(attack: AttackData):
		menu.hide_menu()
		battle.submit_player_attack(monster, attack)
	, CONNECT_ONE_SHOT)
