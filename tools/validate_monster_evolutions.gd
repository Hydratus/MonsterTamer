extends SceneTree

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const MonsterDataClass = preload("res://core/monsters/monster_data.gd")
const ItemDBClass = preload("res://core/items/item_db.gd")
const EvolutionEntryDataClass = preload("res://core/monsters/evolution_entry_data.gd")

const VALIDATOR_LOGS_ENABLED := true
const MONSTER_ROOT := "res://data/monsters"

var _item_db := ItemDBClass.new()

func _init() -> void:
	var options: Dictionary = _parse_options()
	var results: Dictionary = run_validation(options)
	_print_human_readable_results(results)
	DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidatorJSON", JSON.stringify(results))
	if bool(results.get("all_passed", false)):
		quit(0)
	else:
		quit(1)

func _parse_options() -> Dictionary:
	var options := {
		"fix": false,
		"warnings": true
	}
	for arg in OS.get_cmdline_user_args():
		match str(arg):
			"--fix":
				options["fix"] = true
			"--no-warnings":
				options["warnings"] = false
	return options

func run_validation(options: Dictionary = {}) -> Dictionary:
	var results := {
		"all_passed": true,
		"checked_monsters": 0,
		"failed_monsters": 0,
		"warning_monsters": 0,
		"fixed_monsters": 0,
		"issues": {},
		"warnings": {},
		"fixes": {}
	}
	var monster_paths: Array[String] = _collect_monster_paths(MONSTER_ROOT)
	monster_paths.sort()
	var auto_fix: bool = bool(options.get("fix", false))
	var include_warnings: bool = bool(options.get("warnings", true))
	for monster_path in monster_paths:
		results["checked_monsters"] = int(results.get("checked_monsters", 0)) + 1
		var validation := _validate_monster(monster_path, auto_fix, include_warnings)
		var issues: Array[String] = validation.get("issues", [])
		var warnings: Array[String] = validation.get("warnings", [])
		var fixes: Array[String] = validation.get("fixes", [])
		if issues.is_empty():
			if not warnings.is_empty():
				results["warning_monsters"] = int(results.get("warning_monsters", 0)) + 1
				results["warnings"][monster_path] = warnings
			if not fixes.is_empty():
				results["fixed_monsters"] = int(results.get("fixed_monsters", 0)) + 1
				results["fixes"][monster_path] = fixes
			continue
		results["failed_monsters"] = int(results.get("failed_monsters", 0)) + 1
		results["all_passed"] = false
		results["issues"][monster_path] = issues
		if not warnings.is_empty():
			results["warning_monsters"] = int(results.get("warning_monsters", 0)) + 1
			results["warnings"][monster_path] = warnings
		if not fixes.is_empty():
			results["fixed_monsters"] = int(results.get("fixed_monsters", 0)) + 1
			results["fixes"][monster_path] = fixes
	return results

func _collect_monster_paths(root_path: String) -> Array[String]:
	var collected: Array[String] = []
	_collect_monster_paths_recursive(root_path, collected)
	return collected

