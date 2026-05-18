extends SceneTree

const ITEM_DATA_PATH := "res://core/items/item_data.gd"
const ITEMS_DIR := "res://data/items"

const TIERS := [
	{"name": "Lesser", "id": "lesser", "prefix": "A weak", "tier": -1},
	{"name": "Improved", "id": "improved", "prefix": "A stronger", "tier": 1},
	{"name": "Greater", "id": "greater", "prefix": "A potent", "tier": 2},
	{"name": "Superior", "id": "superior", "prefix": "An excellent", "tier": 3},
	{"name": "Mythic", "id": "mythic", "prefix": "A rare", "tier": 4},
	{"name": "Legendary", "id": "legendary", "prefix": "A legendary", "tier": 5}
]

const ELEMENTS := [
	{"name": "Fire", "lower": "fire", "value": 1},
	{"name": "Plant", "lower": "plant", "value": 2},
	{"name": "Water", "lower": "water", "value": 3},
	{"name": "Undead", "lower": "undead", "value": 4},
	{"name": "Electric", "lower": "electric", "value": 5},
	{"name": "Sound", "lower": "sound", "value": 6},
	{"name": "Cosmic", "lower": "cosmic", "value": 7},
	{"name": "Holy", "lower": "holy", "value": 8},
	{"name": "Poison", "lower": "poison", "value": 9},
	{"name": "Metal", "lower": "metal", "value": 10},
	{"name": "Dragon", "lower": "dragon", "value": 11},
	{"name": "Air", "lower": "air", "value": 12},
	{"name": "Beast", "lower": "beast", "value": 13},
	{"name": "Earth", "lower": "earth", "value": 14},
	{"name": "Ice", "lower": "ice", "value": 15}
]

func _init() -> void:
	var written := 0
	for tier in TIERS:
		for element in ELEMENTS:
			_write_element_rune_file(tier, element)
			written += 1
	print("[RuneGenerator] wrote %d elemental rune files." % written)
	quit()

func _write_element_rune_file(tier: Dictionary, element: Dictionary) -> void:
	var file_name := "%s%sBindingRune.tres" % [tier["name"], element["name"]]
	var file_path := "%s/%s" % [ITEMS_DIR, file_name]
	var id := "%s_%s_binding_rune" % [tier["id"], element["lower"]]
	var display_name := "%s %s Binding Rune" % [tier["name"], element["name"]]
	var description := "%s %s binding rune used to capture monsters." % [tier["prefix"], element["lower"]]

	var lines: Array[String] = [
		"[gd_resource type=\"Resource\" script_class=\"ItemData\" format=3]",
		"",
		"[ext_resource type=\"Script\" uid=\"uid://564rgj7ohsyo\" path=\"%s\" id=\"1\"]" % ITEM_DATA_PATH,
		"",
		"[resource]",
		"script = ExtResource(\"1\")",
		"id = \"%s\"" % id,
		"name = \"%s\"" % display_name,
		"description = \"%s\"" % description,
		"category = 1",
		"target_type = 1",
		"overworld_usable = false"
	]

	if int(tier["tier"]) >= 0:
		lines.append("rune_tier = %d" % int(tier["tier"]))
	lines.append("rune_element = %d" % int(element["value"]))

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[RuneGenerator] Failed writing %s" % file_path)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
