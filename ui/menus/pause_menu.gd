extends CanvasLayer
class_name PauseMenuUI

signal closed

const CONFIG_PATH := "user://settings.cfg"

const GAMEPAD_BTN_A := 0
const GAMEPAD_BTN_B := 1
const GAMEPAD_BTN_X := 2
const GAMEPAD_BTN_Y := 3
const GAMEPAD_BTN_LB := 4
const GAMEPAD_BTN_RB := 5
const GAMEPAD_BTN_BACK := 6
const GAMEPAD_BTN_START := 7
const GAMEPAD_BTN_L3 := 9
const GAMEPAD_BTN_R3 := 10
const GAMEPAD_BTN_DPAD_UP := 11
const GAMEPAD_BTN_DPAD_DOWN := 12
const GAMEPAD_BTN_DPAD_LEFT := 13
const GAMEPAD_BTN_DPAD_RIGHT := 14

const MODE_OPTIONS: Array = [
	{"label": "Vollbild", "value": "fullscreen"},
	{"label": "RandlosFenster", "value": "borderless"},
	{"label": "Fenster", "value": "windowed"}
]

const RESOLUTIONS: Array = [
	Vector2i(640, 480),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

const CONTROL_CATEGORIES: Array = [
	{
		"name": "Movement",
		"actions": [
			{"action": "ui_up", "label": "Up"},
			{"action": "ui_down", "label": "Down"},
			{"action": "ui_left", "label": "Left"},
			{"action": "ui_right", "label": "Right"},
			{"action": "run", "label": "Run"}
		]
	},
	{
		"name": "Interaction",
		"actions": [
			{"action": "ui_accept", "label": "Accept"},
			{"action": "ui_cancel", "label": "Back"}
		]
	},
	{
		"name": "Menu",
		"actions": [
			{"action": "tab_left", "label": "Tab Left"},
			{"action": "tab_right", "label": "Tab Right"}
		]
	},
	{
		"name": "Menu",
		"actions": [
			{"action": "pause_menu", "label": "Pause Menu"}
		]
	}
]

const DEFAULT_KEYBOARD: Dictionary = {
	"ui_up": KEY_UP,
	"ui_down": KEY_DOWN,
	"ui_left": KEY_LEFT,
	"ui_right": KEY_RIGHT,
	"ui_accept": KEY_SPACE,
	"ui_cancel": KEY_SHIFT,
	"run": KEY_SHIFT,
	"pause_menu": KEY_ESCAPE,
	"tab_left": KEY_Q,
	"tab_right": KEY_E
}

const DEFAULT_CONTROLLER: Dictionary = {
	"ui_up": GAMEPAD_BTN_DPAD_UP,
	"ui_down": GAMEPAD_BTN_DPAD_DOWN,
	"ui_left": GAMEPAD_BTN_DPAD_LEFT,
	"ui_right": GAMEPAD_BTN_DPAD_RIGHT,
	"ui_accept": GAMEPAD_BTN_A,
	"ui_cancel": GAMEPAD_BTN_B,
	"run": GAMEPAD_BTN_B,
	"pause_menu": GAMEPAD_BTN_START,
	"tab_left": GAMEPAD_BTN_LB,
	"tab_right": GAMEPAD_BTN_RB
}

@onready var _team_panel: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/TeamPanel as Control
@onready var _settings_panel: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel as Control
@onready var _settings_tabs: TabContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs as TabContainer
@onready var _team_list: VBoxContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/TeamPanel/TeamScroll/TeamList as VBoxContainer
@onready var _team_scroll: ScrollContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/TeamPanel/TeamScroll as ScrollContainer
@onready var _video_tab: VBoxContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs/Video as VBoxContainer
@onready var _sound_tab: VBoxContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs/Sound as VBoxContainer
@onready var _controls_tab: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs/Controls as Control
@onready var _controls_list: VBoxContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs/Controls/ControlsScroll/ControlsList as VBoxContainer
@onready var _controls_scroll: ScrollContainer = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel/SettingsTabs/Controls/ControlsScroll as ScrollContainer
@onready var _team_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonTeam as Button
@onready var _settings_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonSettings as Button
@onready var _close_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonClose as Button
@onready var _end_game_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonEndGame as Button

var _mode_option: OptionButton
var _resolution_option: OptionButton
var _vsync_check: CheckBox
var _fps_slider: HSlider
var _fps_value_label: Label

var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _volume_value_labels: Dictionary = {}

var _binding_action := ""
var _binding_device := ""
var _binding_button: Button
var _control_buttons: Dictionary = {}
var _controls_nav_keyboard: Array[Button] = []
var _controls_nav_controller: Array[Button] = []
var _controls_header_for_button: Dictionary = {}
var _team_buttons: Array[Button] = []
var _sidebar_buttons: Array[Button] = []
var _in_content := false
var _last_sidebar_focus := "team"
var _menu_level := "sidebar"
var _active_section := "team"
var _last_settings_tab := 0
var _controls_tab_index := -1

var _settings: Dictionary = {
	"video": {
		"mode": "windowed",
		"resolution": Vector2i(1280, 720),
		"vsync": true,
		"max_fps": 0
	},
	"audio": {
		"master": 0.8,
		"music": 0.8,
		"sfx": 0.8
	},
	"controls": {}
}

func _ready() -> void:
	visible = false
	set_process_unhandled_input(true)
	set_process_input(true)
	_settings_tabs.focus_mode = Control.FOCUS_ALL
	_set_tab_bar_focus_enabled(false)
	_controls_tab_index = _get_tab_index(_controls_tab)
	_settings_tabs.tab_changed.connect(_on_settings_tab_changed)
	_team_button.pressed.connect(_on_team_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_end_game_button.pressed.connect(_on_end_game_pressed)
	_team_button.focus_entered.connect(func(): _on_sidebar_focus("team"))
	_settings_button.focus_entered.connect(func(): _on_sidebar_focus("settings"))
	_close_button.focus_entered.connect(func(): _on_sidebar_focus("close"))
	_end_game_button.focus_entered.connect(func(): _on_sidebar_focus("end_game"))
	_sidebar_buttons = [_team_button, _settings_button, _close_button, _end_game_button]
	_build_video_tab()
	_build_sound_tab()
	_build_controls_tab()
	_load_settings()
	_apply_all_settings()
	_show_section("team")

func open(team: Array) -> void:
	visible = true
	_in_content = false
	_menu_level = "sidebar"
	_active_section = "team"
	_set_sidebar_focus_enabled(true)
	_set_tabs_focus_enabled(false)
	_update_team_list(team)
	_set_team_buttons_focus_enabled(false)
	_set_all_tab_content_focus_enabled(false)
	_show_section("team")
	_team_button.grab_focus()

func close() -> void:
	visible = false
	_in_content = false
	_menu_level = "sidebar"
	_set_sidebar_focus_enabled(true)
	_set_tabs_focus_enabled(false)
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if _menu_level == "sidebar" and focus_owner != _team_button and focus_owner != _settings_button and focus_owner != _close_button and focus_owner != _end_game_button:
		_focus_sidebar_selection()
		get_viewport().set_input_as_handled()
		return
	if focus_owner == _team_button or focus_owner == _settings_button or focus_owner == _close_button or focus_owner == _end_game_button:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			return
	if _binding_action != "":
		if event is InputEventKey and event.pressed and not event.echo and _binding_device == "keyboard":
			_apply_binding(event)
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed and _binding_device == "controller":
			_apply_binding(event)
			get_viewport().set_input_as_handled()
			return
		return
	if event.is_action_pressed("ui_cancel"):
		if _menu_level == "content" and _active_section == "settings":
			_settings_to_tabs()
		elif _menu_level == "tabs" and _active_section == "settings":
			_settings_to_sidebar()
		elif _in_content:
			_leave_content()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if _menu_level == "content" and _active_section == "settings" and _is_controls_tab_active():
		if _is_action_press(event, "ui_up"):
			if _move_controls_focus(-1):
				get_viewport().set_input_as_handled()
				return
		if _is_action_press(event, "ui_down"):
			if _move_controls_focus(1):
				get_viewport().set_input_as_handled()
				return
	if _menu_level == "sidebar":
		if focus_owner == _settings_tabs:
			_settings_button.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			if focus_owner == _team_button:
				_enter_team()
				get_viewport().set_input_as_handled()
				return
			if focus_owner == _settings_button:
				_enter_settings()
				get_viewport().set_input_as_handled()
				return
			if focus_owner == _close_button:
				close()
				get_viewport().set_input_as_handled()
				return
			if focus_owner == _end_game_button:
				_end_game()
				get_viewport().set_input_as_handled()
				return
		return
	if _menu_level == "tabs" and _active_section == "settings":
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("tab_left"):
			_settings_select_prev_tab()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("tab_right"):
			_settings_select_next_tab()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_down"):
			_settings_to_content()
			get_viewport().set_input_as_handled()
			return

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if _menu_level == "content" and _active_section == "settings" and _is_controls_tab_active():
		if event.is_action_pressed("ui_up"):
			if _move_controls_focus(-1):
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_down"):
			if _move_controls_focus(1):
				get_viewport().set_input_as_handled()
				return
	if _menu_level == "tabs" and _active_section == "settings":
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			return
	if focus_owner == _team_button or focus_owner == _settings_button or focus_owner == _close_button or focus_owner == _end_game_button:
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			return

func _on_team_pressed() -> void:
	_enter_team()

func _on_settings_pressed() -> void:
	_enter_settings()

func _on_close_pressed() -> void:
	close()

func _on_end_game_pressed() -> void:
	_end_game()

func _end_game() -> void:
	get_tree().quit()

func _on_sidebar_focus(section: String) -> void:
	_last_sidebar_focus = section
	_menu_level = "sidebar"
	_in_content = false
	_set_tabs_focus_enabled(false)
	_set_all_tab_content_focus_enabled(false)
	_set_team_buttons_focus_enabled(false)
	if section == "team":
		_show_section("team")
		_active_section = "team"
	elif section == "settings":
		_show_section("settings")
		_active_section = "settings"
	elif section == "end_game":
		pass

func _show_section(section: String) -> void:
	_team_panel.visible = section == "team"
	_settings_panel.visible = section == "settings"

func _update_team_list(team: Array) -> void:
	_team_buttons.clear()
	for child in _team_list.get_children():
		child.free()
	if team == null or team.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No team members."
		_team_list.add_child(empty_label)
		return
	for member in team:
		if member == null:
			continue
		var entry_button := Button.new()
		entry_button.focus_mode = Control.FOCUS_NONE
		entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_button.text = "%s | Lvl %d | HP %d/%d | EN %d/%d\nSTR %d | MAG %d | DEF %d | RES %d | SPD %d" % [
			member.data.name,
			member.level,
			member.hp,
			member.get_max_hp(),
			member.energy,
			member.get_max_energy(),
			member.strength,
			member.magic,
			member.defense,
			member.resistance,
			member.speed
		]
		entry_button.focus_entered.connect(func():
			_ensure_scroll_visible(_team_scroll, entry_button)
		)
		_team_list.add_child(entry_button)
		_team_buttons.append(entry_button)

func _build_video_tab() -> void:
	_video_tab.add_theme_constant_override("separation", 8)
	_mode_option = OptionButton.new()
	for item in MODE_OPTIONS:
		_mode_option.add_item(item.label)
	_mode_option.item_selected.connect(func(index: int):
		var value: String = str(MODE_OPTIONS[index].value)
		_settings.video.mode = value
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_create_labeled_row("Window Mode", _mode_option))

	_resolution_option = OptionButton.new()
	for res in RESOLUTIONS:
		_resolution_option.add_item("%dx%d" % [res.x, res.y])
	_resolution_option.item_selected.connect(func(index: int):
		_settings.video.resolution = RESOLUTIONS[index]
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_create_labeled_row("Resolution", _resolution_option))

	_vsync_check = CheckBox.new()
	_vsync_check.text = "VSync"
	_vsync_check.toggled.connect(func(pressed: bool):
		_settings.video.vsync = pressed
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_vsync_check)

	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 8)
	var fps_label := Label.new()
	fps_label.text = "Max FPS"
	fps_label.custom_minimum_size = Vector2(160, 0)
	fps_row.add_child(fps_label)
	_fps_slider = HSlider.new()
	_fps_slider.min_value = 0
	_fps_slider.max_value = 240
	_fps_slider.step = 5
	_fps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fps_slider.value_changed.connect(func(value: float):
		_settings.video.max_fps = int(value)
		_update_fps_label()
		_apply_max_fps()
		_save_settings()
	)
	fps_row.add_child(_fps_slider)
	_fps_value_label = Label.new()
	_fps_value_label.text = "0"
	_fps_value_label.custom_minimum_size = Vector2(50, 0)
	fps_row.add_child(_fps_value_label)
	_video_tab.add_child(fps_row)

func _build_sound_tab() -> void:
	_sound_tab.add_theme_constant_override("separation", 8)
	_master_slider = _create_volume_slider("Master Volume", "master")
	_music_slider = _create_volume_slider("Music Volume", "music")
	_sfx_slider = _create_volume_slider("SFX Volume", "sfx")

func _build_controls_tab() -> void:
	_controls_list.add_theme_constant_override("separation", 8)
	_ensure_default_bindings()
	_control_buttons.clear()
	_controls_nav_keyboard.clear()
	_controls_nav_controller.clear()
	_controls_header_for_button.clear()
	for category in CONTROL_CATEGORIES:
		var header := Label.new()
		header.text = category.name
		header.add_theme_font_size_override("font_size", 14)
		_controls_list.add_child(header)
		var first_in_category := true

		var column_row := HBoxContainer.new()
		column_row.add_theme_constant_override("separation", 8)
		var col_action := Label.new()
		col_action.text = "Action"
		col_action.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_action)
		var col_keyboard := Label.new()
		col_keyboard.text = "Keyboard"
		col_keyboard.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_keyboard)
		var col_controller := Label.new()
		col_controller.text = "Controller"
		col_controller.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_controller)
		_controls_list.add_child(column_row)

		for action_info in category.actions:
			var action_name: String = action_info.action
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var action_label := Label.new()
			action_label.text = action_info.label
			action_label.custom_minimum_size = Vector2(160, 0)
			row.add_child(action_label)

			var keyboard_button := Button.new()
			keyboard_button.custom_minimum_size = Vector2(160, 0)
			keyboard_button.focus_entered.connect(func():
				var target_header: Control = header if first_in_category else null
				_ensure_controls_focus_visible(target_header, row, keyboard_button)
			)
			keyboard_button.pressed.connect(func():
				_start_binding(action_name, "keyboard", keyboard_button)
			)
			row.add_child(keyboard_button)
			_controls_nav_keyboard.append(keyboard_button)

			var controller_button := Button.new()
			controller_button.custom_minimum_size = Vector2(160, 0)
			controller_button.focus_entered.connect(func():
				var target_header: Control = header if first_in_category else null
				_ensure_controls_focus_visible(target_header, row, controller_button)
			)
			controller_button.pressed.connect(func():
				_start_binding(action_name, "controller", controller_button)
			)
			row.add_child(controller_button)
			_controls_nav_controller.append(controller_button)

			_controls_list.add_child(row)
			_control_buttons[action_name] = {
				"keyboard": keyboard_button,
				"controller": controller_button
			}
			if first_in_category:
				_controls_header_for_button[keyboard_button] = header
				_controls_header_for_button[controller_button] = header
				first_in_category = false

	_refresh_control_buttons()

