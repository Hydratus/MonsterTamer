extends Resource
class_name AttackData

@export var name: String

@export var power: int = 5
@export var energy_cost: int = 1
@export var accuracy: int = 100
@export var priority: int = 0

@export_range(0.0, 1.0)
var crit_rate: float = 0.10

@export var element: Element.Type = Element.Type.NORMAL
@export var damage_type: DamageType.Type = DamageType.Type.PHYSICAL

# 🆕 ATTACK LIFESTEAL
@export_range(0.0, 1.0, 0.01)
var lifesteal: float = 0.0

@export var stat_changes: Array[StatChangeData] = []
