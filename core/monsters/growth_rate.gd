extends Resource
class_name GrowthRate

# Definiert, wie schnell ein Monster Level aufsteigt
enum Type {
	FAST,      # Schnell - Level × 12 EXP (1-2 Kämpfe)
	NORMAL,    # Normal - Level × 18 EXP (2-3 Kämpfe)
	SLOW,      # Langsam - Level × 24 EXP (3-4 Kämpfe)
	VERY_SLOW  # Sehr langsam - Level × 30 EXP (4-5 Kämpfe)
}

# Gibt die benötigte EXP für ein Level basierend auf der Wachstumsrate
static func get_required_exp(level: int, growth_type: int) -> int:
	match growth_type:
		Type.FAST:
			return level * 12
		Type.NORMAL:
			return level * 18
		Type.SLOW:
			return level * 24
		Type.VERY_SLOW:
			return level * 30
		_:
			return level * 18  # Default: NORMAL
