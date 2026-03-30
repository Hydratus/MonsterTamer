extends Resource
class_name MTStatChangeData

@export var stat: MTMonsterInstance.StatType
@export_range(-5, 5) var stages: int = 0
@export var target_self: bool = false
