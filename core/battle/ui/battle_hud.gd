extends Control
class_name MTBattleHUD

var enemy_monster: MTMonsterInstance = null
var player_monster: MTMonsterInstance = null

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

var _hp_lerp_speed := 4.5
var _energy_lerp_speed := 4.5
var _enemy_hp_target := 0.0
var _player_hp_target := 0.0
var _player_energy_target := 0.0

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
	enemy_panel.offset_bottom = 130
	enemy_panel.grow_horizontal = GROW_DIRECTION_END
	enemy_panel.grow_vertical = GROW_DIRECTION_END
	add_child(enemy_panel)
	
	var enemy_vbox = VBoxContainer.new()
	enemy_vbox.add_theme_constant_override("separation", 5)
	enemy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel.add_child(enemy_vbox)
	
	enemy_name_label = Label.new()
	enemy_name_label.text = tr("Enemy: ---")
	enemy_name_label.add_theme_font_size_override("font_size", 16)
	enemy_vbox.add_child(enemy_name_label)
	
	enemy_level_label = Label.new()
	enemy_level_label.text = tr("Level: ---")
	enemy_vbox.add_child(enemy_level_label)
	
	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(0, 20)
	enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_hp_bar.show_percentage = false
	enemy_hp_bar.step = 0.01
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.value = 0
	_configure_bar_style(enemy_hp_bar, Color(0.82, 0.15, 0.12, 1.0))
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
	player_panel.offset_top = -165  # Auf Attack-Menü-Höhe ausgerichtet
	player_panel.offset_right = -10  # 10px Abstand zum rechten Rand
	player_panel.offset_bottom = -10 # Bis zum unteren Rand
	player_panel.grow_horizontal = GROW_DIRECTION_BEGIN
	player_panel.grow_vertical = GROW_DIRECTION_BEGIN
	add_child(player_panel)
	
	var player_vbox = VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 5)
	player_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_panel.add_child(player_vbox)
	
	player_name_label = Label.new()
	player_name_label.text = tr("Player: ---")
	player_name_label.add_theme_font_size_override("font_size", 16)
	player_vbox.add_child(player_name_label)
	
	player_level_label = Label.new()
	player_level_label.text = tr("Level: ---")
	player_vbox.add_child(player_level_label)
	
	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(0, 20)
	player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hp_bar.show_percentage = false
	player_hp_bar.step = 0.01
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = 100
	player_hp_bar.value = 0
	_configure_bar_style(player_hp_bar, Color(0.12, 0.72, 0.18, 1.0))
	player_vbox.add_child(player_hp_bar)
	
	player_hp_label = Label.new()
	player_hp_label.text = "0/0"
	player_hp_label.add_theme_font_size_override("font_size", 12)
	player_vbox.add_child(player_hp_label)
	
	player_energy_bar = ProgressBar.new()
	player_energy_bar.custom_minimum_size = Vector2(0, 20)
	player_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_energy_bar.show_percentage = false
	player_energy_bar.step = 0.01
	player_energy_bar.min_value = 0
	player_energy_bar.max_value = 100
	player_energy_bar.value = 0
	_configure_bar_style(player_energy_bar, Color(0.16, 0.58, 1.0, 1.0))
	player_vbox.add_child(player_energy_bar)
	
	player_energy_label = Label.new()
	player_energy_label.text = "0/0"
	player_energy_label.add_theme_font_size_override("font_size", 12)
	player_vbox.add_child(player_energy_label)

func update_monsters(player_mon: MTMonsterInstance, enemy_mon: MTMonsterInstance):
	player_monster = player_mon
	enemy_monster = enemy_mon
	
	print("DEBUG HUD update: player=%s, enemy=%s" % [
		player_mon.data.name if player_mon else "null",
		enemy_mon.data.name if enemy_mon else "null"
	])
	
	_apply_live_display_state()

func apply_snapshot(snapshot: Dictionary) -> void:
	player_monster = snapshot.get("player_monster", null)
	enemy_monster = snapshot.get("enemy_monster", null)
	_apply_display_state(snapshot.get("player", {}), snapshot.get("enemy", {}))

func _apply_live_display_state() -> void:
	_apply_display_state(_build_monster_state(player_monster), _build_monster_state(enemy_monster))

