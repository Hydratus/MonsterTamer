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
			preload("res://data/items/ImprovedUniversalBindingRune.tres"),
			preload("res://data/items/GreaterUniversalBindingRune.tres"),
			preload("res://data/items/SuperiorUniversalBindingRune.tres"),
			preload("res://data/items/MythicUniversalBindingRune.tres"),
			preload("res://data/items/LegendaryUniversalBindingRune.tres"),
			preload("res://data/items/LesserFireBindingRune.tres"),
			preload("res://data/items/LesserPlantBindingRune.tres"),
			preload("res://data/items/LesserWaterBindingRune.tres"),
			preload("res://data/items/LesserUndeadBindingRune.tres"),
			preload("res://data/items/LesserElectricBindingRune.tres"),
			preload("res://data/items/LesserSoundBindingRune.tres"),
			preload("res://data/items/LesserCosmicBindingRune.tres"),
			preload("res://data/items/LesserHolyBindingRune.tres"),
			preload("res://data/items/LesserPoisonBindingRune.tres"),
			preload("res://data/items/LesserMetalBindingRune.tres"),
			preload("res://data/items/LesserDragonBindingRune.tres"),
			preload("res://data/items/LesserAirBindingRune.tres"),
			preload("res://data/items/LesserBeastBindingRune.tres"),
			preload("res://data/items/LesserEarthBindingRune.tres"),
			preload("res://data/items/LesserIceBindingRune.tres"),
			preload("res://data/items/ImprovedFireBindingRune.tres"),
			preload("res://data/items/ImprovedPlantBindingRune.tres"),
			preload("res://data/items/ImprovedWaterBindingRune.tres"),
			preload("res://data/items/ImprovedUndeadBindingRune.tres"),
			preload("res://data/items/ImprovedElectricBindingRune.tres"),
			preload("res://data/items/ImprovedSoundBindingRune.tres"),
			preload("res://data/items/ImprovedCosmicBindingRune.tres"),
			preload("res://data/items/ImprovedHolyBindingRune.tres"),
			preload("res://data/items/ImprovedPoisonBindingRune.tres"),
			preload("res://data/items/ImprovedMetalBindingRune.tres"),
			preload("res://data/items/ImprovedDragonBindingRune.tres"),
			preload("res://data/items/ImprovedAirBindingRune.tres"),
			preload("res://data/items/ImprovedBeastBindingRune.tres"),
			preload("res://data/items/ImprovedEarthBindingRune.tres"),
			preload("res://data/items/ImprovedIceBindingRune.tres"),
			preload("res://data/items/GreaterFireBindingRune.tres"),
			preload("res://data/items/GreaterPlantBindingRune.tres"),
			preload("res://data/items/GreaterWaterBindingRune.tres"),
			preload("res://data/items/GreaterUndeadBindingRune.tres"),
			preload("res://data/items/GreaterElectricBindingRune.tres"),
			preload("res://data/items/GreaterSoundBindingRune.tres"),
			preload("res://data/items/GreaterCosmicBindingRune.tres"),
			preload("res://data/items/GreaterHolyBindingRune.tres"),
			preload("res://data/items/GreaterPoisonBindingRune.tres"),
			preload("res://data/items/GreaterMetalBindingRune.tres"),
			preload("res://data/items/GreaterDragonBindingRune.tres"),
			preload("res://data/items/GreaterAirBindingRune.tres"),
			preload("res://data/items/GreaterBeastBindingRune.tres"),
			preload("res://data/items/GreaterEarthBindingRune.tres"),
			preload("res://data/items/GreaterIceBindingRune.tres"),
			preload("res://data/items/SuperiorFireBindingRune.tres"),
			preload("res://data/items/SuperiorPlantBindingRune.tres"),
			preload("res://data/items/SuperiorWaterBindingRune.tres"),
			preload("res://data/items/SuperiorUndeadBindingRune.tres"),
			preload("res://data/items/SuperiorElectricBindingRune.tres"),
			preload("res://data/items/SuperiorSoundBindingRune.tres"),
			preload("res://data/items/SuperiorCosmicBindingRune.tres"),
			preload("res://data/items/SuperiorHolyBindingRune.tres"),
			preload("res://data/items/SuperiorPoisonBindingRune.tres"),
			preload("res://data/items/SuperiorMetalBindingRune.tres"),
			preload("res://data/items/SuperiorDragonBindingRune.tres"),
			preload("res://data/items/SuperiorAirBindingRune.tres"),
			preload("res://data/items/SuperiorBeastBindingRune.tres"),
			preload("res://data/items/SuperiorEarthBindingRune.tres"),
			preload("res://data/items/SuperiorIceBindingRune.tres"),
			preload("res://data/items/MythicFireBindingRune.tres"),
			preload("res://data/items/MythicPlantBindingRune.tres"),
			preload("res://data/items/MythicWaterBindingRune.tres"),
			preload("res://data/items/MythicUndeadBindingRune.tres"),
			preload("res://data/items/MythicElectricBindingRune.tres"),
			preload("res://data/items/MythicSoundBindingRune.tres"),
			preload("res://data/items/MythicCosmicBindingRune.tres"),
			preload("res://data/items/MythicHolyBindingRune.tres"),
			preload("res://data/items/MythicPoisonBindingRune.tres"),
			preload("res://data/items/MythicMetalBindingRune.tres"),
			preload("res://data/items/MythicDragonBindingRune.tres"),
			preload("res://data/items/MythicAirBindingRune.tres"),
			preload("res://data/items/MythicBeastBindingRune.tres"),
			preload("res://data/items/MythicEarthBindingRune.tres"),
			preload("res://data/items/MythicIceBindingRune.tres"),
			preload("res://data/items/LegendaryFireBindingRune.tres"),
			preload("res://data/items/LegendaryPlantBindingRune.tres"),
			preload("res://data/items/LegendaryWaterBindingRune.tres"),
			preload("res://data/items/LegendaryUndeadBindingRune.tres"),
			preload("res://data/items/LegendaryElectricBindingRune.tres"),
			preload("res://data/items/LegendarySoundBindingRune.tres"),
			preload("res://data/items/LegendaryCosmicBindingRune.tres"),
			preload("res://data/items/LegendaryHolyBindingRune.tres"),
			preload("res://data/items/LegendaryPoisonBindingRune.tres"),
			preload("res://data/items/LegendaryMetalBindingRune.tres"),
			preload("res://data/items/LegendaryDragonBindingRune.tres"),
			preload("res://data/items/LegendaryAirBindingRune.tres"),
			preload("res://data/items/LegendaryBeastBindingRune.tres"),
			preload("res://data/items/LegendaryEarthBindingRune.tres"),
			preload("res://data/items/LegendaryIceBindingRune.tres")
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

func find_invalid_item_ids(item_ids: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for item_id in item_ids:
		if not has_item(item_id):
			result.append(item_id)
	return result

func _build_id_cache() -> void:
	_items_by_id_cache.clear()
	for item in _items_cache:
		if item != null and item.id != "":
			_items_by_id_cache[item.id] = item
