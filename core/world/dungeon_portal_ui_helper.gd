extends RefCounted
class_name MTDungeonPortalUIHelper

## Portal UI Helper for biome selection after boss defeats
## Creates visual portals showing available biomes for player selection on boss floors 41-48

static func _get_game():
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Game")

static func get_biome_display_name(biome: String) -> String:
	"""Returns display name for biome"""
	var display_names = {
		"gloomrot_catacombs": "Gloomrot Catacombs",
		"thornfang_warrens": "Thornfang Warrens",
		"sunforge_basilica": "Sunforge Basilica",
		"skytide_reservoir": "Skytide Reservoir",
		"emberfault_chasm": "Emberfault Chasm",
		"stargrave_observatory": "Stargrave Observatory",
		"ironhowl_bastion": "Ironhowl Bastion",
		"echo_vault": "Echo Vault"
	}
	return display_names.get(biome, biome)

static func create_portal_ui(owner) -> void:
	"""Creates the portal UI layer for biome selection"""
	owner._portal_layer = CanvasLayer.new()
	owner._portal_layer.layer = 13  # Below merchant (14), above game (12)
	owner.add_child(owner._portal_layer)
	
	# Create container for portals
	owner._portal_container = HBoxContainer.new()
	owner._portal_container.anchor_left = 0.5
	owner._portal_container.anchor_top = 0.5
	owner._portal_container.anchor_right = 0.5
	owner._portal_container.anchor_bottom = 0.5
	owner._portal_container.offset_left = -320
	owner._portal_container.offset_top = -100
	owner._portal_container.offset_right = 320
	owner._portal_container.offset_bottom = 100
	owner._portal_container.add_theme_constant_override("separation", 40)
	owner._portal_layer.add_child(owner._portal_container)
	
	# Title label
	var title_container = VBoxContainer.new()
	title_container.name = "PortalTitleContainer"
	title_container.anchor_left = 0.5
	title_container.anchor_top = 0.1
	title_container.anchor_right = 0.5
	title_container.anchor_bottom = 0.15
	title_container.offset_left = -150
	title_container.offset_top = -20
	title_container.offset_right = 150
	title_container.offset_bottom = 20
	
	var title = Label.new()
	title.text = TranslationServer.translate("Choose your next biome")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75, 1))
	title.add_theme_font_size_override("font_size", 24)
	title_container.add_child(title)
	
	owner._portal_layer.add_child(title_container)
	title_container.visible = false
	owner._portal_container.visible = false

static func show_biome_selection_portals(owner, biome_options: Array[String]) -> void:
	"""Displays biome selection portals after boss defeat"""
	if owner._portal_container == null:
		return
	
	# Clear previous portals
	for child in owner._portal_container.get_children():
		child.queue_free()
	
	# Create portal buttons for each available biome
	for i in range(biome_options.size()):
		var biome = biome_options[i]
		var portal_button = create_portal_button(owner, biome, i)
		owner._portal_container.add_child(portal_button)
	
	var title_container: Control = owner._portal_layer.get_node_or_null("PortalTitleContainer") as Control
	if title_container != null:
		title_container.visible = true
	owner._portal_container.visible = true

static func create_portal_button(owner, biome: String, _index: int) -> PanelContainer:
	"""Creates a single portal button for biome selection"""
	var portal = PanelContainer.new()
	portal.custom_minimum_size = Vector2(250, 150)
	
	# Portal styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.set_border_width_all(3)
	style.border_color = Color(0.5, 0.2, 1.0, 1)  # Purple glow
	portal.add_theme_stylebox_override("panel", style)
	
	# Content
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	portal.add_child(content)
	
	# Biome name
	var biome_name = Label.new()
	biome_name.text = get_biome_display_name(biome)
	biome_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	biome_name.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0, 1))
	biome_name.add_theme_font_size_override("font_size", 18)
	content.add_child(biome_name)
	
	# Description
	var desc = Label.new()
	desc.text = get_biome_description(biome)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.8))
	desc.add_theme_font_size_override("font_size", 12)
	content.add_child(desc)
	
	# Select button
	var select_btn = Button.new()
	select_btn.text = TranslationServer.translate("Select")
	select_btn.focus_mode = Control.FOCUS_ALL
	select_btn.pressed.connect(owner._on_portal_biome_selected.bind(biome))
	content.add_child(select_btn)
	
	return portal

static func get_biome_description(biome: String) -> String:
	"""Returns description for biome"""
	var descriptions = {
		"gloomrot_catacombs": "Undead & Cosmic Element",
		"thornfang_warrens": "Plant & Poison Element",
		"sunforge_basilica": "Fire & Holy Element",
		"skytide_reservoir": "Water & Ice Element",
		"emberfault_chasm": "Fire & Earth Element",
		"stargrave_observatory": "Cosmic & Electric Element",
		"ironhowl_bastion": "Metal & Beast Element",
		"echo_vault": "Undead & Cosmic Element"
	}
	return descriptions.get(biome, "")

static func hide_biome_selection_portals(owner) -> void:
	"""Hides biome selection portals"""
	if owner._portal_layer != null:
		var title_container: Control = owner._portal_layer.get_node_or_null("PortalTitleContainer") as Control
		if title_container != null:
			title_container.visible = false
	if owner._portal_container != null:
		owner._portal_container.visible = false