func _collect_monster_paths_recursive(path: String, collected: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		DEBUG_LOG.error("EvolutionValidator", "Unable to open directory: %s" % path)
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
			_collect_monster_paths_recursive(entry_path, collected)
		elif entry.to_lower().ends_with(".tres"):
			collected.append(entry_path)
	dir.list_dir_end()

func _validate_monster(monster_path: String, auto_fix: bool, include_warnings: bool) -> Dictionary:
	var issues: Array[String] = []
	var warnings: Array[String] = []
	var fixes: Array[String] = []
	var monster := load(monster_path)
	if monster == null:
		issues.append("Failed to load resource")
		return {"issues": issues, "warnings": warnings, "fixes": fixes}
	if not monster is MTMonsterData:
		return {"issues": issues, "warnings": warnings, "fixes": fixes}
	var monster_data := monster as MTMonsterData
	if auto_fix and not monster_data.evolutions.is_empty():
		var fixed := _normalized_evolutions(monster_data.evolutions)
		if bool(fixed.get("changed", false)):
			monster_data.evolutions = fixed.get("entries", [])
			fixes.append_array(fixed.get("fixes", []))
			var save_result := ResourceSaver.save(monster_data, monster_path)
			if save_result != OK:
				issues.append("Failed to save auto-fixed resource")
	if monster_data.evolution != null and not monster_data.evolutions.is_empty():
		issues.append("Uses both legacy evolution and inline evolutions")
	var inline_entries: Array[Dictionary] = []
	for raw_entry in monster_data.evolutions:
		var entry := _extract_evolution_data(raw_entry)
		if entry.is_empty():
			issues.append("Evolution entry is missing target monster")
			continue
		inline_entries.append(entry)
	issues.append_array(_validate_evolution_entries(monster_data, inline_entries))
	if monster_data.evolution != null:
		var legacy_entry := _extract_evolution_data(monster_data.evolution)
		if legacy_entry.is_empty():
			issues.append("Legacy evolution data is invalid")
		else:
			issues.append_array(_validate_evolution_entries(monster_data, [legacy_entry]))
			if include_warnings:
				warnings.append("Uses legacy evolution resource; prefer inline evolutions")
	if include_warnings:
		warnings.append_array(_build_evolution_warnings(inline_entries))
	return {"issues": issues, "warnings": warnings, "fixes": fixes}

func _extract_evolution_data(raw_entry) -> Dictionary:
	if raw_entry == null:
		return {}
	if _is_evolution_entry_resource(raw_entry):
		var target_monster: MTMonsterData = _resource_prop(raw_entry, "target_monster", null)
		if target_monster == null:
			return {}
		var normalized := {
			"target_monster": target_monster,
			"min_level": max(1, int(_resource_prop(raw_entry, "min_level", 1)))
		}
		var label := str(_resource_prop(raw_entry, "label", "")).strip_edges()
		if label != "":
			normalized["label"] = label
		var required_attack: MTAttackData = _resource_prop(raw_entry, "required_attack", null)
		if required_attack != null:
			normalized["required_attack"] = required_attack
		var required_trait: MTTraitData = _resource_prop(raw_entry, "required_trait", null)
		if required_trait != null:
			normalized["required_trait"] = required_trait
		var required_item_ids: Array[String] = []
		var single_item_id := str(_resource_prop(raw_entry, "required_item_id", "")).strip_edges()
		if single_item_id != "":
			required_item_ids.append(single_item_id)
		for item_value in _resource_prop(raw_entry, "required_item_ids", []):
			var item_id := str(item_value).strip_edges()
			if item_id != "" and not required_item_ids.has(item_id):
				required_item_ids.append(item_id)
		if not required_item_ids.is_empty():
			normalized["required_item_ids"] = required_item_ids
		var raw_required_elements: Array = _resource_prop(raw_entry, "required_elements", [])
		if not raw_required_elements.is_empty():
			var required_elements: Array[int] = []
			for element_value in raw_required_elements:
				required_elements.append(int(element_value))
			normalized["required_elements"] = required_elements
		var required_flags: Array[String] = []
		var single_flag := str(_resource_prop(raw_entry, "required_flag", "")).strip_edges()
		if single_flag != "":
			required_flags.append(single_flag)
		for flag_value in _resource_prop(raw_entry, "required_flags", []):
			var flag_name := str(flag_value).strip_edges()
			if flag_name != "" and not required_flags.has(flag_name):
				required_flags.append(flag_name)
		if not required_flags.is_empty():
			normalized["required_flags"] = required_flags
		return normalized
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var target_monster: MTMonsterData = entry.get("target_monster", entry.get("evolved_monster", entry.get("monster", null)))
		if target_monster == null:
			return {}
		var normalized := {
			"target_monster": target_monster,
			"min_level": max(1, int(entry.get("min_level", entry.get("evolution_level", 1))))
		}
		var label := str(entry.get("label", "")).strip_edges()
		if label != "":
			normalized["label"] = label
		var required_attack: MTAttackData = entry.get("required_attack", entry.get("attack", null))
		if required_attack != null:
			normalized["required_attack"] = required_attack
		var required_trait: MTTraitData = entry.get("required_trait", entry.get("trait_data", entry.get("trait", null)))
		if required_trait != null:
			normalized["required_trait"] = required_trait
		var required_item_ids: Array[String] = []
		for item_value in entry.get("required_item_ids", []):
			var item_id := str(item_value).strip_edges()
			if item_id != "":
				required_item_ids.append(item_id)
		var single_item_id := str(entry.get("required_item_id", "")).strip_edges()
		if single_item_id != "":
			required_item_ids.append(single_item_id)
		if not required_item_ids.is_empty():
			normalized["required_item_ids"] = required_item_ids
		var required_elements: Array[int] = []
		for element_value in entry.get("required_elements", []):
			required_elements.append(int(element_value))
		if not required_elements.is_empty():
			normalized["required_elements"] = required_elements
		var required_flags: Array[String] = []
		for flag_value in entry.get("required_flags", []):
			var flag_name := str(flag_value).strip_edges()
			if flag_name != "":
				required_flags.append(flag_name)
		var single_flag := str(entry.get("required_flag", "")).strip_edges()
		if single_flag != "":
			required_flags.append(single_flag)
		if not required_flags.is_empty():
			normalized["required_flags"] = required_flags
		return normalized
	var legacy_evolution := raw_entry as MTEvolutionData
	if legacy_evolution == null:
		return {}
	var legacy_target := legacy_evolution.evolved_monster as MTMonsterData
	if legacy_target == null:
		return {}
	return {
		"target_monster": legacy_target,
		"min_level": max(1, legacy_evolution.evolution_level)
	}

func _validate_evolution_entries(monster_data: MTMonsterData, evolution_entries: Array) -> Array[String]:
	var issues: Array[String] = []
	var seen_signatures: Dictionary = {}
	for raw_entry in evolution_entries:
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if entry.is_empty():
			continue
		var target_monster: MTMonsterData = entry.get("target_monster", null)
		if target_monster == null:
			issues.append("Evolution entry has no target monster")
			continue
		if target_monster == monster_data:
			issues.append("Evolution target points to the same monster")
		var min_level: int = int(entry.get("min_level", 1))
		if min_level < 1:
			issues.append("Evolution entry has invalid min_level %d" % min_level)
		for raw_item_id in entry.get("required_item_ids", []):
			var item_id := str(raw_item_id).strip_edges()
			if item_id == "":
				issues.append("Evolution entry has empty required_item_id")
			elif not _item_db.has_item(item_id):
				issues.append("Evolution entry uses unknown required_item_id: %s" % item_id)
		var signature := _evolution_signature(entry)
		if seen_signatures.has(signature):
			issues.append("Duplicate evolution entry: %s" % signature)
		else:
			seen_signatures[signature] = true
	return issues

func _build_evolution_warnings(evolution_entries: Array[Dictionary]) -> Array[String]:
	var warnings: Array[String] = []
	if evolution_entries.size() <= 1:
		return warnings
	var unconditional_count := 0
	var item_trigger_counts: Dictionary = {}
	for entry in evolution_entries:
		var has_specific_trigger := false
		if entry.has("required_attack") or entry.has("required_trait") or entry.has("required_elements") or entry.has("required_flags"):
			has_specific_trigger = true
		var required_item_ids: Array = entry.get("required_item_ids", [])
		if not required_item_ids.is_empty():
			has_specific_trigger = true
			for raw_item_id in required_item_ids:
				var item_id := str(raw_item_id)
				item_trigger_counts[item_id] = int(item_trigger_counts.get(item_id, 0)) + 1
		if not has_specific_trigger:
			unconditional_count += 1
	if unconditional_count > 1:
		warnings.append("Multiple unconditional evolutions may be ambiguous")
	for item_id in item_trigger_counts.keys():
		var count: int = int(item_trigger_counts.get(item_id, 0))
		if count > 1:
			warnings.append("Multiple evolutions share required_item_id %s" % str(item_id))
	return warnings

func _normalized_evolutions(source: Array) -> Dictionary:
	var changed := false
	var fixes: Array[String] = []
	var normalized: Array[Dictionary] = []
	for raw_entry in source:
		var entry := _extract_evolution_data(raw_entry)
		if entry.is_empty():
			changed = true
			fixes.append("Removed evolution entry with missing target monster")
			continue
		var normalized_entry := {
			"target_monster": entry.get("target_monster", null),
			"min_level": max(1, int(entry.get("min_level", 1)))
		}
		if int(entry.get("min_level", 1)) != int(normalized_entry.get("min_level", 1)):
			changed = true
			fixes.append("Clamped evolution min_level below 1")
		var label := str(entry.get("label", "")).strip_edges()
		if label != "":
			normalized_entry["label"] = label
		var required_attack: MTAttackData = entry.get("required_attack", null)
		if required_attack != null:
			normalized_entry["required_attack"] = required_attack
		var required_trait: MTTraitData = entry.get("required_trait", null)
		if required_trait != null:
			normalized_entry["required_trait"] = required_trait
		var required_item_ids: Array[String] = []
		for raw_item_id in entry.get("required_item_ids", []):
			var item_id := str(raw_item_id).strip_edges()
			if item_id == "":
				continue
			if not required_item_ids.has(item_id):
				required_item_ids.append(item_id)
		if required_item_ids.size() == 1:
			normalized_entry["required_item_id"] = required_item_ids[0]
		elif required_item_ids.size() > 1:
			normalized_entry["required_item_ids"] = required_item_ids
		var required_elements: Array[int] = []
		for raw_element in entry.get("required_elements", []):
			var element_value := int(raw_element)
			if not required_elements.has(element_value):
				required_elements.append(element_value)
		if not required_elements.is_empty():
			normalized_entry["required_elements"] = required_elements
		var required_flags: Array[String] = []
		for raw_flag in entry.get("required_flags", []):
			var flag_name := str(raw_flag).strip_edges()
			if flag_name != "" and not required_flags.has(flag_name):
				required_flags.append(flag_name)
		if required_flags.size() == 1:
			normalized_entry["required_flag"] = required_flags[0]
		elif required_flags.size() > 1:
			normalized_entry["required_flags"] = required_flags
		normalized.append(normalized_entry)
	var source_signatures: Array[String] = []
	for raw_entry in source:
		source_signatures.append(_evolution_signature(_extract_evolution_data(raw_entry)))
	var seen_signatures: Dictionary = {}
	var deduped: Array[Dictionary] = []
	for entry in normalized:
		var signature := _evolution_signature(entry)
		if seen_signatures.has(signature):
			changed = true
			fixes.append("Removed duplicate evolution entry: %s" % signature)
			continue
		seen_signatures[signature] = true
		deduped.append(entry)
	deduped.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_level: int = int(a.get("min_level", 1))
		var b_level: int = int(b.get("min_level", 1))
		if a_level == b_level:
			return _resource_identity(a.get("target_monster", null)) < _resource_identity(b.get("target_monster", null))
		return a_level < b_level
	)
	var normalized_signatures: Array[String] = []
	for entry in deduped:
		normalized_signatures.append(_evolution_signature(entry))
	if source_signatures != normalized_signatures:
		changed = true
		if not fixes.has("Sorted evolutions by min_level"):
			fixes.append("Sorted evolutions by min_level")
	return {"changed": changed, "entries": _build_evolution_resource_entries(deduped), "fixes": fixes}

