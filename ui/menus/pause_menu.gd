extends CanvasLayer
class_name MTPauseMenuUI

signal closed
signal item_used_message(text: String)

const CONFIG_PATH := "user://settings.cfg"

const ItemDataClass = preload("res://core/items/item_data.gd")
const ItemMenuClass = preload("res://ui/menus/item_menu.gd")
const InputButtonsClass = preload("res://core/systems/input_buttons.gd")
const MonsterStatusViewHelper = preload("res://core/ui/monster_status_view_helper.gd")


const GAMEPAD_BTN_A := InputButtonsClass.GAMEPAD_BTN_A
const GAMEPAD_BTN_B := InputButtonsClass.GAMEPAD_BTN_B
const GAMEPAD_BTN_X := InputButtonsClass.GAMEPAD_BTN_X
const GAMEPAD_BTN_Y := InputButtonsClass.GAMEPAD_BTN_Y
const GAMEPAD_BTN_LB := InputButtonsClass.GAMEPAD_BTN_LB
const GAMEPAD_BTN_RB := InputButtonsClass.GAMEPAD_BTN_RB
const GAMEPAD_BTN_BACK := InputButtonsClass.GAMEPAD_BTN_BACK
const GAMEPAD_BTN_START := InputButtonsClass.GAMEPAD_BTN_START
const GAMEPAD_BTN_L3 := InputButtonsClass.GAMEPAD_BTN_L3
const GAMEPAD_BTN_R3 := InputButtonsClass.GAMEPAD_BTN_R3
const GAMEPAD_BTN_DPAD_UP := InputButtonsClass.GAMEPAD_BTN_DPAD_UP
const GAMEPAD_BTN_DPAD_DOWN := InputButtonsClass.GAMEPAD_BTN_DPAD_DOWN
const GAMEPAD_BTN_DPAD_LEFT := InputButtonsClass.GAMEPAD_BTN_DPAD_LEFT
const GAMEPAD_BTN_DPAD_RIGHT := InputButtonsClass.GAMEPAD_BTN_DPAD_RIGHT

const MODE_OPTIONS: Array = [
	{"label_key": "Fullscreen", "value": "fullscreen"},
	{"label_key": "Borderless", "value": "borderless"},
	{"label_key": "Windowed", "value": "windowed"}
]

const RESOLUTIONS: Array = [
	Vector2i(640, 480),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

const LANGUAGE_OPTIONS: Array = [
	{"label_key": "English", "value": "en"},
	{"label_key": "Deutsch", "value": "de"}
]
const FALLBACK_LOCALE := "en"

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
	"pause_menu": KEY_ESCAPE
}

const DEFAULT_CONTROLLER: Dictionary = {
	"ui_up": GAMEPAD_BTN_DPAD_UP,
	"ui_down": GAMEPAD_BTN_DPAD_DOWN,
	"ui_left": GAMEPAD_BTN_DPAD_LEFT,
	"ui_right": GAMEPAD_BTN_DPAD_RIGHT,
	"ui_accept": GAMEPAD_BTN_A,
	"ui_cancel": GAMEPAD_BTN_B,
	"run": GAMEPAD_BTN_B,
	"pause_menu": GAMEPAD_BTN_START
}

const MOVEMENT_WASD_KEYS: Dictionary = {
	"ui_up": KEY_W,
	"ui_down": KEY_S,
	"ui_left": KEY_A,
	"ui_right": KEY_D
}

const MOVEMENT_ARROW_KEYS: Dictionary = {
	"ui_up": KEY_UP,
	"ui_down": KEY_DOWN,
	"ui_left": KEY_LEFT,
	"ui_right": KEY_RIGHT
}

@onready var _team_panel: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/TeamPanel as Control
@onready var _settings_panel: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/SettingsPanel as Control
@onready var _inventory_panel: Control = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/InventoryPanel as Control
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
@onready var _inventory_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonInventory as Button
@onready var _close_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonClose as Button
@onready var _end_game_button: Button = $Root/Window/WindowVBox/ContentRow/Sidebar/ButtonEndGame as Button
@onready var _item_menu: ItemMenuClass = $Root/Window/WindowVBox/ContentRow/ContentPanel/ContentStack/InventoryPanel/ItemMenu as ItemMenuClass

var _mode_option: OptionButton
var _language_option: OptionButton
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
var _last_team: Array = []
var _overlay_message_active := false
var _inputmap_defaults: Dictionary = {}
var _last_item_tab: int = 0
var _team_sub_level: String = "list"  # "list" | "options" | "switch" | "status"
var _team_selected_index: int = -1
var _team_status_tab: int = 0
var _team_sub_nav: Array[Button] = []
var _settings_control_active := false
var _settings_nav_controls: Array[Control] = []
var _settings_nav_focus_index := 0
var _controls_reset_button: Button

const ACTION_ALIASES: Dictionary = {
	"ui_up": "up",
	"ui_down": "down",
	"ui_left": "left",
	"ui_right": "right",
	"ui_accept": "accept",
	"ui_cancel": "back"
}
var _reset_confirm: ConfirmationDialog

