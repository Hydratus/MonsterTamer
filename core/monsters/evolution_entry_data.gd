extends Resource
class_name MTEvolutionEntryData

@export var target_monster: MTMonsterData
@export_range(1, 100)
var min_level: int = 1
@export var label: String = ""

@export var required_attack: MTAttackData
@export var required_trait: MTTraitData

@export var required_item_id: String = ""
@export var required_item_ids: PackedStringArray = PackedStringArray()

@export var required_elements: Array[int] = []

@export var required_flag: String = ""
@export var required_flags: PackedStringArray = PackedStringArray()