func _build_evolution_resource_entries(entries: Array[Dictionary]) -> Array[Resource]:
	var result: Array[Resource] = []
	for entry in entries:
		result.append(_build_evolution_resource_entry(entry))
	return result

func _build_evolution_resource_entry(entry: Dictionary) -> Resource:
	var resource := EvolutionEntryDataClass.new()
	resource.target_monster = entry.get("target_monster", null)
	resource.min_level = max(1, int(entry.get("min_level", 1)))
	resource.label = str(entry.get("label", "")).strip_edges()
	resource.required_attack = entry.get("required_attack", null)
	resource.required_trait = entry.get("required_trait", null)
	var required_item_ids: Array[String] = []
	for raw_item_id in entry.get("required_item_ids", []):
		var item_id := str(raw_item_id).strip_edges()
		if item_id != "" and not required_item_ids.has(item_id):
			required_item_ids.append(item_id)
	if required_item_ids.size() == 1:
		resource.required_item_id = required_item_ids[0]
		resource.required_item_ids = PackedStringArray()
	else:
		resource.required_item_id = ""
		resource.required_item_ids = PackedStringArray(required_item_ids)
	var required_elements: Array[int] = []
	for raw_element in entry.get("required_elements", []):
		required_elements.append(int(raw_element))
	resource.required_elements = required_elements
	var required_flags: Array[String] = []
	for raw_flag in entry.get("required_flags", []):
		var flag_name := str(raw_flag).strip_edges()
		if flag_name != "" and not required_flags.has(flag_name):
			required_flags.append(flag_name)
	if required_flags.size() == 1:
		resource.required_flag = required_flags[0]
		resource.required_flags = PackedStringArray()
	else:
		resource.required_flag = ""
		resource.required_flags = PackedStringArray(required_flags)
	return resource