var _settings: Dictionary = {
	"general": {
		"language": "en"
	},
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
	_inventory_button.pressed.connect(_on_inventory_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_end_game_button.pressed.connect(_on_end_game_pressed)
	_team_button.focus_entered.connect(func(): _on_sidebar_focus("team"))
	_settings_button.focus_entered.connect(func(): _on_sidebar_focus("settings"))
	_inventory_button.focus_entered.connect(func(): _on_sidebar_focus("inventory"))
	_close_button.focus_entered.connect(func(): _on_sidebar_focus("close"))
	_end_game_button.focus_entered.connect(func(): _on_sidebar_focus("end_game"))
	_sidebar_buttons = [_team_button, _inventory_button, _settings_button, _close_button, _end_game_button]
	_item_menu.item_used.connect(_on_item_used)
	_item_menu.tab_changed.connect(func(index: int): _last_item_tab = index)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_ensure_reset_dialog()
	_build_video_tab()
	_build_sound_tab()
	_build_controls_tab()
	_capture_inputmap_defaults()
	_load_settings()
	_ensure_actions_from_defaults()
	_enforce_preferred_global_bindings()
	_apply_all_settings()
	_show_section("team")

func _exit_tree() -> void:
	# Cleanup signal connections to prevent memory leaks
	if is_node_ready():
		if _settings_tabs.tab_changed.is_connected(_on_settings_tab_changed):
			_settings_tabs.tab_changed.disconnect(_on_settings_tab_changed)
		if _team_button.pressed.is_connected(_on_team_pressed):
			_team_button.pressed.disconnect(_on_team_pressed)
		if _settings_button.pressed.is_connected(_on_settings_pressed):
			_settings_button.pressed.disconnect(_on_settings_pressed)
		if _inventory_button.pressed.is_connected(_on_inventory_pressed):
			_inventory_button.pressed.disconnect(_on_inventory_pressed)
		if _close_button.pressed.is_connected(_on_close_pressed):
			_close_button.pressed.disconnect(_on_close_pressed)
		if _end_game_button.pressed.is_connected(_on_end_game_pressed):
			_end_game_button.pressed.disconnect(_on_end_game_pressed)
		if _item_menu.item_used.is_connected(_on_item_used):
			_item_menu.item_used.disconnect(_on_item_used)
		if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
			Input.joy_connection_changed.disconnect(_on_joy_connection_changed)

func _enter_inventory() -> void:
	_show_section("inventory")
	_active_section = "inventory"
	_in_content = false
	_menu_level = "content"
	_item_menu.select_tab(_last_item_tab)
	_item_menu.open_inventory(_last_team, false, false)
	_item_menu.set_allow_enter_from_tabs(false)
	_item_menu.set_tabs_focus_enabled(false)
	_item_menu.set_auto_focus_content(false)
	_set_sidebar_focus_enabled(false)
	_set_inventory_focus_enabled(false)
	_inventory_to_content()

func _inventory_to_content() -> void:
	_item_menu.set_tabs_focus_enabled(false)
	_set_inventory_focus_enabled(true)
	_item_menu.set_auto_focus_content(true)
	_item_menu.set_allow_enter_from_tabs(true)
	_item_menu.refresh()
	_item_menu.lock_item_lateral_navigation()
	_item_menu.grab_first_focus()
	_menu_level = "content"
	_in_content = true

func _inventory_to_sidebar() -> void:
	_in_content = false
	_menu_level = "sidebar"
	_item_menu.set_tabs_focus_enabled(false)
	_set_inventory_focus_enabled(false)
	_item_menu.set_allow_enter_from_tabs(false)
	_set_sidebar_focus_enabled(true)
	_inventory_button.grab_focus()

func _set_inventory_focus_enabled(enabled: bool) -> void:
	_item_menu.set_focus_enabled(enabled)

func _on_item_used(item: ItemDataClass, target: MTMonsterInstance) -> void:
	if item == null or target == null:
		return
	_apply_item_overworld(item, target)
	_item_menu.refresh()

func _apply_item_overworld(item: ItemDataClass, target: MTMonsterInstance) -> void:
	if item.heal_max > 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var amount := rng.randi_range(item.heal_min, item.heal_max)
		var before := target.hp
		target.hp = min(target.hp + amount, target.get_max_hp())
		var healed := target.hp - before
		if healed > 0:
			var game = _get_game()
			if game != null:
				game.remove_item(item.id, 1)
			item_used_message.emit(tr("Used %s on %s, healed %d HP.") % [TranslationServer.translate(item.name), _monster_name(target), healed])
		else:
			item_used_message.emit(tr("Couldn't use!"))
	else:
		item_used_message.emit(tr("Couldn't use!"))

func _get_game():
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Game")

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return tr("Unknown")
	return monster.data.name

func open(team: Array) -> void:
	visible = true
	_reset_menu_state_for_open_close()
	_last_team = team
	_update_team_list(team)
	_show_section("team")
	_team_button.grab_focus()

func close() -> void:
	_reset_menu_state_for_open_close()
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	visible = false
	emit_signal("closed")

func _reset_menu_state_for_open_close() -> void:
	_in_content = false
	_menu_level = "sidebar"
	_active_section = "team"
	_last_sidebar_focus = "team"
	_settings_control_active = false
	_settings_nav_controls.clear()
	_settings_nav_focus_index = 0
	_set_sidebar_focus_enabled(true)
	_set_tabs_focus_enabled(false)
	_set_all_tab_content_focus_enabled(false)
	_set_team_buttons_focus_enabled(false)
	_team_sub_level = "list"
	_team_selected_index = -1
	_team_sub_nav.clear()
	_set_inventory_focus_enabled(false)
	_item_menu.set_tabs_focus_enabled(false)
	_item_menu.set_allow_enter_from_tabs(false)
	_item_menu.set_auto_focus_content(false)

func _apply_localized_static_texts() -> void:
	_team_button.text = tr("Team")
	_inventory_button.text = tr("Inventory")
	_settings_button.text = tr("Settings")
	_close_button.text = tr("Close")
	_end_game_button.text = tr("End Game")

func _clear_children(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

func _rebuild_localized_ui() -> void:
	_settings_control_active = false
	_settings_nav_controls.clear()
	_settings_nav_focus_index = 0
	_apply_localized_static_texts()
	_clear_children(_video_tab)
	_build_video_tab()
	_clear_children(_sound_tab)
	_build_sound_tab()
	_clear_children(_controls_list)
	_build_controls_tab()
	_sync_ui_from_settings()
	_update_team_list(_last_team)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _overlay_message_active:
		return
	if event.is_action_pressed("pause_menu"):
		close()
		get_viewport().set_input_as_handled()
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if _menu_level == "sidebar" and focus_owner != _team_button and focus_owner != _inventory_button and focus_owner != _settings_button and focus_owner != _close_button and focus_owner != _end_game_button:
		_focus_sidebar_selection()
		get_viewport().set_input_as_handled()
		return
	if focus_owner == _team_button or focus_owner == _inventory_button or focus_owner == _settings_button or focus_owner == _close_button or focus_owner == _end_game_button:
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
	var settings_direct_result := _handle_settings_direct_controls_input(event)
	if settings_direct_result == "handled":
		get_viewport().set_input_as_handled()
		return
	if settings_direct_result == "stop":
		return
	# --- Settings content: Controls tab (existing behaviour) ---
	if _menu_level == "content" and _active_section == "settings" and _is_controls_tab_active():
		if event.is_action_pressed("ui_cancel"):
			if _settings_control_active:
				_deactivate_settings_control()
			else:
				_settings_to_sidebar()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left"):
			var controls_focus_owner := get_viewport().gui_get_focus_owner() as Control
			if _move_controls_horizontal_focus(-1):
				get_viewport().set_input_as_handled()
				return
			if controls_focus_owner != null and controls_focus_owner == _controls_reset_button:
				_settings_tabs.current_tab = max(_settings_tabs.current_tab - 1, 0)
				_settings_to_content()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			var controls_focus_owner := get_viewport().gui_get_focus_owner() as Control
			if _move_controls_horizontal_focus(1):
				get_viewport().set_input_as_handled()
				return
			if controls_focus_owner != null and controls_focus_owner == _controls_reset_button:
				_settings_tabs.current_tab = min(_settings_tabs.current_tab + 1, _settings_tabs.get_tab_count() - 1)
				_settings_to_content()
			get_viewport().set_input_as_handled()
			return
		if _is_action_press(event, "ui_up"):
			if _move_controls_focus(-1):
				get_viewport().set_input_as_handled()
				return
		if _is_action_press(event, "ui_down"):
			if _move_controls_focus(1):
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_up") and _is_first_settings_focus():
			get_viewport().set_input_as_handled()
			return
	# --- Inventory content: Left/Right completely blocked ---
	if _menu_level == "content" and _active_section == "inventory":
		if event.is_action_pressed("ui_cancel"):
			_inventory_to_sidebar()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up") and _item_menu.is_first_item_focused():
			get_viewport().set_input_as_handled()
			return
	# --- Team content sub-views ---
	if _menu_level == "content" and _active_section == "team":
		if event.is_action_pressed("ui_cancel"):
			_team_go_back()
			get_viewport().set_input_as_handled()
			return
		if _team_sub_level != "list":
			if event.is_action_pressed("ui_up"):
				_team_sub_nav_move(-1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_down"):
				_team_sub_nav_move(1)
				get_viewport().set_input_as_handled()
				return
		if _team_sub_level == "list":
			if event.is_action_pressed("ui_up"):
				_team_list_move_focus(-1)
				get_viewport().set_input_as_handled()
				return
			if event.is_action_pressed("ui_down"):
				_team_list_move_focus(1)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel"):
		if _menu_level == "content" and _active_section == "settings":
			_settings_to_sidebar()
		elif _menu_level == "tabs" and _active_section == "settings":
			_settings_to_sidebar()
		elif _menu_level == "content" and _active_section == "inventory":
			_inventory_to_sidebar()
		elif _in_content:
			_leave_content()
		else:
			close()
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
			if focus_owner == _inventory_button:
				_enter_inventory()
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
		if event.is_action_pressed("ui_left"):
			_settings_select_prev_tab()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_right"):
			_settings_select_next_tab()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_up"):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_down"):
			_settings_to_content()
			get_viewport().set_input_as_handled()
			return
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _overlay_message_active:
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
		# While rebinding, swallow all other inputs to prevent menu navigation.
		if (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed):
			get_viewport().set_input_as_handled()
		return

	if _menu_level == "content" and _active_section == "settings" and _is_controls_tab_active():
		var focus_owner := get_viewport().gui_get_focus_owner() as Control
		if event.is_action_pressed("ui_left"):
			if _move_controls_horizontal_focus(-1):
				get_viewport().set_input_as_handled()
				return
			if focus_owner != null and (focus_owner == _controls_reset_button or focus_owner in _controls_nav_keyboard or focus_owner in _controls_nav_controller):
				_settings_tabs.current_tab = max(_settings_tabs.current_tab - 1, 0)
				_settings_to_content()
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ui_right"):
			if _move_controls_horizontal_focus(1):
				get_viewport().set_input_as_handled()
				return
			if focus_owner != null and (focus_owner == _controls_reset_button or focus_owner in _controls_nav_keyboard or focus_owner in _controls_nav_controller):
				_settings_tabs.current_tab = min(_settings_tabs.current_tab + 1, _settings_tabs.get_tab_count() - 1)
				_settings_to_content()
				get_viewport().set_input_as_handled()
				return

	var settings_direct_result := _handle_settings_direct_controls_input(event)
	if settings_direct_result == "handled":
		get_viewport().set_input_as_handled()
		return
	if settings_direct_result == "stop":
		return

func _handle_settings_direct_controls_input(event: InputEvent) -> String:
	if not (_menu_level == "content" and _active_section == "settings" and not _is_controls_tab_active()):
		return "continue"
	if _settings_control_active:
		if event.is_action_pressed("ui_cancel"):
			_deactivate_settings_control()
			return "handled"
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			return "handled"
		return "stop"
	if event.is_action_pressed("ui_cancel"):
		_settings_to_sidebar()
		return "handled"
	if event.is_action_pressed("ui_accept"):
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is Range:
			_activate_settings_control()
			return "handled"
		# Let non-slider controls (OptionButton, CheckBox) consume accept normally.
		return "stop"
	if event.is_action_pressed("ui_up"):
		if _settings_nav_focus_index > 0:
			_move_settings_nav_focus(-1)
		return "handled"
	if event.is_action_pressed("ui_down"):
		_move_settings_nav_focus(1)
		return "handled"
	if event.is_action_pressed("ui_left"):
		_settings_tabs.current_tab = max(_settings_tabs.current_tab - 1, 0)
		_settings_to_content()
		return "handled"
	if event.is_action_pressed("ui_right"):
		_settings_tabs.current_tab = min(_settings_tabs.current_tab + 1, _settings_tabs.get_tab_count() - 1)
		_settings_to_content()
		return "handled"
	return "stop"

func _on_team_pressed() -> void:
	_enter_team()

func _on_settings_pressed() -> void:
	_enter_settings()

func _on_inventory_pressed() -> void:
	_enter_inventory()

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
	_set_inventory_focus_enabled(false)
	if section == "team":
		_show_section("team")
		_active_section = "team"
	elif section == "inventory":
		_show_section("inventory")
		_active_section = "inventory"
		_item_menu.select_tab(_last_item_tab)
		_item_menu.open_inventory(_last_team, false, false)
		_item_menu.set_focus_enabled(false)
		_item_menu.set_allow_enter_from_tabs(false)
	elif section == "settings":
		_show_section("settings")
		_active_section = "settings"
	elif section == "end_game":
		pass

func _show_section(section: String) -> void:
	_team_panel.visible = section == "team"
	_settings_panel.visible = section == "settings"
	_inventory_panel.visible = section == "inventory"

func _update_team_list(team: Array) -> void:
	_team_buttons.clear()
	for child in _team_list.get_children():
		child.queue_free()
	if team == null or team.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("No team members.")
		_team_list.add_child(empty_label)
		return
	for i in range(team.size()):
		var member: MTMonsterInstance = team[i] as MTMonsterInstance
		if member == null:
			continue
		var entry_button := Button.new()
		entry_button.focus_mode = Control.FOCUS_NONE
		entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_button.text = tr("%s | Lv. %d | HP %d/%d | EN %d/%d\nSTR %d | MAG %d | DEF %d | RES %d | SPD %d") % [
			_monster_name(member),
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
		var captured_i := i
		entry_button.pressed.connect(func():
			_team_open_monster_options(captured_i)
		)
		_team_list.add_child(entry_button)
		_team_buttons.append(entry_button)

func _build_video_tab() -> void:
	_video_tab.add_theme_constant_override("separation", 8)
	_language_option = OptionButton.new()
	_language_option.focus_mode = Control.FOCUS_NONE
	for item in LANGUAGE_OPTIONS:
		_language_option.add_item(tr(str(item["label_key"])))
	_language_option.item_selected.connect(func(index: int):
		_settings.general.language = str(LANGUAGE_OPTIONS[index]["value"])
		_apply_language()
		_save_settings()
		_rebuild_localized_ui()
	)
	_video_tab.add_child(_create_labeled_row(tr("Language"), _language_option))

	_mode_option = OptionButton.new()
	_mode_option.focus_mode = Control.FOCUS_NONE
	for item in MODE_OPTIONS:
		_mode_option.add_item(tr(str(item["label_key"])))
	_mode_option.item_selected.connect(func(index: int):
		var value: String = str(MODE_OPTIONS[index].value)
		_settings.video.mode = value
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_create_labeled_row(tr("Window Mode"), _mode_option))

	_resolution_option = OptionButton.new()
	_resolution_option.focus_mode = Control.FOCUS_NONE
	for res in RESOLUTIONS:
		_resolution_option.add_item("%dx%d" % [res.x, res.y])
	_resolution_option.item_selected.connect(func(index: int):
		_settings.video.resolution = RESOLUTIONS[index]
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_create_labeled_row(tr("Resolution"), _resolution_option))

	_vsync_check = CheckBox.new()
	_vsync_check.focus_mode = Control.FOCUS_NONE
	_vsync_check.text = tr("VSync")
	_vsync_check.toggled.connect(func(pressed: bool):
		_settings.video.vsync = pressed
		_apply_video_settings()
		_save_settings()
	)
	_video_tab.add_child(_create_labeled_row(tr("VSync"), _vsync_check))

	_fps_slider = HSlider.new()
	_fps_slider.focus_mode = Control.FOCUS_NONE
	_fps_slider.min_value = 0
	_fps_slider.max_value = 240
	_fps_slider.step = 1
	_fps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fps_slider.value_changed.connect(func(value: float):
		_settings.video.max_fps = int(value)
		_update_fps_label()
		_apply_max_fps()
		_save_settings()
	)
	_fps_value_label = Label.new()
	_fps_value_label.text = tr("0")
	_fps_value_label.custom_minimum_size = Vector2(50, 0)
	var fps_extra_row := HBoxContainer.new()
	fps_extra_row.add_theme_constant_override("separation", 4)
	fps_extra_row.add_child(_fps_slider)
	fps_extra_row.add_child(_fps_value_label)
	_video_tab.add_child(_create_labeled_row(tr("Max FPS"), fps_extra_row))

func _build_sound_tab() -> void:
	_sound_tab.add_theme_constant_override("separation", 8)
	_master_slider = _create_volume_slider(tr("Master Volume"), "master")
	_music_slider = _create_volume_slider(tr("Music Volume"), "music")
	_sfx_slider = _create_volume_slider(tr("SFX Volume"), "sfx")

func _build_controls_tab() -> void:
	_controls_list.add_theme_constant_override("separation", 8)
	_ensure_default_bindings()
	_control_buttons.clear()
	_controls_nav_keyboard.clear()
	_controls_nav_controller.clear()
	_controls_header_for_button.clear()
	_controls_reset_button = null
	_controls_list.add_child(_create_reset_controls_row())
	for category in CONTROL_CATEGORIES:
		var header := Label.new()
		header.text = tr(str(category.name))
		header.add_theme_font_size_override("font_size", 14)
		_controls_list.add_child(header)
		var first_in_category := true

		var column_row := HBoxContainer.new()
		column_row.add_theme_constant_override("separation", 8)
		var col_action := Label.new()
		col_action.text = tr("Action")
		col_action.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_action)
		var col_keyboard := Label.new()
		col_keyboard.text = tr("Keyboard")
		col_keyboard.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_keyboard)
		var col_controller := Label.new()
		col_controller.text = tr("Controller")
		col_controller.custom_minimum_size = Vector2(160, 0)
		column_row.add_child(col_controller)
		_controls_list.add_child(column_row)

		for action_info in category.actions:
			var action_name: String = action_info.action
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var action_label := Label.new()
			action_label.text = tr(str(action_info.label))
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

func _create_reset_controls_row() -> HBoxContainer:
	_ensure_reset_dialog()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = tr("Controls")
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var button := Button.new()
	button.text = tr("Reset Controls")
	button.pressed.connect(func():
		if _reset_confirm != null:
			_reset_confirm.popup_centered()
	)
	row.add_child(button)
	_controls_reset_button = button
	_controls_nav_keyboard.append(button)
	_controls_nav_controller.append(button)
	return row

func _ensure_reset_dialog() -> void:
	if _reset_confirm != null:
		return
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.title = tr("Reset Controls")
	_reset_confirm.dialog_text = tr("Reset all controls to defaults?")
	_reset_confirm.ok_button_text = tr("Yes")
	_reset_confirm.cancel_button_text = tr("No")
	_reset_confirm.confirmed.connect(func():
		_reset_controls_to_defaults()
	)
	add_child(_reset_confirm)

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

func _activate_settings_control() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	# Only sliders need a locked control mode for left/right adjustment.
	_settings_control_active = focus_owner is Range

func _deactivate_settings_control() -> void:
	if not _settings_control_active:
		return
	_settings_control_active = false
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		var idx := _settings_nav_controls.find(focus_owner)
		if idx >= 0:
			_settings_nav_focus_index = idx

func _move_settings_nav_focus(direction: int) -> bool:
	_prune_settings_nav_controls()
	if _settings_nav_controls.is_empty():
		return false
	var new_index := _settings_nav_focus_index + direction
	if new_index < 0 or new_index >= _settings_nav_controls.size():
		return false
	_settings_nav_focus_index = new_index
	var target := _settings_nav_controls[_settings_nav_focus_index]
	if target == null or not is_instance_valid(target):
		_prune_settings_nav_controls()
		if _settings_nav_controls.is_empty():
			return false
		_settings_nav_focus_index = clamp(_settings_nav_focus_index, 0, _settings_nav_controls.size() - 1)
		target = _settings_nav_controls[_settings_nav_focus_index]
	target.grab_focus()
	_ensure_scroll_visible(_controls_scroll, target)
	return true

func _prune_settings_nav_controls() -> void:
	var valid_controls: Array[Control] = []
	for ctrl in _settings_nav_controls:
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		valid_controls.append(ctrl)
	_settings_nav_controls = valid_controls
	if _settings_nav_controls.is_empty():
		_settings_nav_focus_index = 0
	else:
		_settings_nav_focus_index = clamp(_settings_nav_focus_index, 0, _settings_nav_controls.size() - 1)

func _prune_controls_nav_buttons() -> void:
	var valid_keyboard: Array[Button] = []
	for button in _controls_nav_keyboard:
		if button == null or not is_instance_valid(button):
			continue
		valid_keyboard.append(button)
	_controls_nav_keyboard = valid_keyboard

	var valid_controller: Array[Button] = []
	for button in _controls_nav_controller:
		if button == null or not is_instance_valid(button):
			continue
		valid_controller.append(button)
	_controls_nav_controller = valid_controller

	var valid_headers: Dictionary = {}
	for key in _controls_header_for_button.keys():
		var button: Button = key as Button
		if button == null or not is_instance_valid(button):
			continue
		var header: Control = _controls_header_for_button.get(key, null) as Control
		if header != null and not is_instance_valid(header):
			header = null
		valid_headers[button] = header
	_controls_header_for_button = valid_headers

func _prune_team_sub_nav() -> void:
	var valid_buttons: Array[Button] = []
	for button in _team_sub_nav:
		if button == null or not is_instance_valid(button):
			continue
		valid_buttons.append(button)
	_team_sub_nav = valid_buttons

func _create_volume_slider(text: String, key: String) -> HSlider:
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
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
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(50, 0)
	_volume_value_labels[key] = value_label

	var extra_row := HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 4)
	extra_row.add_child(slider)
	extra_row.add_child(value_label)
	_sound_tab.add_child(_create_labeled_row(text, extra_row))
	return slider

func _update_fps_label() -> void:
	if _settings.video.max_fps <= 0:
		_fps_value_label.text = tr("Unlimited")
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
	_apply_language()
	_apply_video_settings()
	_apply_audio_settings()
	_apply_localized_static_texts()
	_sync_ui_from_settings()

func _sync_ui_from_settings() -> void:
	if _language_option != null:
		var language_index := 0
		for i in range(LANGUAGE_OPTIONS.size()):
			if str(LANGUAGE_OPTIONS[i]["value"]) == str(_settings.general.language):
				language_index = i
				break
		_language_option.select(language_index)

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

func _apply_language() -> void:
	var requested_locale := str(_settings.general.language)
	var resolved_locale := _resolve_supported_locale(requested_locale)
	_settings.general.language = resolved_locale
	TranslationServer.set_locale(resolved_locale)

func _resolve_supported_locale(requested_locale: String) -> String:
	var requested := requested_locale.strip_edges().to_lower()
	if requested == "":
		return FALLBACK_LOCALE
	for option in LANGUAGE_OPTIONS:
		var value := str(option["value"]).to_lower()
		if requested == value:
			return value
	# Support locale variants like de_AT or en-US by matching base language.
	for option in LANGUAGE_OPTIONS:
		var value := str(option["value"]).to_lower()
		if requested.begins_with(value + "_") or requested.begins_with(value + "-"):
			return value
	return FALLBACK_LOCALE

func _ensure_default_bindings() -> void:
	for category in CONTROL_CATEGORIES:
		for action_info in category.actions:
			_ensure_action(action_info.action)
	for action_name in DEFAULT_KEYBOARD.keys():
		_ensure_action(action_name)

func _capture_inputmap_defaults() -> void:
	_inputmap_defaults.clear()
	var actions := _get_control_actions()
	for action_name in actions:
		var source_action: String = action_name
		if not InputMap.has_action(source_action) and ACTION_ALIASES.has(action_name):
			source_action = ACTION_ALIASES[action_name]
		if not InputMap.has_action(source_action):
			continue
		var events: Array = []
		for event in InputMap.action_get_events(source_action):
			if event != null:
				events.append(event.duplicate())
		_inputmap_defaults[action_name] = events

func _ensure_actions_from_defaults() -> void:
	for action_name in _inputmap_defaults.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for event in _inputmap_defaults[action_name]:
			InputMap.action_add_event(action_name, event)
		_apply_alias_fallback_events(action_name)

func _enforce_preferred_global_bindings() -> void:
	# Ensure these are always single-key keyboard bindings at runtime/startup.
	_apply_preferred_default_overrides("ui_accept")
	_apply_preferred_default_overrides("ui_cancel")

func _reset_controls_to_defaults() -> void:
	for action_name in _inputmap_defaults.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for event in InputMap.action_get_events(action_name):
			InputMap.action_erase_event(action_name, event)
		for event in _inputmap_defaults[action_name]:
			InputMap.action_add_event(action_name, event.duplicate())
		_apply_alias_fallback_events(action_name)
		_apply_preferred_default_overrides(action_name)
	_refresh_control_buttons()
	_save_settings()

func _apply_alias_fallback_events(action_name: String) -> void:
	if not ACTION_ALIASES.has(action_name):
		return
	var alias_action: String = ACTION_ALIASES[action_name]
	if not InputMap.has_action(alias_action):
		return
	var has_keyboard := false
	var has_controller := false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			has_keyboard = true
		elif event is InputEventJoypadButton:
			has_controller = true
	if not has_keyboard:
		for event in InputMap.action_get_events(alias_action):
			if event is InputEventKey:
				InputMap.action_add_event(action_name, event.duplicate())
	if not has_controller:
		for event in InputMap.action_get_events(alias_action):
			if event is InputEventJoypadButton:
				InputMap.action_add_event(action_name, event.duplicate())

func _apply_preferred_default_overrides(action_name: String) -> void:
	if action_name == "ui_accept":
		var to_remove: Array = []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				to_remove.append(event)
		for event in to_remove:
			InputMap.action_erase_event(action_name, event)
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_SPACE
		InputMap.action_add_event(action_name, key_event)
		return
	if action_name == "ui_cancel":
		var to_remove_cancel: Array = []
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				to_remove_cancel.append(event)
		for event in to_remove_cancel:
			InputMap.action_erase_event(action_name, event)
		var cancel_key_event := InputEventKey.new()
		cancel_key_event.keycode = KEY_SHIFT
		InputMap.action_add_event(action_name, cancel_key_event)
		return
	if _is_movement_action(action_name):
		_set_movement_default_bindings(action_name)
		return

func _set_movement_default_bindings(action_name: String) -> void:
	var wasd_key := int(MOVEMENT_WASD_KEYS.get(action_name, -1))
	var arrow_key := int(MOVEMENT_ARROW_KEYS.get(action_name, -1))
	if wasd_key <= 0 and arrow_key <= 0:
		return
	# Reset keyboard events for movement action, then restore both defaults.
	var to_remove: Array = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			to_remove.append(event)
	for event in to_remove:
		InputMap.action_erase_event(action_name, event)
	if wasd_key > 0:
		_add_keyboard_binding_if_missing(action_name, wasd_key)
	if arrow_key > 0:
		_add_keyboard_binding_if_missing(action_name, arrow_key)

func _get_control_actions() -> Array:
	var actions: Array = []
	for category in CONTROL_CATEGORIES:
		for action_info in category.actions:
			var action_name: String = action_info.action
			if not actions.has(action_name):
				actions.append(action_name)
	for action_name in DEFAULT_KEYBOARD.keys():
		if not actions.has(action_name):
			actions.append(action_name)
	return actions


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
	button.text = tr("Press key...")
	button.disabled = true

func _apply_binding(event: InputEvent) -> void:
	var new_event: InputEvent
	if event is InputEventKey:
		if _binding_device == "keyboard" and _is_movement_action(_binding_action):
			var pressed_key := _get_keycode_for_event(event)
			if _is_arrow_keycode(pressed_key):
				# Arrow keys stay fixed as secondary movement input and cannot be rebound as primary.
				return
		var key_event := InputEventKey.new()
		key_event.keycode = event.keycode
		new_event = key_event
	elif event is InputEventJoypadButton:
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = event.button_index
		pad_event.device = -1
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

func _is_arrow_keycode(keycode: int) -> bool:
	return keycode == KEY_UP or keycode == KEY_DOWN or keycode == KEY_LEFT or keycode == KEY_RIGHT

func _replace_binding(action_name: String, device: String, event: InputEvent) -> void:
	_ensure_action(action_name)
	if device == "controller" and event is InputEventJoypadButton:
		(event as InputEventJoypadButton).device = -1
	var to_remove: Array = []
	for existing in InputMap.action_get_events(action_name):
		if device == "keyboard" and existing is InputEventKey:
			to_remove.append(existing)
		elif device == "controller" and existing is InputEventJoypadButton:
			to_remove.append(existing)
	for existing in to_remove:
		InputMap.action_erase_event(action_name, existing)
	InputMap.action_add_event(action_name, event)
	if device == "keyboard" and event is InputEventKey and _is_movement_action(action_name):
		var selected_key := _get_keycode_for_event(event)
		var companion_key := _get_movement_companion_key(action_name, selected_key)
		if companion_key > 0 and companion_key != selected_key:
			_add_keyboard_binding_if_missing(action_name, companion_key)

func _get_movement_companion_key(action_name: String, selected_key: int) -> int:
	if not _is_movement_action(action_name):
		return -1
	var wasd_key := int(MOVEMENT_WASD_KEYS.get(action_name, -1))
	var arrow_key := int(MOVEMENT_ARROW_KEYS.get(action_name, -1))
	if selected_key == wasd_key:
		return arrow_key
	if selected_key == arrow_key:
		return wasd_key
	# Keep arrow fallback for custom movement keys.
	return arrow_key

func _add_keyboard_binding_if_missing(action_name: String, keycode: int) -> void:
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and _get_keycode_for_event(existing) == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.keycode = keycode as Key
	InputMap.action_add_event(action_name, key_event)

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
	if device == "keyboard":
		var labels := _get_keyboard_labels_in_display_order(action_name)
		if not labels.is_empty():
			return " / ".join(labels)
		return "Unassigned"
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			return _joy_button_label(event.button_index)
	return "Unassigned"

func _get_keyboard_labels_in_display_order(action_name: String) -> Array[String]:
	var labels: Array[String] = []
	if _is_movement_action(action_name):
		var arrow_key := int(MOVEMENT_ARROW_KEYS.get(action_name, -1))
		# Primary/custom movement key first, fixed arrow key always secondary.
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				var code := _get_keycode_for_event(event)
				if code == arrow_key:
					continue
				var label := OS.get_keycode_string(code)
				if not labels.has(label):
					labels.append(label)
		if _action_has_keyboard_key(action_name, arrow_key):
			var arrow_label := OS.get_keycode_string(arrow_key)
			if not labels.has(arrow_label):
				labels.append(arrow_label)
		return labels
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var code := _get_keycode_for_event(event)
			var label := OS.get_keycode_string(code)
			if not labels.has(label):
				labels.append(label)
	return labels

func _action_has_keyboard_key(action_name: String, keycode: int) -> bool:
	if keycode <= 0:
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and _get_keycode_for_event(event) == keycode:
			return true
	return false

func _get_keycode_for_event(event: InputEventKey) -> int:
	if event.keycode > 0:
		return event.keycode
	return event.physical_keycode

func _update_volume_label(key: String, value: float) -> void:
	var label: Label = _volume_value_labels.get(key) as Label
	if label == null:
		return
	label.text = "%d%%" % int(round(value * 100.0))

func _ensure_scroll_visible(scroll: ScrollContainer, control: Control) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if control == null or not is_instance_valid(control):
		return
	if scroll.is_ancestor_of(control):
		scroll.ensure_control_visible(control)

func _ensure_controls_focus_visible(header: Control, row: Control, button: Control) -> void:
	call_deferred("_ensure_controls_focus_visible_deferred", header, row, button)

func _ensure_controls_focus_visible_deferred(header: Control, row: Control, button: Control) -> void:
	if _controls_scroll == null:
		return
	if header != null and is_instance_valid(header):
		_ensure_scroll_visible(_controls_scroll, header)
	if row != null and not is_instance_valid(row):
		row = null
	if button != null and not is_instance_valid(button):
		button = null
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

func _is_first_settings_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	# Proxy-nav mode (Video/Sound tabs)
	_prune_settings_nav_controls()
	if not _settings_nav_controls.is_empty():
		return focus_owner == _settings_nav_controls[0] and _settings_nav_focus_index == 0
	# Controls tab: check against first focusable child
	var tab_control: Control = _settings_tabs.get_child(_settings_tabs.current_tab) as Control
	if tab_control == null:
		return false
	var first_focus := _find_first_focusable(tab_control)
	if first_focus == null:
		return false
	return focus_owner == first_focus

func _move_controls_focus(direction: int) -> bool:
	_prune_controls_nav_buttons()
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
	if target == null or not is_instance_valid(target):
		return false
	var header: Control = _controls_header_for_button.get(target, null) as Control
	var row: Control = target.get_parent() as Control
	if row != null and not is_instance_valid(row):
		row = null
	_ensure_controls_focus_visible(header, row, target)
	target.grab_focus()
	return true

func _move_controls_horizontal_focus(direction: int) -> bool:
	_prune_controls_nav_buttons()
	if direction == 0:
		return false
	var focus_owner := get_viewport().gui_get_focus_owner() as Control
	if focus_owner == null:
		return false
	if _controls_reset_button != null and is_instance_valid(_controls_reset_button) and focus_owner == _controls_reset_button:
		return false
	var target: Button = null
	if direction > 0 and focus_owner in _controls_nav_keyboard:
		var idx := _controls_nav_keyboard.find(focus_owner)
		if idx >= 0 and idx < _controls_nav_controller.size():
			target = _controls_nav_controller[idx]
	elif direction < 0 and focus_owner in _controls_nav_controller:
		var idx := _controls_nav_controller.find(focus_owner)
		if idx >= 0 and idx < _controls_nav_keyboard.size():
			target = _controls_nav_keyboard[idx]
	if target == null or not is_instance_valid(target) or target == focus_owner:
		return false
	var header: Control = _controls_header_for_button.get(target, null) as Control
	var row: Control = target.get_parent() as Control
	if row != null and not is_instance_valid(row):
		row = null
	_ensure_controls_focus_visible(header, row, target)
	target.grab_focus()
	return true

func _enter_team() -> void:
	_team_sub_level = "list"
	_team_selected_index = -1
	_team_sub_nav.clear()
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
	_show_section("settings")
	_active_section = "settings"
	_in_content = false
	_menu_level = "tabs"
	_settings_control_active = false
	_settings_nav_controls.clear()
	_settings_nav_focus_index = 0
	_set_sidebar_focus_enabled(false)
	_set_tabs_focus_enabled(false)
	_settings_tabs.current_tab = _last_settings_tab
	_set_all_tab_content_focus_enabled(false)
	_settings_to_content()

func _leave_content() -> void:
	_in_content = false
	_menu_level = "sidebar"
	_set_sidebar_focus_enabled(true)
	if _active_section == "settings":
		_set_all_tab_content_focus_enabled(false)
		_set_tabs_focus_enabled(false)
	if _active_section == "inventory":
		_set_inventory_focus_enabled(false)
	_set_team_buttons_focus_enabled(false)
	if _last_sidebar_focus == "settings":
		_settings_button.grab_focus()
	elif _last_sidebar_focus == "inventory":
		_inventory_button.grab_focus()
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
	_settings_control_active = false
	_settings_nav_controls.clear()
	_settings_nav_focus_index = 0
	_set_tabs_focus_enabled(false)
	_set_all_tab_content_focus_enabled(false)
	# For Video/Sound tabs: collect direct controls and navigate them.
	# For Controls tab: keep existing controls-nav system.
	if _is_controls_tab_active():
		_set_tab_content_focus_enabled(true)
		var focus_target := _find_first_focusable(tab_control)
		if focus_target != null:
			focus_target.grab_focus()
			_ensure_scroll_visible(_controls_scroll, focus_target)
	else:
		_set_tab_content_focus_enabled(true)
		_collect_settings_controls(tab_control)
		if not _settings_nav_controls.is_empty():
			_settings_nav_controls[0].grab_focus()
	_menu_level = "content"
	_in_content = true

func _collect_settings_controls(root: Node) -> void:
	for child in root.get_children():
		if child is OptionButton or child is CheckBox or child is Range:
			_settings_nav_controls.append(child as Control)
		else:
			_collect_settings_controls(child)

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

func _focus_tabs() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null and focus_owner != _settings_tabs:
		focus_owner.release_focus()
	_settings_tabs.grab_focus()
	_menu_level = "tabs"
	_in_content = false

func _settings_to_sidebar() -> void:
	_settings_control_active = false
	_settings_nav_controls.clear()
	_settings_nav_focus_index = 0
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
	elif _last_sidebar_focus == "inventory":
		_inventory_button.grab_focus()
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
	var valid_buttons: Array[Button] = []
	for button in _team_buttons:
		if button == null or not is_instance_valid(button):
			continue
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		valid_buttons.append(button)
	_team_buttons = valid_buttons

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
			if ctrl is OptionButton or ctrl is CheckBox or ctrl is Range:
				ctrl.focus_mode = Control.FOCUS_ALL
			elif ctrl is Button:
				ctrl.focus_mode = Control.FOCUS_ALL
			else:
				ctrl.focus_mode = Control.FOCUS_NONE
	for child in root.get_children():
		_set_focus_for_controls(child, enabled)

func set_overlay_message_active(active: bool) -> void:
	_overlay_message_active = active

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_control_buttons()


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
	_settings.general.language = str(config.get_value("general", "language", _settings.general.language))
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
						_set_bindings_from_config(action_name, "keyboard", entry.keyboard)
					if entry.has("controller"):
						_set_bindings_from_config(action_name, "controller", entry.controller)

func _set_bindings_from_config(action_name: String, device: String, value: Variant) -> void:
	if value is Array:
		_set_binding_codes(action_name, device, value as Array)
		return
	var code := int(value)
	if device == "keyboard":
		code = _normalize_legacy_keyboard_key(action_name, code)
	if code < 0:
		return
	if device == "keyboard":
		if code <= 0:
			return
		var key_event := InputEventKey.new()
		key_event.keycode = code as Key
		_replace_binding(action_name, "keyboard", key_event)
		return
	if device == "controller":
		var pad_event := InputEventJoypadButton.new()
		pad_event.button_index = code as JoyButton
		pad_event.device = -1
		_replace_binding(action_name, "controller", pad_event)

func _set_binding_codes(action_name: String, device: String, codes: Array) -> void:
	_ensure_action(action_name)
	var to_remove: Array = []
	for existing in InputMap.action_get_events(action_name):
		if device == "keyboard" and existing is InputEventKey:
			to_remove.append(existing)
		elif device == "controller" and existing is InputEventJoypadButton:
			to_remove.append(existing)
	for existing in to_remove:
		InputMap.action_erase_event(action_name, existing)

	for raw_code in codes:
		var code := int(raw_code)
		if device == "keyboard":
			code = _normalize_legacy_keyboard_key(action_name, code)
			if code <= 0:
				continue
			_add_keyboard_binding_if_missing(action_name, code)
		elif device == "controller":
			if code < 0:
				continue
			var exists := false
			for existing in InputMap.action_get_events(action_name):
				if existing is InputEventJoypadButton and existing.button_index == code:
					exists = true
					break
			if not exists:
				var pad_event := InputEventJoypadButton.new()
				pad_event.button_index = code as JoyButton
				pad_event.device = -1
				InputMap.action_add_event(action_name, pad_event)

	if device == "keyboard" and _is_movement_action(action_name) and _get_event_count(action_name, "keyboard") == 1:
		var selected_key := -1
		for existing in InputMap.action_get_events(action_name):
			if existing is InputEventKey:
				selected_key = _get_keycode_for_event(existing)
				break
		if selected_key > 0:
			var companion_key := _get_movement_companion_key(action_name, selected_key)
			if companion_key > 0 and companion_key != selected_key:
				_add_keyboard_binding_if_missing(action_name, companion_key)

func _normalize_legacy_keyboard_key(action_name: String, keycode: int) -> int:
	if action_name == "ui_cancel" and (keycode == KEY_ESCAPE or keycode == KEY_BACKSPACE):
		return KEY_SHIFT
	if action_name == "ui_accept" and keycode == KEY_ENTER:
		return KEY_SPACE
	return keycode

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", _settings.general.language)
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
				"keyboard": _get_binding_codes(action_name, "keyboard"),
				"controller": _get_binding_codes(action_name, "controller")
			}
			config.set_value("controls", action_name, entry)

	config.save(CONFIG_PATH)

