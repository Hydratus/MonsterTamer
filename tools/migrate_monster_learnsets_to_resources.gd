extends SceneTree

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const MONSTER_ROOT := "res://data/monsters"

const AttackLearnDataClass = preload("res://core/monsters/attack_learn_data.gd")
const TraitLearnDataClass = preload("res://core/monsters/trait_learn_data.gd")

func _init() -> void:
	var converted_count := 0
	var paths := _collect_monster_paths(MONSTER_ROOT)
	paths.sort()
	for monster_path in paths:
		var monster_res := load(monster_path)
		if monster_res == null or not monster_res is MTMonsterData:
			continue
		var monster: MTMonsterData = monster_res
		var changed := false
		var converted_attacks := _convert_attack_entries(monster.learnable_attacks)
		if bool(converted_attacks.get("changed", false)):
			monster.learnable_attacks = converted_attacks.get("entries", [])
			changed = true
		var converted_traits := _convert_trait_entries(monster.learnable_traits)
		if bool(converted_traits.get("changed", false)):
			monster.learnable_traits = converted_traits.get("entries", [])
			changed = true
		if not changed:
			continue
		var save_result := ResourceSaver.save(monster, monster_path)
		if save_result != OK:
			DEBUG_LOG.error("LearnsetMigration", "Failed to save %s" % monster_path)
			continue
		converted_count += 1
		DEBUG_LOG.debug(true, "LearnsetMigration", "Converted learnsets in %s" % monster_path)
	DEBUG_LOG.debug(true, "LearnsetMigration", "Finished conversion. Updated monsters: %d" % converted_count)
	quit(0)

func _collect_monster_paths(root_path: String) -> Array[String]:
	var collected: Array[String] = []
	_collect_recursive(root_path, collected)
	return collected

func _collect_recursive(path: String, collected: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var entry_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_collect_recursive(entry_path, collected)
		elif entry.to_lower().ends_with(".tres"):
			collected.append(entry_path)
	dir.list_dir_end()

func _convert_attack_entries(source: Array) -> Dictionary:
	var changed := false
	var entries: Array = []
	for raw_entry in source:
		if raw_entry == null:
			changed = true
			continue
		if raw_entry is MTAttackLearnData:
			entries.append(raw_entry)
			continue
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var attack: MTAttackData = entry.get("attack", null)
			if attack == null:
				changed = true
				continue
			var resource: MTAttackLearnData = AttackLearnDataClass.new()
			resource.attack = attack
			resource.learn_level = max(1, int(entry.get("learn_level", 1)))
			entries.append(resource)
			changed = true
			continue
		if raw_entry is Resource:
			var attack_resource = raw_entry.get("attack")
			if attack_resource == null:
				changed = true
				continue
			var fallback_resource: MTAttackLearnData = AttackLearnDataClass.new()
			fallback_resource.attack = attack_resource
			fallback_resource.learn_level = max(1, int(raw_entry.get("learn_level") if raw_entry.get("learn_level") != null else 1))
			entries.append(fallback_resource)
			changed = true
			continue
		changed = true
	if entries.size() != source.size():
		changed = true
	return {"changed": changed, "entries": entries}

func _convert_trait_entries(source: Array) -> Dictionary:
	var changed := false
	var entries: Array = []
	for raw_entry in source:
		if raw_entry == null:
			changed = true
			continue
		if raw_entry is MTTraitLearnData:
			entries.append(raw_entry)
			continue
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			var trait_data: MTTraitData = entry.get("trait_data", entry.get("trait", null))
			if trait_data == null:
				changed = true
				continue
			var resource: MTTraitLearnData = TraitLearnDataClass.new()
			resource.trait_data = trait_data
			resource.learn_level = max(1, int(entry.get("learn_level", 1)))
			entries.append(resource)
			changed = true
			continue
		if raw_entry is Resource:
			var trait_resource = raw_entry.get("trait_data")
			if trait_resource == null:
				trait_resource = raw_entry.get("trait")
			if trait_resource == null:
				changed = true
				continue
			var fallback_resource: MTTraitLearnData = TraitLearnDataClass.new()
			fallback_resource.trait_data = trait_resource
			fallback_resource.learn_level = max(1, int(raw_entry.get("learn_level") if raw_entry.get("learn_level") != null else 1))
			entries.append(fallback_resource)
			changed = true
			continue
		changed = true
	if entries.size() != source.size():
		changed = true
	return {"changed": changed, "entries": entries}