func _is_evolution_entry_resource(raw_entry) -> bool:
	if not raw_entry is Resource:
		return false
	var script_resource: Script = raw_entry.get_script()
	if script_resource == null:
		return false
	return script_resource.resource_path == "res://core/monsters/evolution_entry_data.gd"

func _resource_prop(resource: Resource, property_name: String, default_value = null):
	if resource == null:
		return default_value
	var value = resource.get(property_name)
	if value == null:
		return default_value
	return value

func _resource_identity(resource: Resource) -> String:
	if resource == null:
		return "<null>"
	if resource.resource_path != "":
		return resource.resource_path
	return str(resource)

func _evolution_signature(entry: Dictionary) -> String:
	if entry.is_empty():
		return "<empty>"
	var bits: Array[String] = []
	bits.append(_resource_identity(entry.get("target_monster", null)))
	bits.append(str(int(entry.get("min_level", 1))))
	bits.append(_resource_identity(entry.get("required_attack", null)))
	bits.append(_resource_identity(entry.get("required_trait", null)))
	var item_ids: Array[String] = []
	for raw_item_id in entry.get("required_item_ids", []):
		item_ids.append(str(raw_item_id))
	item_ids.sort()
	bits.append("|".join(item_ids))
	var elements: Array[String] = []
	for raw_element in entry.get("required_elements", []):
		elements.append(str(int(raw_element)))
	elements.sort()
	bits.append("|".join(elements))
	var flags: Array[String] = []
	for raw_flag in entry.get("required_flags", []):
		flags.append(str(raw_flag))
	flags.sort()
	bits.append("|".join(flags))
	return "::".join(bits)