func _build_monster_state(monster: MTMonsterInstance) -> Dictionary:
	if monster == null:
		return {}
	return {
		"name": monster.data.name,
		"level": monster.level,
		"hp": monster.hp,
		"max_hp": monster.get_max_hp(),
		"energy": monster.energy,
		"max_energy": monster.get_max_energy()
	}

func _apply_display_state(player_state: Dictionary, enemy_state: Dictionary) -> void:
	if enemy_state.is_empty():
		enemy_name_label.text = tr("Enemy: ---")
		enemy_level_label.text = tr("Level: ---")
		enemy_hp_bar.max_value = 100
		_enemy_hp_target = 0.0
		enemy_hp_label.text = "0/0"
	else:
		enemy_name_label.text = tr("Enemy: %s") % String(enemy_state.get("name", "---"))
		enemy_level_label.text = tr("Level: %d") % int(enemy_state.get("level", 0))
		enemy_hp_bar.max_value = 100
		_enemy_hp_target = _to_percent(
			int(enemy_state.get("hp", 0)),
			int(enemy_state.get("max_hp", 0))
		)
		enemy_hp_label.text = _format_resource_label(
			int(enemy_state.get("hp", 0)),
			int(enemy_state.get("max_hp", 0))
		)

	if player_state.is_empty():
		player_name_label.text = tr("Player: ---")
		player_level_label.text = tr("Level: ---")
		player_hp_bar.max_value = 100
		_player_hp_target = 0.0
		player_hp_label.text = "0/0"
		player_energy_bar.max_value = 100
		_player_energy_target = 0.0
		player_energy_label.text = "0/0"
	else:
		player_name_label.text = tr("Player: %s") % String(player_state.get("name", "---"))
		player_level_label.text = tr("Level: %d") % int(player_state.get("level", 0))
		player_hp_bar.max_value = 100
		_player_hp_target = _to_percent(
			int(player_state.get("hp", 0)),
			int(player_state.get("max_hp", 0))
		)
		player_hp_label.text = _format_resource_label(
			int(player_state.get("hp", 0)),
			int(player_state.get("max_hp", 0))
		)
		player_energy_bar.max_value = 100
		_player_energy_target = _to_percent(
			int(player_state.get("energy", 0)),
			int(player_state.get("max_energy", 0))
		)
		player_energy_label.text = _format_resource_label(
			int(player_state.get("energy", 0)),
			int(player_state.get("max_energy", 0))
		)

func _process(delta):
	if enemy_monster != null:
		enemy_hp_bar.value = _animate_resource_bar(
			enemy_hp_bar.value,
			_enemy_hp_target,
			delta,
			_hp_lerp_speed,
			enemy_hp_bar.max_value
		)
	if player_monster != null:
		player_hp_bar.value = _animate_resource_bar(
			player_hp_bar.value,
			_player_hp_target,
			delta,
			_hp_lerp_speed,
			player_hp_bar.max_value
		)
		player_energy_bar.value = _animate_resource_bar(
			player_energy_bar.value,
			_player_energy_target,
			delta,
			_energy_lerp_speed,
			player_energy_bar.max_value
		)

func _animate_resource_bar(current_value: float, target_value: float, delta: float, speed: float, max_value: float) -> float:
	var next_value: float = lerp(current_value, target_value, clamp(delta * speed, 0.0, 1.0))
	next_value = clamp(next_value, 0.0, max_value)

	# Snap nur kurz vor Ziel, damit die Animation sichtbar bleibt.
	if abs(next_value - target_value) <= 0.05:
		next_value = target_value

	# Verhindert Restpixel-Balken bei 0 HP/EN.
	if target_value <= 0.0 and next_value <= 0.35:
		next_value = 0.0

	return next_value

func _to_percent(current: int, max_value: int) -> float:
	if max_value <= 0:
		return 0.0
	return clamp((float(current) / float(max_value)) * 100.0, 0.0, 100.0)

func _configure_bar_style(bar: ProgressBar, fill_color: Color) -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.09, 0.11, 0.14, 0.9)
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4

	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4

	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)

func _format_resource_label(current: int, max_value: int) -> String:
	if max_value <= 0:
		return "%d/%d (0%%)" % [current, max_value]
	var percent: int = int(round((float(current) / float(max_value)) * 100.0))
	percent = clamp(percent, 0, 100)
	return "%d/%d (%d%%)" % [current, max_value, percent]
