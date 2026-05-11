extends Resource
class_name MTAttackData

const StatusAilmentClass = preload("res://core/battle/status/status_ailment.gd")

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

# Fraction of dealt damage reflected back to the user as recoil.
@export_range(0.0, 1.0, 0.01)
var recoil_ratio: float = 0.0

@export var stat_changes: Array[MTStatChangeData] = []

# Chance for stat changes to trigger (1.0 = always).
@export_range(0.0, 1.0, 0.01)
var stat_change_chance: float = 1.0

# Optional status application package (used after hit confirmation).
@export var status_effect: int = StatusAilmentClass.Type.NONE
@export_range(0.0, 1.0, 0.01)
var status_chance: float = 0.0
@export_range(0, 8, 1)
var status_duration: int = 0
@export var status_target_self: bool = false