func _create_labeled_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _create_volume_slider(text: String, key: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float):
		_settings.audio[key] = value
		_update_volume_label(key, value)
		_apply_audio_settings()
		_save_settings()
	)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(value_label)
	_volume_value_labels[key] = value_label
	_sound_tab.add_child(row)
	return slider

func _update_fps_label() -> void:
	if _settings.video.max_fps <= 0:
		_fps_value_label.text = "Unlimited"
	else:
		_fps_value_label.text = str(_settings.video.max_fps)

func _apply_video_settings() -> void:
	_apply_window_mode(_settings.video.mode)
	_apply_resolution(_settings.video.resolution)
	_apply_vsync(_settings.video.vsync)
	_apply_max_fps()

func _apply_max_fps() -> void:
	Engine.max_fps = int(_settings.video.max_fps)

func _apply_window_mode(mode: String) -> void:
	if mode == "fullscreen":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif mode == "borderless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_resolution(resolution: Vector2i) -> void:
	DisplayServer.window_set_size(resolution)

func _apply_vsync(enabled: bool) -> void:
	var mode: int = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)

func _apply_audio_settings() -> void:
	_set_bus_volume("Master", _settings.audio.master)
	_set_bus_volume("Music", _settings.audio.music)
	_set_bus_volume("SFX", _settings.audio.sfx)

