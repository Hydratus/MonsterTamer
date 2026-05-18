extends Resource
class_name MTItemData

enum Category {
	ACTIVE = 0,
	SOULBINDER = 1,
	BINDING_RUNES = 1,
	WEAPON = 2,
	ARMOR = 3,
	ACCESSOIRE = 4
}

enum RuneTier {
	LESSER,
	IMPROVED,
	GREATER,
	SUPERIOR,
	MYTHIC,
	LEGENDARY
}

enum RuneElement {
	UNIVERSAL = -1,
	FIRE = 1,
	PLANT = 2,
	WATER = 3,
	UNDEAD = 4,
	ELECTRIC = 5,
	SOUND = 6,
	COSMIC = 7,
	HOLY = 8,
	POISON = 9,
	METAL = 10,
	DRAGON = 11,
	AIR = 12,
	BEAST = 13,
	EARTH = 14,
	ICE = 15
}

enum TargetType {
	SELF_TEAM,
	ENEMY
}

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var category: int = Category.ACTIVE
@export var target_type: int = TargetType.SELF_TEAM
@export var battle_usable: bool = true
@export var overworld_usable: bool = true
@export var consumable: bool = true
@export var heal_min: int = 0
@export var heal_max: int = 0
@export var rune_tier: int = RuneTier.LESSER
@export var rune_element: int = RuneElement.UNIVERSAL

func get_rune_tier_multiplier() -> float:
	match rune_tier:
		RuneTier.IMPROVED:
			return 1.2
		RuneTier.GREATER:
			return 1.4
		RuneTier.SUPERIOR:
			return 1.7
		RuneTier.MYTHIC:
			return 2.0
		RuneTier.LEGENDARY:
			return 2.5
		_:
			return 1.0