func _get_binding_codes(action_name: String, device: String) -> Array[int]:
	var codes: Array[int] = []
	for event in InputMap.action_get_events(action_name):
		if device == "keyboard" and event is InputEventKey:
			var keycode := _get_keycode_for_event(event)
			if not codes.has(keycode):
				codes.append(keycode)
		if device == "controller" and event is InputEventJoypadButton:
			var button_index := int(event.button_index)
			if not codes.has(button_index):
				codes.append(button_index)
	return codes


# ================================================================
# Team sub-view management
# ================================================================

func _team_go_back() -> void:
	match _team_sub_level:
		"list":
			_leave_content()
		"options":
			var prev_idx := _team_selected_index
			_team_sub_level = "list"
			_team_selected_index = -1
			_team_sub_nav.clear()
			_update_team_list(_last_team)
			_set_team_buttons_focus_enabled(true)
			if prev_idx >= 0 and prev_idx < _team_buttons.size():
				_team_buttons[prev_idx].grab_focus()
				_ensure_scroll_visible(_team_scroll, _team_buttons[prev_idx])
			elif not _team_buttons.is_empty():
				_team_buttons[0].grab_focus()
		"switch":
			_team_sub_level = "options"
			_team_sub_nav.clear()
			_build_team_options_view(_team_selected_index)
		"status":
			_team_sub_level = "options"
			_team_sub_nav.clear()
			_build_team_options_view(_team_selected_index)