func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var value: float = clamp(linear_value, 0.0, 1.0)
	var db: float = linear_to_db(max(value, 0.001))
	AudioServer.set_bus_volume_db(index, db)

func _apply_all_settings() -> void:
	_apply_video_settings()
	_apply_audio_settings()
	_sync_ui_from_settings()

func _sync_ui_from_settings() -> void:
	var mode_index := 2
	for i in range(MODE_OPTIONS.size()):
		if MODE_OPTIONS[i].value == _settings.video.mode:
			mode_index = i
			break
	_mode_option.select(mode_index)
	var res_index := 0
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == _settings.video.resolution:
			res_index = i
			break
	_resolution_option.select(res_index)
	_vsync_check.button_pressed = _settings.video.vsync
	_fps_slider.value = _settings.video.max_fps
	_update_fps_label()
	_master_slider.value = _settings.audio.master
	_music_slider.value = _settings.audio.music
	_sfx_slider.value = _settings.audio.sfx
	_update_volume_label("master", _master_slider.value)
	_update_volume_label("music", _music_slider.value)
	_update_volume_label("sfx", _sfx_slider.value)
	_refresh_control_buttons()

func _ensure_default_bindings() -> void:
	for category in CONTROL_CATEGORIES:
		for action_info in category.actions:
			_ensure_action(action_info.action)
	for action_name in DEFAULT_KEYBOARD.keys():
		_ensure_action(action_name)
		if action_name == "ui_cancel":
			for existing in InputMap.action_get_events(action_name):
				if existing is InputEventKey:
					InputMap.action_erase_event(action_name, existing)
		if _get_event_count(action_name, "keyboard") == 0:
			var key_event := InputEventKey.new()
			key_event.keycode = DEFAULT_KEYBOARD[action_name]
			InputMap.action_add_event(action_name, key_event)
		if _get_event_count(action_name, "controller") == 0:
			var pad_event := InputEventJoypadButton.new()
			pad_event.button_index = DEFAULT_CONTROLLER[action_name]
			InputMap.action_add_event(action_name, pad_event)
	_add_default_wasd_bindings()

