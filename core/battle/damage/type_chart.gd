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

static var chart := {
	MTElement.Type.FIRE: {
		MTElement.Type.PLANT: 2.0,
		MTElement.Type.WATER: 0.5,
		MTElement.Type.FIRE: 0.5,
	},

	MTElement.Type.WATER: {
		MTElement.Type.FIRE: 2.0,
		MTElement.Type.PLANT: 0.5,
		MTElement.Type.WATER: 0.5,
	},

	MTElement.Type.PLANT: {
		MTElement.Type.WATER: 2.0,
		MTElement.Type.FIRE: 0.5,
		MTElement.Type.PLANT: 0.5,
	},

	# Beispiel Immunität
	MTElement.Type.NORMAL: {
		MTElement.Type.GHOST: 0.0
	},

	MTElement.Type.GHOST: {
		MTElement.Type.NORMAL: 0.0
	}
}


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
