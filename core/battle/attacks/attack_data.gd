extends Resource
class_name MTAttackData

@export var name: String

@export_multiline var description: String = ""

@export var power: int = 5
@export var energy_cost: int = 1
@export var accuracy: int = 100
@export var priority: int = 0

@export_range(0.0, 1.0)
var crit_rate: float = 0.10

@export var element: MTElement.Type = MTElement.Type.FIRE
@export var damage_type: MTDamageType.Type = MTDamageType.Type.PHYSICAL
@export var makes_contact: bool = false
@export var requires_contact_for_effect: bool = false

# 🆕 ATTACK LIFESTEAL
@export_range(0.0, 1.0, 0.01)
var lifesteal: float = 0.0

@export var stat_changes: Array[MTStatChangeData] = []