func _team_open_monster_options(index: int) -> void:
	_team_selected_index = index
	_team_sub_level = "options"
	_team_sub_nav.clear()
	_build_team_options_view(index)

func _build_team_options_view(index: int) -> void:
	_team_sub_nav.clear()
	_team_buttons.clear()
	for child in _team_list.get_children():
		child.queue_free()
	# Validate index bounds safely
	if index < 0 or index >= _last_team.size():
		return
	var monster: MTMonsterInstance = _last_team[index] as MTMonsterInstance
	if monster == null:  # Validate object not null
		return

	var title := Label.new()
	title.text = tr("%s  Lv. %d  |  HP %d/%d  |  EN %d/%d") % [
		_monster_name(monster), monster.level,
		monster.hp, monster.get_max_hp(),
		monster.energy, monster.get_max_energy()
	]
	_team_list.add_child(title)

	_team_list.add_child(HSeparator.new())

	var btn_status := Button.new()
	btn_status.text = tr("Status")
	btn_status.focus_mode = Control.FOCUS_ALL
	btn_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_status.pressed.connect(func(): _team_show_status(index))
	_team_list.add_child(btn_status)
	_team_sub_nav.append(btn_status)

	var btn_switch := Button.new()
	btn_switch.text = tr("Switch")
	btn_switch.focus_mode = Control.FOCUS_ALL
	btn_switch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_switch.pressed.connect(func(): _team_start_switch(index))
	_team_list.add_child(btn_switch)
	_team_sub_nav.append(btn_switch)

	_prune_team_sub_nav()
	if not _team_sub_nav.is_empty():
		_team_sub_nav[0].grab_focus()

