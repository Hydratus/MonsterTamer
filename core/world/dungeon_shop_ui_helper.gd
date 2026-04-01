extends RefCounted
class_name MTDungeonShopUIHelper

static func create_merchant_shop_ui(owner) -> void:
	owner._merchant_shop_layer = CanvasLayer.new()
	owner._merchant_shop_layer.layer = 14
	owner.add_child(owner._merchant_shop_layer)

	owner._merchant_shop_panel = PanelContainer.new()
	owner._merchant_shop_panel.anchor_left = 0.5
	owner._merchant_shop_panel.anchor_top = 0.5
	owner._merchant_shop_panel.anchor_right = 0.5
	owner._merchant_shop_panel.anchor_bottom = 0.5
	owner._merchant_shop_panel.offset_left = -200
	owner._merchant_shop_panel.offset_top = -140
	owner._merchant_shop_panel.offset_right = 200
	owner._merchant_shop_panel.offset_bottom = 140
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(1, 0.9, 0.65, 1)
	owner._merchant_shop_panel.add_theme_stylebox_override("panel", panel_style)
	owner._merchant_shop_layer.add_child(owner._merchant_shop_panel)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	owner._merchant_shop_panel.add_child(outer)

	owner._merchant_shop_title = Label.new()
	owner._merchant_shop_title.text = "Dungeon Merchant"
	owner._merchant_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner._merchant_shop_title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	outer.add_child(owner._merchant_shop_title)

	owner._merchant_shop_list = VBoxContainer.new()
	owner._merchant_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owner._merchant_shop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	owner._merchant_shop_list.add_theme_constant_override("separation", 4)
	outer.add_child(owner._merchant_shop_list)

	owner._merchant_shop_status = Label.new()
	owner._merchant_shop_status.text = ""
	owner._merchant_shop_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owner._merchant_shop_status.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 1))
	outer.add_child(owner._merchant_shop_status)

	owner._merchant_shop_close_button = Button.new()
	owner._merchant_shop_close_button.text = "Close"
	owner._merchant_shop_close_button.focus_mode = Control.FOCUS_ALL
	owner._merchant_shop_close_button.pressed.connect(owner._close_merchant_shop)
	outer.add_child(owner._merchant_shop_close_button)

	owner._merchant_shop_panel.visible = false

static func rebuild_merchant_shop_buttons(owner, item_db_class) -> void:
	owner._merchant_shop_buttons.clear()
	for child in owner._merchant_shop_list.get_children():
		child.queue_free()
	if Game == null:
		var unavailable: Label = Label.new()
		unavailable.text = "Merchant unavailable"
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		owner._merchant_shop_list.add_child(unavailable)
		return
	for i in range(owner.merchant_shop_items.size()):
		var item_id: String = str(owner.merchant_shop_items[i])
		var item_name: String = item_id
		var item_data = item_db_class.new().get_item(item_id)
		if item_data != null:
			item_name = item_data.name
		var base_price: int = 20
		if i < owner.merchant_shop_prices.size():
			base_price = int(owner.merchant_shop_prices[i])
		var price: int = owner._apply_merchant_discount(base_price)
		var button: Button = Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.text = "%s  -  %d gold" % [item_name, price]
		if Game.run_gold < price:
			button.disabled = true
		button.pressed.connect(owner._on_merchant_buy_pressed.bind(i))
		owner._merchant_shop_list.add_child(button)
		owner._merchant_shop_buttons.append(button)

static func open_merchant_shop(owner, item_db_class) -> void:
	if owner._merchant_shop_panel == null or owner._merchant_shop_panel.get_parent() == null:
		create_merchant_shop_ui(owner)
	rebuild_merchant_shop_buttons(owner, item_db_class)
	owner._merchant_shop_status.text = "Select an item to buy."
	owner._merchant_shop_panel.visible = true
	owner._merchant_shop_open = true
	owner._pause_npc_walks()
	if owner._merchant_shop_buttons.size() > 0:
		owner._merchant_shop_buttons[0].grab_focus()
	else:
		owner._merchant_shop_close_button.grab_focus()

static func close_merchant_shop(owner) -> void:
	owner._merchant_shop_open = false
	if owner._merchant_shop_panel != null:
		owner._merchant_shop_panel.visible = false
	owner._resume_npc_walks()
	var viewport = owner.get_viewport()
	if viewport != null:
		viewport.gui_release_focus()

static func on_merchant_buy_pressed(owner, index: int, item_db_class) -> void:
	if Game == null:
		owner._merchant_shop_status.text = "Merchant unavailable"
		return
	if index < 0 or index >= owner.merchant_shop_items.size():
		return
	var item_id: String = str(owner.merchant_shop_items[index])
	var base_price: int = 20
	if index < owner.merchant_shop_prices.size():
		base_price = int(owner.merchant_shop_prices[index])
	var price: int = owner._apply_merchant_discount(base_price)
	if not Game.spend_run_gold(price):
		owner._merchant_shop_status.text = "Not enough gold (%d needed, %d available)." % [price, Game.run_gold]
		rebuild_merchant_shop_buttons(owner, item_db_class)
		return
	Game.add_item(item_id, 1)
	var item_name: String = item_id
	var item_data = item_db_class.new().get_item(item_id)
	if item_data != null:
		item_name = item_data.name
	owner._merchant_shop_status.text = "Bought %s for %d gold." % [item_name, price]
	owner._log_dungeon("[Dungeon] merchant sale item=%s price=%d run_gold=%d" % [item_id, price, Game.run_gold])
	rebuild_merchant_shop_buttons(owner, item_db_class)
	if owner._merchant_shop_buttons.size() > 0:
		owner._merchant_shop_buttons[0].grab_focus()
	else:
		owner._merchant_shop_close_button.grab_focus()

static func create_currency_hud(owner) -> void:
	owner._currency_hud_layer = CanvasLayer.new()
	owner._currency_hud_layer.layer = 12
	owner.add_child(owner._currency_hud_layer)
	owner._currency_hud_label = Label.new()
	owner._currency_hud_label.anchor_left = 0.0
	owner._currency_hud_label.anchor_top = 0.5
	owner._currency_hud_label.anchor_right = 0.0
	owner._currency_hud_label.anchor_bottom = 0.5
	owner._currency_hud_label.offset_left = 10
	owner._currency_hud_label.offset_top = -24
	owner._currency_hud_label.offset_right = 260
	owner._currency_hud_label.offset_bottom = 24
	owner._currency_hud_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	owner._currency_hud_layer.add_child(owner._currency_hud_label)

static func update_currency_hud(owner, force: bool = false) -> void:
	if owner._currency_hud_label == null:
		return
	if Game == null:
		if force:
			owner._currency_hud_label.text = "Gold: -\nSoul Essence: -"
		return
	var gold: int = Game.run_gold
	var essence: int = Game.soul_essence
	if not force and gold == owner._last_gold_display and essence == owner._last_essence_display:
		return
	owner._last_gold_display = gold
	owner._last_essence_display = essence
	owner._currency_hud_label.text = "Gold: %d\nSoul Essence: %d" % [gold, essence]

static func apply_merchant_discount(_owner, base_price: int) -> int:
	if Game == null:
		return max(1, base_price)
	var discount_level: int = Game.get_meta_unlock_level("merchant_discount")
	var factor: float = clampf(1.0 - float(discount_level) * 0.10, 0.5, 1.0)
	return max(1, int(round(float(base_price) * factor)))
