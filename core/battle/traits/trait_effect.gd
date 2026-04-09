extends Resource
class_name MTTraitEffect

# Wird beim Hinzufügen aufgerufen
func on_apply(_monster) -> void:
	pass

# Schadensmodifikation
func modify_damage(_attacker, _defender, damage: float, _action) -> float:
	return damage

# Stat-Modifikation
func modify_stat(_monster, _stat: int, value: int) -> int:
	return value