func _team_start_switch(source_index: int) -> void:
	_team_selected_index = source_index
	_team_sub_level = "switch"
	_team_sub_nav.clear()
	_build_team_switch_view(source_index)

func _build_team_switch_view(source_index: int) -> void:
	_team_sub_nav.clear()
	_team_buttons.clear()
	for child in _team_list.get_children():
		child.queue_free()
	# Validate index bounds safely
	if source_index < 0 or source_index >= _last_team.size():
		return
	var source: MTMonsterInstance = _last_team[source_index] as MTMonsterInstance
	if source == null:  # Validate object not null
		return

	var header := Label.new()
	header.text = tr("Swap %s with ...") % _monster_name(source)
	_team_list.add_child(header)
	_team_list.add_child(HSeparator.new())

	for i in range(_last_team.size()):
		var m: MTMonsterInstance = _last_team[i] as MTMonsterInstance
		if m == null:
			continue
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == source_index:
			btn.text = tr("► %s  Lv. %d  [current position]") % [_monster_name(m), m.level]
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
		else:
			btn.text = tr("%s  Lv. %d  |  HP %d/%d") % [_monster_name(m), m.level, m.hp, m.get_max_hp()]
			btn.focus_mode = Control.FOCUS_ALL
			var captured_i := i
			btn.pressed.connect(func(): _team_finish_switch(captured_i))
			_team_sub_nav.append(btn)
		_team_list.add_child(btn)

	_prune_team_sub_nav()
	if not _team_sub_nav.is_empty():
		_team_sub_nav[0].grab_focus()

