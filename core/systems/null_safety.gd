class_name NullSafety

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

## Standard validation helper for common null checks
## Returns true if object is valid and ready for use

## Validate single object
static func is_valid(obj: Variant) -> bool:
	return obj != null

## Validate array of objects
static func all_valid(objects: Array) -> bool:
	for obj in objects:
		if obj == null:
			return false
	return true

## Validate array element at index
static func is_valid_index(array: Array, index: int) -> bool:
	return index >= 0 and index < array.size()

## Validate typed array element at index with type checking
static func is_valid_typed_index(array: Array, index: int, element_type: StringName) -> bool:
	if not is_valid_index(array, index):
		return false
	var element = array[index]
	return element != null and element.is_class(element_type)

## Get element safely with fallback
static func get_safe(array: Array, index: int, default: Variant = null) -> Variant:
	if is_valid_index(array, index):
		return array[index]
	return default

## Validate dictionary key exists and has valid value
static func has_valid_key(dict: Dictionary, key: Variant) -> bool:
	return dict.has(key) and dict[key] != null

## Log error if validation fails (used in critical paths)
static func assert_valid(obj: Variant, context: String = "") -> bool:
	if obj == null:
		if context != "":
			DEBUG_LOG.error("NullSafety", "Null reference in context: %s" % context)
		else:
			DEBUG_LOG.error("NullSafety", "Null reference detected")
		return false
	return true

## Check if Monster instance is alive and valid
static func is_valid_monster(monster: Variant) -> bool:
	if monster == null:
		return false
	if not monster is MTMonsterInstance:
		return false
	return monster.is_alive()

## Check if array has valid alive monsters
static func has_valid_monsters(monsters: Array) -> bool:
	if monsters == null or monsters.is_empty():
		return false
	for m in monsters:
		if m != null and is_valid_monster(m):
			return true
	return false
