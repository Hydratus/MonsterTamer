extends Resource
class_name MTElement

enum Type {
	FIRE = 1,
	PLANT = 2,
	WATER = 3,
	UNDEAD = 4,
	ELECTRIC = 5,
	SOUND = 6,
	COSMIC = 7,
	HOLY = 8,
	POISON = 9,
	METAL = 10,
	DRAGON = 11,
	AIR = 12,
	BEAST = 13,
	EARTH = 14,
	ICE = 15
}

static func type_to_key(element_type: int) -> String:
	match element_type:
		Type.FIRE:
			return "FIRE"
		Type.PLANT:
			return "PLANT"
		Type.WATER:
			return "WATER"
		Type.UNDEAD:
			return "UNDEAD"
		Type.ELECTRIC:
			return "ELECTRIC"
		Type.SOUND:
			return "SOUND"
		Type.COSMIC:
			return "COSMIC"
		Type.HOLY:
			return "HOLY"
		Type.POISON:
			return "POISON"
		Type.METAL:
			return "METAL"
		Type.DRAGON:
			return "DRAGON"
		Type.AIR:
			return "AIR"
		Type.BEAST:
			return "BEAST"
		Type.EARTH:
			return "EARTH"
		Type.ICE:
			return "ICE"
		_:
			return "UNKNOWN"
