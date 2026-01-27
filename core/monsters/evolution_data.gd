extends Resource
class_name EvolutionData

# Das Monster, zu dem sich entwickelt wird
@export var evolved_monster: Resource

# Das Level, bei dem sich das Monster entwickeln kann
@export_range(1, 100)
var evolution_level: int = 1