func _add_default_wasd_bindings() -> void:
	var mapping: Dictionary = {
		"ui_up": KEY_W,
		"ui_down": KEY_S,
		"ui_left": KEY_A,
		"ui_right": KEY_D
	}
	for action_name in mapping.keys():
		_ensure_action(action_name)
		var key_event := InputEventKey.new()
		key_event.keycode = mapping[action_name]
		if not InputMap.action_has_event(action_name, key_event):
			InputMap.action_add_event(action_name, key_event)

func _is_movement_action(action_name: String) -> bool:
	return action_name == "ui_up" or action_name == "ui_down" or action_name == "ui_left" or action_name == "ui_right"

func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

func _get_event_count(action_name: String, device: String) -> int:
	var count := 0
	for event in InputMap.action_get_events(action_name):
		if device == "keyboard" and event is InputEventKey:
			count += 1
		elif device == "controller" and event is InputEventJoypadButton:
			count += 1
	return count

func _start_binding(action_name: String, device: String, button: Button) -> void:
	if _binding_action != "":
		return
	_binding_action = action_name
	_binding_device = device
	_binding_button = button
	button.text = "Press key..."
	button.disabled = true

func _apply_binding(event: InputEvent) -> void:
	var new_event: InputEvent
	if event is InputEventKey:
		var key_event := InputEventKey.new()
		key_event.keycode = event.keycode
		new_event = key_event
	elif event is InputEventJoypadButton:
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = event.button_index
		new_event = pad_event
	else:
		return
	_replace_binding(_binding_action, _binding_device, new_event)
	_binding_button.disabled = false
	_binding_action = ""
	_binding_device = ""
	_binding_button = null
	_refresh_control_buttons()
	_save_settings()

