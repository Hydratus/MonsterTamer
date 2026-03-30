extends Control
class_name MTItemMenu

const ITEM_DB = preload("res://core/items/item_db.gd")
const ItemDataClass = preload("res://core/items/item_data.gd")

signal closed
signal item_used(item: MTItemData, target: MTMonsterInstance)

@onready var _tabs: TabContainer = $RootVBox/Tabs as TabContainer
@onready var _active_list: VBoxContainer = $RootVBox/Tabs/Active/ActiveScroll/ActiveList as VBoxContainer
@onready var _active_scroll: ScrollContainer = $RootVBox/Tabs/Active/ActiveScroll as ScrollContainer
@onready var _binding_runes_list: VBoxContainer = $RootVBox/Tabs/BindingRunes/BindingRunesScroll/BindingRunesList as VBoxContainer
@onready var _binding_runes_scroll: ScrollContainer = $RootVBox/Tabs/BindingRunes/BindingRunesScroll as ScrollContainer
@onready var _weapon_list: VBoxContainer = $RootVBox/Tabs/Weapon/WeaponScroll/WeaponList as VBoxContainer
@onready var _weapon_scroll: ScrollContainer = $RootVBox/Tabs/Weapon/WeaponScroll as ScrollContainer
@onready var _armor_list: VBoxContainer = $RootVBox/Tabs/Armor/ArmorScroll/ArmorList as VBoxContainer
@onready var _armor_scroll: ScrollContainer = $RootVBox/Tabs/Armor/ArmorScroll as ScrollContainer
@onready var _accessoire_list: VBoxContainer = $RootVBox/Tabs/Accessoire/AccessoireScroll/AccessoireList as VBoxContainer
@onready var _accessoire_scroll: ScrollContainer = $RootVBox/Tabs/Accessoire/AccessoireScroll as ScrollContainer
@onready var _back_button: Button = $RootVBox/Footer/BackButton as Button

var _team: Array = []
var _mode := "items"
var _pending_item: MTItemData
var _buttons: Array[Button] = []
var _allow_back := true
var _auto_focus_content := true
var _nav_hold_dir: int = 0
var _nav_repeat_timer: float = 0.0
var _ignore_hold_until_release := false
var _require_focus_owner := true
var _allow_enter_from_tabs := true

const NAV_REPEAT_DELAY := 0.35
const NAV_REPEAT_INTERVAL := 0.08

func _ready() -> void:
	visible = false
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process(true)
	_tabs.set_tab_title(ItemDataClass.Category.SOULBINDER, "Binding Runes")
	_tabs.tab_changed.connect(_on_tab_changed)
	_back_button.pressed.connect(func():
		if _mode == "targets":
			_show_items_for_tab(_tabs.current_tab)
		else:
			close()
	)

func _process(delta: float) -> void:
	if not visible:
		_nav_hold_dir = 0
		_nav_repeat_timer = 0.0
		return
	if _ignore_hold_until_release:
		if Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_up"):
			return
		_ignore_hold_until_release = false
	if _nav_hold_dir == 0:
		pass
	if _buttons.is_empty():
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner() as Control
	var focus_button: Button = focus_owner as Button
	var focus_in_list := focus_button != null and _buttons.has(focus_button)
	if _require_focus_owner and not focus_in_list:
		return
	if not focus_in_list:
		return
	var dir := 0
	if Input.is_action_pressed("ui_down") and not Input.is_action_pressed("ui_up"):
		dir = 1
	elif Input.is_action_pressed("ui_up") and not Input.is_action_pressed("ui_down"):
		dir = -1
	if dir == 0:
		_nav_hold_dir = 0
		_nav_repeat_timer = 0.0
		return
	if dir != _nav_hold_dir:
		_nav_hold_dir = dir
		_nav_repeat_timer = NAV_REPEAT_DELAY
		return
	_nav_repeat_timer -= delta
	if _nav_repeat_timer <= 0.0:
		_nav_repeat_timer += NAV_REPEAT_INTERVAL
		_move_button_focus(dir)

