extends RefCounted
class_name MTItemDB

var _items_cache: Array[MTItemData] = []
var _items_by_id_cache: Dictionary = {}

func get_all_items() -> Array[MTItemData]:
	if _items_cache.is_empty():
		_items_cache = [
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
		_build_id_cache()
	return _items_cache

func get_item(item_id: String) -> MTItemData:
	if _items_by_id_cache.is_empty():
		get_all_items()  # Ensures cache is built
	return _items_by_id_cache.get(item_id, null)

func has_item(item_id: String) -> bool:
	return get_item(item_id) != null

func filter_valid_item_ids(item_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item_id in item_ids:
		if has_item(item_id):
			result.append(item_id)
	return result

func _build_id_cache() -> void:
	_items_by_id_cache.clear()
	for item in _items_cache:
		if item != null and item.id != "":
			_items_by_id_cache[item.id] = item
