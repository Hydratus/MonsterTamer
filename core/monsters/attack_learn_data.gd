extends Resource
class_name AttackLearnData

# Die Attacke die gelernt wird
@export var attack: Resource

# Das Level, bei dem die Attacke gelernt wird
@export_range(1, 100)
var learn_level: int = 1
