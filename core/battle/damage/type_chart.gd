extends RefCounted
class_name MTTypeChart


# -------------------------------------------------
# Zentrale Typen-Tabelle
# -------------------------------------------------
# attack_element -> defense_element -> multiplier
# 0.0 = Immun
# 0.5 = nicht sehr effektiv
# 1.0 = normal
# 2.0 = sehr effektiv
# 4.0 entsteht automatisch bei Doppeltypen
# -------------------------------------------------

const TYPE_CHART_CSV_PATH := "res://data/elements/type_chart.csv"

static var _name_to_type := {
	"fire": MTElement.Type.FIRE,
	"plant": MTElement.Type.PLANT,
	"water": MTElement.Type.WATER,
	"electric": MTElement.Type.ELECTRIC,
	"sound": MTElement.Type.SOUND,
	"cosmic": MTElement.Type.COSMIC,
	"undead": MTElement.Type.UNDEAD,
	"holy": MTElement.Type.HOLY,
	"poison": MTElement.Type.POISON,
	"metal": MTElement.Type.METAL,
	"dragon": MTElement.Type.DRAGON,
	"air": MTElement.Type.AIR,
	"beast": MTElement.Type.BEAST,
	"earth": MTElement.Type.EARTH,
	"ice": MTElement.Type.ICE
}

static var chart := _build_chart_from_csv()


static func _parse_multiplier(token: String) -> float:
	var normalized := token.strip_edges().to_lower().replace(",", ".")
	if normalized == "x0":
		return 0.0
	if normalized == "x0.5":
		return 0.5
	if normalized == "x1":
		return 1.0
	if normalized == "x2":
		return 2.0

	return 1.0


static func _build_chart_from_csv() -> Dictionary:
	var loaded_chart: Dictionary = {}
	var file := FileAccess.open(TYPE_CHART_CSV_PATH, FileAccess.READ)
	if file == null:
		push_warning("Type chart CSV not found: %s" % TYPE_CHART_CSV_PATH)
		return loaded_chart

	var lines: PackedStringArray = file.get_as_text().strip_edges(true, true).split("\n", false)
	if lines.is_empty():
		return loaded_chart

	var header_cells: PackedStringArray = lines[0].strip_edges().split(";", false)
	if header_cells.size() < 2:
		return loaded_chart

	var defenders: Array = []
	for i in range(1, header_cells.size()):
		var defender_name := header_cells[i].strip_edges().to_lower()
		if _name_to_type.has(defender_name):
			defenders.append(_name_to_type[defender_name])
		else:
			defenders.append(null)

	for line_index in range(1, lines.size()):
		var raw_line := lines[line_index].strip_edges()
		if raw_line == "":
			continue

		var cells: PackedStringArray = raw_line.split(";", false)
		if cells.size() < 2:
			continue

		var attacker_name := cells[0].strip_edges().to_lower()
		if not _name_to_type.has(attacker_name):
			continue

		var attacker_type: int = _name_to_type[attacker_name]
		if not loaded_chart.has(attacker_type):
			loaded_chart[attacker_type] = {}

		for defender_index in range(min(cells.size() - 1, defenders.size())):
			var defender_type = defenders[defender_index]
			if defender_type == null:
				continue

			var multiplier := _parse_multiplier(cells[defender_index + 1])
			loaded_chart[attacker_type][defender_type] = multiplier

	return loaded_chart


# -------------------------------------------------
# MULTIPLIER für EINEN Verteidigungs-Typ
# -------------------------------------------------

static func _get_single_multiplier(
	attack_element: int,
	defense_element: int
) -> float:
	if chart.has(attack_element):
		if chart[attack_element].has(defense_element):
			return chart[attack_element][defense_element]

	return 1.0


# -------------------------------------------------
# MULTIPLIER für MEHRERE Verteidigungs-Typen
# (Doppeltypen!)
# -------------------------------------------------

static func get_multiplier(
	attack_element: int,
	defender_elements: Array
) -> float:
	var multiplier := 1.0

	for element in defender_elements:
		multiplier *= _get_single_multiplier(attack_element, element)

	return multiplier
