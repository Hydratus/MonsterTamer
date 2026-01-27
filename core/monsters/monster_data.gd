extends Resource
class_name MonsterData

# Growth rate enum - wie schnell das Monster levelt
enum GrowthType {
	FAST,       # Schnell - Level × 100 EXP
	NORMAL,     # Normal - Level × 150 EXP
	SLOW,       # Langsam - Level × 200 EXP
	VERY_SLOW   # Sehr langsam - Level × 250 EXP
}

@export var name: String

# BASE STATS
@export var base_max_hp: int = 20
@export var base_max_energy: int = 10
@export var base_strength: int = 5
@export var base_magic: int = 5
@export var base_defense: int = 5
@export var base_resistance: int = 5
@export var base_speed: int = 10

# LIFESTEAL
@export_range(0.0, 1.0, 0.01)
var base_lifesteal: float = 0.0

# LEVEL
@export_range(1, 100)
var level: int = 1

# EXPERIENCE
@export_range(10, 1000)
var base_exp: int = 100
@export var growth_rate: GrowthType = GrowthType.NORMAL

# ELEMENTS
@export var elements: Array[Element.Type] = []

# ATTACKS
@export var attacks: Array[AttackData] = []

# TRAITS
@export var passive_traits: Array[TraitData] = []

# EVOLUTION
@export var evolution: Resource

# ATTACK LEARNING
@export var learnable_attacks: Array[Resource] = []

# TRAIT LEARNING
@export var learnable_traits: Array[Resource] = []
