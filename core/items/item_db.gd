extends RefCounted
class_name MTItemDB

func get_all_items() -> Array[MTItemData]:
	return [
		preload("res://data/items/SecretKey.tres"),
		preload("res://data/items/MonsterEgg.tres"),
		preload("res://data/items/LesserHealingPotion.tres"),
		preload("res://data/items/LesserUniversalBindingRune.tres"),
		preload("res://data/items/LesserNormalBindingRune.tres"),
		preload("res://data/items/LesserFireBindingRune.tres"),
		preload("res://data/items/LesserPlantBindingRune.tres"),
		preload("res://data/items/LesserWaterBindingRune.tres"),
		preload("res://data/items/LesserGhostBindingRune.tres"),
		preload("res://data/items/ImprovedUniversalBindingRune.tres"),
		preload("res://data/items/ImprovedNormalBindingRune.tres"),
		preload("res://data/items/ImprovedFireBindingRune.tres"),
		preload("res://data/items/ImprovedPlantBindingRune.tres"),
		preload("res://data/items/ImprovedWaterBindingRune.tres"),
		preload("res://data/items/ImprovedGhostBindingRune.tres"),
		preload("res://data/items/GreaterUniversalBindingRune.tres"),
		preload("res://data/items/GreaterNormalBindingRune.tres"),
		preload("res://data/items/GreaterFireBindingRune.tres"),
		preload("res://data/items/GreaterPlantBindingRune.tres"),
		preload("res://data/items/GreaterWaterBindingRune.tres"),
		preload("res://data/items/GreaterGhostBindingRune.tres"),
		preload("res://data/items/SuperiorUniversalBindingRune.tres"),
		preload("res://data/items/SuperiorNormalBindingRune.tres"),
		preload("res://data/items/SuperiorFireBindingRune.tres"),
		preload("res://data/items/SuperiorPlantBindingRune.tres"),
		preload("res://data/items/SuperiorWaterBindingRune.tres"),
		preload("res://data/items/SuperiorGhostBindingRune.tres"),
		preload("res://data/items/MythicUniversalBindingRune.tres"),
		preload("res://data/items/MythicNormalBindingRune.tres"),
		preload("res://data/items/MythicFireBindingRune.tres"),
		preload("res://data/items/MythicPlantBindingRune.tres"),
		preload("res://data/items/MythicWaterBindingRune.tres"),
		preload("res://data/items/MythicGhostBindingRune.tres"),
		preload("res://data/items/LegendaryUniversalBindingRune.tres"),
		preload("res://data/items/LegendaryNormalBindingRune.tres"),
		preload("res://data/items/LegendaryFireBindingRune.tres"),
		preload("res://data/items/LegendaryPlantBindingRune.tres"),
		preload("res://data/items/LegendaryWaterBindingRune.tres"),
		preload("res://data/items/LegendaryGhostBindingRune.tres")
	]

func get_item(item_id: String) -> MTItemData:
	for item in get_all_items():
		if item.id == item_id:
			return item
	return null
