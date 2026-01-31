extends Control
class_name BattleHUD

var enemy_monster: MonsterInstance = null
var player_monster: MonsterInstance = null

# Enemy Panel (Top Left)
var enemy_panel: PanelContainer
var enemy_name_label: Label
var enemy_level_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label

# Player Panel (Bottom Right)
var player_panel: PanelContainer
var player_name_label: Label
var player_level_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var player_energy_bar: ProgressBar
var player_energy_label: Label

func _ready():
	# Setze die Größe der Control auf den gesamten Bildschirm
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# WICHTIG: Erlaube Mouse-Events durch das HUD hindurch
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Erstelle Enemy Panel (Top Left) - mit festen Margins statt Position
	enemy_panel = PanelContainer.new()
	enemy_panel.anchor_left = 0.0
	enemy_panel.anchor_top = 0.0
	enemy_panel.anchor_right = 0.0
	enemy_panel.anchor_bottom = 0.0
	enemy_panel.offset_left = 10
	enemy_panel.offset_top = 10
	enemy_panel.offset_right = 260  # 250px breit + 10px margin
	enemy_panel.offset_bottom = 110  # 100px hoch + 10px margin
	enemy_panel.grow_horizontal = GROW_DIRECTION_END
	enemy_panel.grow_vertical = GROW_DIRECTION_END
	add_child(enemy_panel)
	
	var enemy_vbox = VBoxContainer.new()
	enemy_vbox.add_theme_constant_override("separation", 5)
	enemy_panel.add_child(enemy_vbox)
	
	enemy_name_label = Label.new()
	enemy_name_label.text = "Enemy: ---"
	enemy_name_label.add_theme_font_size_override("font_size", 16)
	enemy_vbox.add_child(enemy_name_label)
	
	enemy_level_label = Label.new()
	enemy_level_label.text = "Level: ---"
	enemy_vbox.add_child(enemy_level_label)
	
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(200, 20)
	enemy_hp_bar.modulate = Color.RED
	enemy_vbox.add_child(enemy_hp_bar)
	
	enemy_hp_label = Label.new()
	enemy_hp_label.text = "0/0"
	enemy_hp_label.add_theme_font_size_override("font_size", 12)
	enemy_vbox.add_child(enemy_hp_label)
	
	# Erstelle Player Panel (Bottom Right) - mit Anchors für responsive Design
	player_panel = PanelContainer.new()
	player_panel.anchor_left = 1.0
	player_panel.anchor_top = 1.0
	player_panel.anchor_right = 1.0
	player_panel.anchor_bottom = 1.0
	player_panel.offset_left = -260  # 250px breit + 10px margin
	player_panel.offset_top = -170   # Tiefer, auf Höhe von Actions/Textbox
	player_panel.offset_right = -10  # 10px Abstand zum rechten Rand
	player_panel.offset_bottom = -10 # Bis zum unteren Rand
	player_panel.grow_horizontal = GROW_DIRECTION_BEGIN
	player_panel.grow_vertical = GROW_DIRECTION_BEGIN
	add_child(player_panel)
	
	var player_vbox = VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 5)
	player_panel.add_child(player_vbox)
	
	player_name_label = Label.new()
	player_name_label.text = "Player: ---"
	player_name_label.add_theme_font_size_override("font_size", 16)
	player_vbox.add_child(player_name_label)
	
	player_level_label = Label.new()
	player_level_label.text = "Level: ---"
	player_vbox.add_child(player_level_label)
	
	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(200, 20)
	player_hp_bar.modulate = Color.GREEN
	player_vbox.add_child(player_hp_bar)
	
	player_hp_label = Label.new()
	player_hp_label.text = "0/0"
	player_hp_label.add_theme_font_size_override("font_size", 12)
	player_vbox.add_child(player_hp_label)
	
	player_energy_bar = ProgressBar.new()
	player_energy_bar.custom_minimum_size = Vector2(200, 20)
	player_energy_bar.modulate = Color.BLUE
	player_vbox.add_child(player_energy_bar)
	
	player_energy_label = Label.new()
	player_energy_label.text = "0/0"
	player_energy_label.add_theme_font_size_override("font_size", 12)
	player_vbox.add_child(player_energy_label)

func update_monsters(player_mon: MonsterInstance, enemy_mon: MonsterInstance):
	player_monster = player_mon
	enemy_monster = enemy_mon
	
	print("DEBUG HUD update: player=%s, enemy=%s" % [
		player_mon.data.name if player_mon else "null",
		enemy_mon.data.name if enemy_mon else "null"
	])
	
	update_displays()

func update_displays():
	# Aktualisiere Enemy-Anzeige
	if enemy_monster != null:
		enemy_name_label.text = "Enemy: %s" % enemy_monster.data.name
		enemy_level_label.text = "Level: %d" % enemy_monster.level
		enemy_hp_bar.max_value = enemy_monster.get_max_hp()
		enemy_hp_bar.value = enemy_monster.hp
		enemy_hp_label.text = "%d/%d" % [enemy_monster.hp, enemy_monster.get_max_hp()]
	else:
		enemy_name_label.text = "Enemy: ---"
		enemy_level_label.text = "Level: ---"
		enemy_hp_label.text = "0/0"
	
	# Aktualisiere Player-Anzeige
	if player_monster != null:
		player_name_label.text = "Player: %s" % player_monster.data.name
		player_level_label.text = "Level: %d" % player_monster.level
		player_hp_bar.max_value = player_monster.get_max_hp()
		player_hp_bar.value = player_monster.hp
		player_hp_label.text = "%d/%d" % [player_monster.hp, player_monster.get_max_hp()]
		
		player_energy_bar.max_value = player_monster.get_max_energy()
		player_energy_bar.value = player_monster.energy
		player_energy_label.text = "%d/%d" % [player_monster.energy, player_monster.get_max_energy()]
	else:
		player_name_label.text = "Player: ---"
		player_level_label.text = "Level: ---"
		player_hp_label.text = "0/0"
		player_energy_label.text = "0/0"

func _process(_delta):
	# Aktualisiere die Anzeige jeden Frame
	if enemy_monster != null or player_monster != null:
		update_displays()