func _replace_binding(action_name: String, device: String, event: InputEvent) -> void:
	_ensure_action(action_name)
	var to_remove: Array = []
	for existing in InputMap.action_get_events(action_name):
		if device == "keyboard" and existing is InputEventKey:
			to_remove.append(existing)
		elif device == "controller" and existing is InputEventJoypadButton:
			to_remove.append(existing)
	for existing in to_remove:
		InputMap.action_erase_event(action_name, existing)
	InputMap.action_add_event(action_name, event)
	if device == "keyboard" and _is_movement_action(action_name):
		_add_default_wasd_bindings()

func _refresh_control_buttons() -> void:
	for action_name in _control_buttons.keys():
		var buttons: Dictionary = _control_buttons.get(action_name, {})
		var keyboard_button: Button = buttons.get("keyboard") as Button
		var controller_button: Button = buttons.get("controller") as Button
		if keyboard_button != null:
			keyboard_button.text = _get_binding_label(action_name, "keyboard")
		if controller_button != null:
			controller_button.text = _get_binding_label(action_name, "controller")

func _get_binding_label(action_name: String, device: String) -> String:
	for event in InputMap.action_get_events(action_name):
		if device == "keyboard" and event is InputEventKey:
			return OS.get_keycode_string(event.keycode)
		if device == "controller" and event is InputEventJoypadButton:
			return _joy_button_label(event.button_index)
	return "Unassigned"

