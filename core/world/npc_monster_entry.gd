extends Resource
class_name NPCMonsterEntry

@export var monster_data: MonsterData
@export var level: int = -1
@export var attacks_override: Array[AttackData] = []
@export var traits_override: Array[TraitData] = []