func _input(event: InputEvent) -> void:
	if _handle_nav_event(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _handle_nav_event(event):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()

func _handle_nav_event(event: InputEvent) -> bool:
	if not visible:
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner() as Control
	var focus_button: Button = focus_owner as Button
	var focus_in_menu := focus_owner != null and is_ancestor_of(focus_owner)
	if event.is_action_pressed("ui_accept"):
		if not focus_in_menu:
			return false
		if focus_button != null and _buttons.has(focus_button):
			_move_button_focus(0)
			focus_owner.emit_signal("pressed")
			return true
		if focus_owner == _back_button:
			focus_owner.emit_signal("pressed")
			return true
		return false
	if event.is_action_pressed("ui_left"):
		if focus_in_menu:
			select_prev_tab()
			return true
		return false
	if event.is_action_pressed("ui_right"):
		if focus_in_menu:
			select_next_tab()
			return true
		return false
	if _buttons.is_empty():
		return false
	var focus_in_list := focus_button != null and _buttons.has(focus_button)
	if event.is_action_pressed("ui_down"):
		_nav_hold_dir = 1
		_nav_repeat_timer = NAV_REPEAT_DELAY
		if focus_in_list:
			_move_button_focus(1)
		else:
			if not _allow_enter_from_tabs:
				return false
			_buttons[0].grab_focus()
			call_deferred("_ensure_scroll_visible", _get_scroll_for_tab(_tabs.current_tab), _buttons[0])
		return true
	if event.is_action_pressed("ui_up"):
		_nav_hold_dir = -1
		_nav_repeat_timer = NAV_REPEAT_DELAY
		if focus_in_list:
			if is_first_item_focused():
				return false
			_move_button_focus(-1)
		else:
			if not _allow_enter_from_tabs:
				return false
			var last_index := _buttons.size() - 1
			_buttons[last_index].grab_focus()
			call_deferred("_ensure_scroll_visible", _get_scroll_for_tab(_tabs.current_tab), _buttons[last_index])
		return true
	if _require_focus_owner and not focus_in_list:
		return false
	return false

func open_inventory(team: Array, allow_back: bool = true, auto_focus_content: bool = true) -> void:
	_team = team
	_allow_back = allow_back
	_auto_focus_content = auto_focus_content
	_back_button.visible = allow_back
	visible = true
	_show_items_for_tab(_tabs.current_tab)

func set_allow_enter_from_tabs(allow: bool) -> void:
	_allow_enter_from_tabs = allow

func is_first_item_focused() -> bool:
	if _buttons.is_empty():
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner() as Control
	return focus_owner == _buttons[0]

func close() -> void:
	visible = false
	_mode = "items"
	_closed_cleanup()
	closed.emit()

func refresh() -> void:
	if not visible:
		return
	_show_items_for_tab(_tabs.current_tab)

func set_focus_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	_back_button.focus_mode = Control.FOCUS_ALL if enabled and _allow_back else Control.FOCUS_NONE

func set_tabs_focus_enabled(enabled: bool) -> void:
	var tab_bar: Control = _tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

func grab_tabs_focus() -> void:
	var tab_bar: Control = _tabs.get_tab_bar()
	if tab_bar == null:
		return
	tab_bar.grab_focus()

func set_auto_focus_content(enabled: bool) -> void:
	_auto_focus_content = enabled

func set_require_focus_owner(enabled: bool) -> void:
	_require_focus_owner = enabled

func select_next_tab() -> void:
	_tabs.current_tab = min(_tabs.current_tab + 1, _tabs.get_tab_count() - 1)

func select_prev_tab() -> void:
	_tabs.current_tab = max(_tabs.current_tab - 1, 0)

func select_tab(tab_index: int) -> void:
	_tabs.current_tab = clamp(tab_index, 0, _tabs.get_tab_count() - 1)

func grab_first_focus() -> void:
	if _buttons.size() > 0:
		_buttons[0].grab_focus()
		_ignore_hold_until_release = true
	elif _allow_back:
		_back_button.grab_focus()

func _closed_cleanup() -> void:
	_pending_item = null
	_buttons.clear()

func _on_tab_changed(_index: int) -> void:
	if _mode == "items":
		_show_items_for_tab(_tabs.current_tab)

func has_items_in_current_tab() -> bool:
	return _tab_has_items(_tabs.current_tab)

func _tab_has_items(tab_index: int) -> bool:
	var items := ITEM_DB.new().get_all_items()
	for item in items:
		if item.category == tab_index:
			var count: int = Game.get_item_count(item.id)
			if count > 0:
				return true
	return false

func _show_items_for_tab(tab_index: int) -> void:
	_mode = "items"
	_pending_item = null
	var list := _get_list_for_tab(tab_index)
	_clear_list(list)
	_buttons.clear()

	var items := ITEM_DB.new().get_all_items()
	var filtered: Array[MTItemData] = []
	for item in items:
		if item.category == tab_index:
			var count: int = Game.get_item_count(item.id)
			if count > 0:
				filtered.append(item)

	if filtered.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items."
		list.add_child(empty_label)
		if _auto_focus_content:
			var tab_bar: Control = _tabs.get_tab_bar()
			if tab_bar != null:
				tab_bar.grab_focus()
		return

	for item in filtered:
		var count: int = Game.get_item_count(item.id)
		var button := Button.new()
		button.text = "%s x%d" % [item.name, count]
		button.focus_entered.connect(func():
			_ensure_scroll_visible(_get_scroll_for_tab(tab_index), button)
		)
		button.pressed.connect(func():
			_on_item_pressed(item)
		)
		list.add_child(button)
		_buttons.append(button)

	if _auto_focus_content:
		grab_first_focus()

func _on_item_pressed(item: MTItemData) -> void:
	if item == null:
		return
	if item.target_type == MTItemData.TargetType.SELF_TEAM and _team.size() > 0:
		_show_targets(item)
		return
	item_used.emit(item, null)

func _show_targets(item: MTItemData) -> void:
	_mode = "targets"
	_pending_item = item
	var list := _get_list_for_tab(_tabs.current_tab)
	_clear_list(list)
	_buttons.clear()

	var title := Label.new()
	title.text = "Select Target"
	list.add_child(title)

	for monster in _team:
		if monster == null:
			continue
		var button := Button.new()
		button.text = "%s %d/%d HP" % [monster.data.name, monster.hp, monster.get_max_hp()]
		button.focus_entered.connect(func():
			_ensure_scroll_visible(_get_scroll_for_tab(_tabs.current_tab), button)
		)
		button.pressed.connect(func():
			item_used.emit(item, monster)
		)
		list.add_child(button)
		_buttons.append(button)

	grab_first_focus()

func _get_list_for_tab(tab_index: int) -> VBoxContainer:
	match tab_index:
		ItemDataClass.Category.SOULBINDER:
			return _binding_runes_list
		MTItemData.Category.WEAPON:
			return _weapon_list
		MTItemData.Category.ARMOR:
			return _armor_list
		MTItemData.Category.ACCESSOIRE:
			return _accessoire_list
		_:
			return _active_list

func _get_scroll_for_tab(tab_index: int) -> ScrollContainer:
	match tab_index:
		ItemDataClass.Category.SOULBINDER:
			return _binding_runes_scroll
		MTItemData.Category.WEAPON:
			return _weapon_scroll
		MTItemData.Category.ARMOR:
			return _armor_scroll
		MTItemData.Category.ACCESSOIRE:
			return _accessoire_scroll
		_:
			return _active_scroll

func _ensure_scroll_visible(scroll: ScrollContainer, control: Control) -> void:
	if scroll == null or control == null:
		return
	if scroll.is_ancestor_of(control):
		scroll.ensure_control_visible(control)

func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()

func _move_button_focus(step: int) -> bool:
	if _buttons.is_empty():
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner() as Control
	var index: int = _buttons.find(focus_owner)
	if index == -1:
		index = 0 if step > 0 else _buttons.size() - 1
	var next_index: int = int(clamp(index + step, 0, _buttons.size() - 1))
	var guard: int = 0
	while guard < _buttons.size() and _buttons[next_index].disabled:
		next_index = clamp(next_index + step, 0, _buttons.size() - 1)
		guard += 1
	if _buttons[next_index].disabled:
		return false
	_buttons[next_index].grab_focus()
	call_deferred("_ensure_scroll_visible", _get_scroll_for_tab(_tabs.current_tab), _buttons[next_index])
	return true