func _update_volume_label(key: String, value: float) -> void:
	var label: Label = _volume_value_labels.get(key) as Label
	if label == null:
		return
	label.text = "%d%%" % int(round(value * 100.0))

func _ensure_scroll_visible(scroll: ScrollContainer, control: Control) -> void:
	if scroll == null or control == null:
		return
	if scroll.is_ancestor_of(control):
		scroll.ensure_control_visible(control)

func _ensure_controls_focus_visible(header: Control, row: Control, button: Control) -> void:
	call_deferred("_ensure_controls_focus_visible_deferred", header, row, button)

func _ensure_controls_focus_visible_deferred(header: Control, row: Control, button: Control) -> void:
	if _controls_scroll == null:
		return
	if header != null:
		_ensure_scroll_visible(_controls_scroll, header)
	_ensure_scroll_visible(_controls_scroll, row)
	_ensure_scroll_visible(_controls_scroll, button)

func _is_action_press(event: InputEvent, action_name: String) -> bool:
	if event is InputEventKey:
		return event.pressed and event.is_action(action_name)
	if event is InputEventJoypadButton:
		return event.pressed and event.is_action(action_name)
	return false

func _get_tab_index(tab_control: Control) -> int:
	if tab_control == null:
		return -1
	for i in range(_settings_tabs.get_child_count()):
		if _settings_tabs.get_child(i) == tab_control:
			return i
	return -1

func _is_controls_tab_active() -> bool:
	return _controls_tab_index >= 0 and _settings_tabs.current_tab == _controls_tab_index

func _move_controls_focus(direction: int) -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	var list: Array[Button] = []
	if focus_owner in _controls_nav_keyboard:
		list = _controls_nav_keyboard
	elif focus_owner in _controls_nav_controller:
		list = _controls_nav_controller
	else:
		return false
	var index := list.find(focus_owner)
	if index < 0:
		return false
	var next_index := index + direction
	if next_index < 0 or next_index >= list.size():
		return false
	var target := list[next_index]
	if target == null:
		return false
	var header: Control = _controls_header_for_button.get(target, null) as Control
	var row: Control = target.get_parent() as Control
	_ensure_controls_focus_visible(header, row, target)
	target.grab_focus()
	return true

func _enter_team() -> void:
	_show_section("team")
	_in_content = true
	_menu_level = "content"
	_active_section = "team"
	_set_sidebar_focus_enabled(false)
	_set_team_buttons_focus_enabled(true)
	if not _team_buttons.is_empty():
		_team_buttons[0].grab_focus()
		_ensure_scroll_visible(_team_scroll, _team_buttons[0])

func _enter_settings() -> void:
	_settings_to_tabs()

func _leave_content() -> void:
	_in_content = false
	_menu_level = "sidebar"
	_set_sidebar_focus_enabled(true)
	if _active_section == "settings":
		_set_all_tab_content_focus_enabled(false)
		_set_tabs_focus_enabled(false)
	_set_team_buttons_focus_enabled(false)
	if _last_sidebar_focus == "settings":
		_settings_button.grab_focus()
	else:
		_team_button.grab_focus()

