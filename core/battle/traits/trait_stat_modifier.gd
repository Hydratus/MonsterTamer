extends Resource
class_name MTTraitStatModifier

@export var stat: MTMonsterInstance.StatType

# Flat Bonus (z. B. +10 Strength)
@export var flat_bonus: int = 0

# Multiplier (z. B. 1.2 = +20 %)
@export_range(0.0, 5.0, 0.05)
var multiplier: float = 1.0
