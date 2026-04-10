extends RefCounted
class_name MTMonsterStatusViewHelper

const TAB_KEYS: Array[String] = ["Stats", "Attacks", "Traits"]

static func get_tab_names() -> Array[String]:
	var names: Array[String] = []
	for key in TAB_KEYS:
		names.append(TranslationServer.translate(key))
	return names

static func add_title(container: VBoxContainer, monster: MTMonsterInstance) -> void:
	if container == null or monster == null:
		return
	var title := Label.new()
	title.text = TranslationServer.translate("%s  Lv. %d  |  HP %d/%d  |  EN %d/%d") % [
		_monster_name(monster),
		monster.level,
		monster.hp,
		monster.get_max_hp(),
		monster.energy,
		monster.get_max_energy()
	]
	container.add_child(title)

static func add_tab_content(container: VBoxContainer, monster: MTMonsterInstance, tab_index: int) -> void:
	if container == null or monster == null:
		return
	match tab_index:
		0:
			_add_stats_tab(container, monster)
		1:
			_add_attacks_tab(container, monster)
		2:
			_add_traits_tab(container, monster)

static func _add_stats_tab(container: VBoxContainer, monster: MTMonsterInstance) -> void:
	var stat_rows: Array = [
		[TranslationServer.translate("HP"), monster.get_max_hp()],
		[TranslationServer.translate("EN"), monster.get_max_energy()],
		[TranslationServer.translate("STR"), monster.get_strength()],
		[TranslationServer.translate("MAG"), monster.get_magic()],
		[TranslationServer.translate("DEF"), monster.get_defense()],
		[TranslationServer.translate("RES"), monster.get_resistance()],
		[TranslationServer.translate("SPD"), monster.get_speed()]
	]
	for stat_entry in stat_rows:
		var row := HBoxContainer.new()
		var label_name := Label.new()
		label_name.text = str(stat_entry[0])
		label_name.custom_minimum_size = Vector2(80, 0)
		var label_value := Label.new()
		label_value.text = str(stat_entry[1])
		row.add_child(label_name)
		row.add_child(label_value)
		container.add_child(row)

static func _add_attacks_tab(container: VBoxContainer, monster: MTMonsterInstance) -> void:
	if monster.attacks.is_empty():
		var empty := Label.new()
		empty.text = TranslationServer.translate("No attacks learned.")
		container.add_child(empty)
		return
	var elem_keys := MTElement.Type.keys()
	for attack in monster.attacks:
		if attack == null:
			continue
		var elem_idx: int = attack.element
		var elem_key: String = elem_keys[elem_idx] if elem_idx >= 0 and elem_idx < elem_keys.size() else "?"
		var elem_name: String = TranslationServer.translate(elem_key)
		var localized_attack_name: String = TranslationServer.translate(attack.name)
		var localized_attack_description: String = ""
		if attack.description != "":
			localized_attack_description = _localize_attack_description(attack.description)
		var attack_label := Label.new()
		attack_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		attack_label.text = TranslationServer.translate("%s  |  %s  |  Power: %d  |  EN: %d  |  Acc: %d%%") % [
			localized_attack_name,
			elem_name,
			attack.power,
			attack.energy_cost,
			attack.accuracy
		]
		if localized_attack_description != "":
			attack_label.text += "\n  " + localized_attack_description
		container.add_child(attack_label)

static func _add_traits_tab(container: VBoxContainer, monster: MTMonsterInstance) -> void:
	if monster.passive_traits.is_empty():
		var empty := Label.new()
		empty.text = TranslationServer.translate("No traits.")
		container.add_child(empty)
		return
	for trait_entry in monster.passive_traits:
		if trait_entry == null:
			continue
		var trait_name: String = ""
		if trait_entry.has_method("get_localized_name"):
			trait_name = str(trait_entry.get_localized_name())
		else:
			trait_name = TranslationServer.translate(str(trait_entry.name))
		var trait_description: String = ""
		if trait_entry.has_method("get_localized_description"):
			trait_description = str(trait_entry.get_localized_description())
		else:
			trait_description = TranslationServer.translate(str(trait_entry.description))
		var trait_label := Label.new()
		trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if trait_description != "":
			trait_label.text = TranslationServer.translate("%s: %s") % [trait_name, trait_description]
		else:
			trait_label.text = trait_name
		container.add_child(trait_label)

static func _localize_attack_description(text: String) -> String:
	var localized: String = TranslationServer.translate(text)
	if localized == "":
		return localized
	if not TranslationServer.get_locale().begins_with("de"):
		return localized

	# Fallback for known English fragments when an exact PO key does not match.
	if localized == text:
		localized = localized.replace("Buff self Strength +2.\nDebuff self Speed -5.", "Erhoeht eigene STR um +2.\nSenkt eigene SPD um 5.")
		localized = localized.replace("Buff self Strength +2.", "Erhoeht eigene STR um +2.")
		localized = localized.replace("Debuff self Speed -5.", "Senkt eigene SPD um 5.")
		localized = localized.replace("Debuff enemy Strength -5.", "Senkt die gegnerische STR um 5.")
		localized = localized.replace("self", "eigene")
		localized = localized.replace("target", "Ziel")
		localized = localized.replace("enemy", "Gegner")

	return localized

static func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name
