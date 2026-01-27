extends Resource
class_name TraitEffect

# Wird beim Hinzufügen aufgerufen
func on_apply(monster) -> void:
	pass

# Schadensmodifikation
func modify_damage(attacker, defender, damage: float, action) -> float:
	return damage

# Stat-Modifikation
func modify_stat(monster, stat: int, value: int) -> int:
	return value
