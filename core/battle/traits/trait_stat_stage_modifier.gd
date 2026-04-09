extends Resource
class_name MTTraitStatStageModifier

@export var stat: MTMonsterInstance.StatType

# Stage Change (z.B. -1 = eine Stufe senken, +2 = zwei Stufen erhöhen)
@export_range(-6, 6)
var stage_change: int = 0
