extends Resource
class_name TraitStatModifier

@export var stat: MonsterInstance.StatType

# Flat Bonus (z. B. +10 Strength)
@export var flat_bonus: int = 0

# Multiplier (z. B. 1.2 = +20 %)
@export_range(0.0, 5.0, 0.05)
var multiplier: float = 1.0