func _team_finish_switch(target_index: int) -> void:
	var source_index := _team_selected_index
	if source_index < 0 or source_index >= _last_team.size():
		return
	if target_index < 0 or target_index >= _last_team.size():
		return
	var game = _get_game()
	if game == null:
		return
	if not game.swap_party_positions(source_index, target_index):
		return
	_team_sub_level = "list"
	_team_selected_index = -1
	_team_sub_nav.clear()
	_update_team_list(_last_team)
	_set_team_buttons_focus_enabled(true)
	var focus_idx := mini(source_index, _team_buttons.size() - 1)
	if not _team_buttons.is_empty():
		_team_buttons[focus_idx].grab_focus()
		_ensure_scroll_visible(_team_scroll, _team_buttons[focus_idx])

func _team_show_status(index: int) -> void:
	_team_selected_index = index
	_team_sub_level = "status"
	_team_status_tab = 0
	_team_sub_nav.clear()
	_build_team_status_view(index)

func _build_team_status_view(index: int) -> void:
	_team_sub_nav.clear()
	_team_buttons.clear()
	for child in _team_list.get_children():
		child.queue_free()
	if index < 0 or index >= _last_team.size():
		return
	var monster: MTMonsterInstance = _last_team[index] as MTMonsterInstance
	if monster == null:
		return

	MonsterStatusViewHelper.add_title(_team_list, monster)

	# Tab buttons
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	_team_list.add_child(tab_row)

	var tab_names: Array[String] = MonsterStatusViewHelper.get_tab_names()
	var tab_buttons: Array[Button] = []
	for ti in range(tab_names.size()):
		var tb := Button.new()
		tb.text = tab_names[ti]
		tb.focus_mode = Control.FOCUS_ALL
		tb.toggle_mode = true
		tb.button_pressed = (ti == _team_status_tab)
		var captured_ti := ti
		var captured_idx := index
		tb.pressed.connect(func():
			_team_status_tab = captured_ti
			_build_team_status_view(captured_idx)
		)
		tab_row.add_child(tb)
		tab_buttons.append(tb)
		_team_sub_nav.append(tb)

	_team_list.add_child(HSeparator.new())

	# Content
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	_team_list.add_child(content)
	MonsterStatusViewHelper.add_tab_content(content, monster, _team_status_tab)

	if _team_status_tab < tab_buttons.size():
		tab_buttons[_team_status_tab].grab_focus()

func _team_sub_nav_move(direction: int) -> void:
	_prune_team_sub_nav()
	if _team_sub_nav.is_empty():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var current_idx := -1
	for i in range(_team_sub_nav.size()):
		if _team_sub_nav[i] == focus_owner:
			current_idx = i
			break
	var next_idx := current_idx + direction
	if next_idx < 0 or next_idx >= _team_sub_nav.size():
		return
	var target := _team_sub_nav[next_idx]
	if target == null or not is_instance_valid(target):
		return
	target.grab_focus()

func _team_list_move_focus(direction: int) -> void:
	_set_team_buttons_focus_enabled(true)
	if _team_buttons.is_empty():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var current_idx := -1
	for i in range(_team_buttons.size()):
		if _team_buttons[i] == focus_owner:
			current_idx = i
			break
	var next_idx := current_idx + direction
	if next_idx < 0 or next_idx >= _team_buttons.size():
		return
	var target := _team_buttons[next_idx]
	if target == null or not is_instance_valid(target):
		return
	target.grab_focus()
	_ensure_scroll_visible(_team_scroll, target)
