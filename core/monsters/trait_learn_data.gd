extends Resource
class_name TraitLearnData

# Der Trait der gelernt wird
@export var trait_data: Resource

# Das Level, bei dem der Trait gelernt wird
@export_range(1, 100)
var learn_level: int = 1