func _set_sidebar_focus_enabled(enabled: bool) -> void:
	for button in _sidebar_buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.focus_neighbor_right = NodePath("")
		button.focus_neighbor_left = NodePath("")

func _set_tabs_focus_enabled(enabled: bool) -> void:
	_settings_tabs.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	_set_tab_bar_focus_enabled(false)

func _set_tab_bar_focus_enabled(enabled: bool) -> void:
	var tab_bar: Control = _settings_tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _settings_to_content() -> void:
	var tab_control: Control = _settings_tabs.get_child(_settings_tabs.current_tab) as Control
	if tab_control == null:
		return
	_set_tab_content_focus_enabled(true)
	_set_tabs_focus_enabled(false)
	var focus_target := _find_first_focusable(tab_control)
	if focus_target != null:
		focus_target.grab_focus()
		_ensure_scroll_visible(_controls_scroll, focus_target)
	_menu_level = "content"
	_in_content = true

func _find_first_focusable(root: Node) -> Control:
	if root is Control:
		var ctrl := root as Control
		if ctrl.visible and ctrl.focus_mode != Control.FOCUS_NONE:
			return ctrl
	for child in root.get_children():
		var found := _find_first_focusable(child)
		if found != null:
			return found
	return null

func _lock_left_navigation(root: Node) -> void:
	if root is Control:
		var ctrl := root as Control
		ctrl.focus_neighbor_left = NodePath("")
	for child in root.get_children():
		_lock_left_navigation(child)

func _settings_to_tabs() -> void:
	_show_section("settings")
	_active_section = "settings"
	_in_content = false
	_menu_level = "tabs"
	_set_sidebar_focus_enabled(false)
	_set_tabs_focus_enabled(true)
	_settings_tabs.current_tab = _last_settings_tab
	_set_all_tab_content_focus_enabled(false)
	call_deferred("_focus_tabs")

func _focus_tabs() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner != _settings_tabs:
		focus_owner.release_focus()
	_settings_tabs.grab_focus()
	_menu_level = "tabs"
	_in_content = false

func _settings_to_sidebar() -> void:
	_in_content = false
	_menu_level = "sidebar"
	_set_tabs_focus_enabled(false)
	_set_all_tab_content_focus_enabled(false)
	_set_sidebar_focus_enabled(true)
	_settings_button.grab_focus()

func _settings_select_next_tab() -> void:
	_settings_tabs.current_tab = min(_settings_tabs.current_tab + 1, _settings_tabs.get_tab_count() - 1)
	_focus_tabs()

func _settings_select_prev_tab() -> void:
	_settings_tabs.current_tab = max(_settings_tabs.current_tab - 1, 0)
	_focus_tabs()

func _focus_sidebar_selection() -> void:
	if _last_sidebar_focus == "settings":
		_settings_button.grab_focus()
	elif _last_sidebar_focus == "end_game":
		_end_game_button.grab_focus()
	elif _last_sidebar_focus == "close":
		_close_button.grab_focus()
	else:
		_team_button.grab_focus()

func _on_settings_tab_changed(tab_index: int) -> void:
	_last_settings_tab = tab_index

func _set_tab_content_focus_enabled(enabled: bool) -> void:
	var tab_control: Control = _settings_tabs.get_child(_settings_tabs.current_tab) as Control
	if tab_control == null:
		return
	_set_focus_for_controls(tab_control, enabled)

func _set_team_buttons_focus_enabled(enabled: bool) -> void:
	for button in _team_buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func _set_all_tab_content_focus_enabled(enabled: bool) -> void:
	for i in range(_settings_tabs.get_child_count()):
		var tab_control: Control = _settings_tabs.get_child(i) as Control
		if tab_control == null:
			continue
		_set_focus_for_controls(tab_control, enabled)