func _print_human_readable_results(results: Dictionary) -> void:
	var checked: int = int(results.get("checked_monsters", 0))
	var failed: int = int(results.get("failed_monsters", 0))
	var warned: int = int(results.get("warning_monsters", 0))
	var fixed: int = int(results.get("fixed_monsters", 0))
	var issues: Dictionary = results.get("issues", {})
	var warnings: Dictionary = results.get("warnings", {})
	var fixes: Dictionary = results.get("fixes", {})
	if fixed > 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "Auto-fixed evolutions in %d monsters." % fixed)
	if failed <= 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "Monster evolution validation passed for %d monsters." % checked)
		if warned > 0:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "Warnings found in %d/%d monsters." % [warned, checked])
			_print_detail_block("WARN", warnings)
		return
	DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "Monster evolution validation found issues in %d/%d monsters." % [failed, checked])
	_print_detail_block("FAIL", issues)
	if warned > 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "Warnings found in %d/%d monsters." % [warned, checked])
		_print_detail_block("WARN", warnings)
	if fixed > 0:
		_print_detail_block("FIXED", fixes)

func _print_detail_block(label: String, details: Dictionary) -> void:
	var paths: Array[String] = []
	for path in details.keys():
		paths.append(str(path))
	paths.sort()
	for monster_path in paths:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "%s - %s" % [label, monster_path])
		var detail_list: Array = details.get(monster_path, [])
		for detail in detail_list:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "EvolutionValidator", "  - %s" % str(detail))