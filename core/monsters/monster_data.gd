extends Resource
class_name MonsterData

@export var name: String

# ------------------------
# BASE STATS
# ------------------------
@export var base_max_hp: int = 20
@export var base_max_energy: int = 10

@export var base_strength: int = 5
@export var base_magic: int = 5

@export var base_defense: int = 5
@export var base_resistance: int = 5

@export var base_speed: int = 10

# 🆕 LIFESTEAL (0.0 = 0 %)
@export_range(0.0, 1.0, 0.01)
var base_lifesteal: float = 0.0

# ------------------------
# LEVEL
# ------------------------
@export_range(1, 100)
var level: int = 1

# ------------------------
# ELEMENTS
# ------------------------
@export var elements: Array[Element.Type] = []

# ------------------------
# ATTACKS
# ------------------------
@export var attacks: Array[AttackData] = []

# ------------------------
# TRAITS
# ------------------------
@export var passive_traits: Array[TraitData] = []

# ------------------------
# EVOLUTION
# ------------------------
@export var evolution: Resource

# ------------------------
# ATTACK LEARNING
# ------------------------
@export var learnable_attacks: Array[Resource] = []

# ------------------------
# TRAIT LEARNING
# ------------------------
@export var learnable_traits: Array[Resource] = []