func _set_focus_for_controls(root: Node, enabled: bool) -> void:
	if root is Control:
		var ctrl := root as Control
		if not enabled:
			ctrl.focus_mode = Control.FOCUS_NONE
		else:
			if ctrl is OptionButton:
				ctrl.focus_mode = Control.FOCUS_ALL
			elif ctrl is Button or ctrl is CheckBox:
				ctrl.focus_mode = Control.FOCUS_ALL
			elif ctrl is Range:
				ctrl.focus_mode = Control.FOCUS_ALL
			else:
				ctrl.focus_mode = Control.FOCUS_NONE
	for child in root.get_children():
		_set_focus_for_controls(child, enabled)

func _joy_button_label(button_index: int) -> String:
	match button_index:
		GAMEPAD_BTN_A:
			return "A"
		GAMEPAD_BTN_B:
			return "B"
		GAMEPAD_BTN_X:
			return "X"
		GAMEPAD_BTN_Y:
			return "Y"
		GAMEPAD_BTN_LB:
			return "LB"
		GAMEPAD_BTN_RB:
			return "RB"
		GAMEPAD_BTN_BACK:
			return "Back"
		GAMEPAD_BTN_START:
			return "Start"
		GAMEPAD_BTN_DPAD_UP:
			return "DPad Up"
		GAMEPAD_BTN_DPAD_DOWN:
			return "DPad Down"
		GAMEPAD_BTN_DPAD_LEFT:
			return "DPad Left"
		GAMEPAD_BTN_DPAD_RIGHT:
			return "DPad Right"
		GAMEPAD_BTN_L3:
			return "L3"
		GAMEPAD_BTN_R3:
			return "R3"
		_:
			return "Button %d" % button_index

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	_settings.video.mode = str(config.get_value("video", "mode", _settings.video.mode))
	var res_value: Variant = config.get_value("video", "resolution", _settings.video.resolution)
	if res_value is Vector2i:
		_settings.video.resolution = res_value
	_settings.video.vsync = bool(config.get_value("video", "vsync", _settings.video.vsync))
	_settings.video.max_fps = int(config.get_value("video", "max_fps", _settings.video.max_fps))
	_settings.audio.master = float(config.get_value("audio", "master", _settings.audio.master))
	_settings.audio.music = float(config.get_value("audio", "music", _settings.audio.music))
	_settings.audio.sfx = float(config.get_value("audio", "sfx", _settings.audio.sfx))

	for category in CONTROL_CATEGORIES:
		for action_info in category.actions:
			var action_name: String = action_info.action
			if config.has_section_key("controls", action_name):
				var entry: Variant = config.get_value("controls", action_name, {})
				if entry is Dictionary:
					if entry.has("keyboard"):
						var keycode = int(entry.keyboard)
						if action_name == "ui_cancel" and (keycode == KEY_ESCAPE or keycode == KEY_BACKSPACE):
							keycode = KEY_SHIFT
						if action_name == "ui_accept" and keycode == KEY_ENTER:
							keycode = KEY_SPACE
						if keycode > 0:
							var key_event := InputEventKey.new()
							key_event.keycode = keycode as Key
							_replace_binding(action_name, "keyboard", key_event)
					if entry.has("controller"):
						var button_index = int(entry.controller)
						if button_index >= 0:
							var pad_event := InputEventJoypadButton.new()
							pad_event.button_index = button_index as JoyButton
							_replace_binding(action_name, "controller", pad_event)
	_add_default_wasd_bindings()

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("video", "mode", _settings.video.mode)
	config.set_value("video", "resolution", _settings.video.resolution)
	config.set_value("video", "vsync", _settings.video.vsync)
	config.set_value("video", "max_fps", _settings.video.max_fps)
	config.set_value("audio", "master", _settings.audio.master)
	config.set_value("audio", "music", _settings.audio.music)
	config.set_value("audio", "sfx", _settings.audio.sfx)

	for category in CONTROL_CATEGORIES:
		for action_info in category.actions:
			var action_name: String = action_info.action
			var entry: Dictionary = {
				"keyboard": _get_binding_code(action_name, "keyboard"),
				"controller": _get_binding_code(action_name, "controller")
			}
			config.set_value("controls", action_name, entry)

	config.save(CONFIG_PATH)

func _get_binding_code(action_name: String, device: String) -> int:
	for event in InputMap.action_get_events(action_name):
		if device == "keyboard" and event is InputEventKey:
			return event.keycode
		if device == "controller" and event is InputEventJoypadButton:
			return event.button_index
	return -1
