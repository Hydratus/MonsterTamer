extends SceneTree

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const MonsterDataClass = preload("res://core/monsters/monster_data.gd")
const BalanceConstants = preload("res://core/systems/game_balance_constants.gd")

const VALIDATOR_LOGS_ENABLED := true
const MONSTER_ROOT := "res://data/monsters"
const EARLY_ROLE_WINDOW_LEVEL := 10
const EARLY_ROLE_DUPLICATE_THRESHOLD := 3
const ATTACK_GAP_WARNING_THRESHOLD := 12
const TRAIT_GAP_WARNING_THRESHOLD := 15
const HIGH_LEVEL_INCENTIVE_THRESHOLD := 15

func _init() -> void:
	var options: Dictionary = _parse_options()
	var results: Dictionary = run_validation(options)
	_print_human_readable_results(results)
	DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidatorJSON", JSON.stringify(results))
	if bool(results.get("all_passed", false)):
		quit(0)
	else:
		quit(1)

func _parse_options() -> Dictionary:
	var options := {
		"fix": false,
		"balance_warnings": true
	}
	for arg in OS.get_cmdline_user_args():
		match str(arg):
			"--fix":
				options["fix"] = true
			"--no-balance-warnings":
				options["balance_warnings"] = false
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
	var include_balance_warnings: bool = bool(options.get("balance_warnings", true))
	for monster_path in monster_paths:
		results["checked_monsters"] = int(results.get("checked_monsters", 0)) + 1
		var validation := _validate_monster(monster_path, auto_fix, include_balance_warnings)
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
		DEBUG_LOG.error("LearnsetValidator", "Unable to open directory: %s" % path)
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

func _validate_monster(monster_path: String, auto_fix: bool, include_balance_warnings: bool) -> Dictionary:
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
	var display_name := monster_data.name if monster_data.name != "" else monster_path.get_file().trim_suffix(".tres")
	if auto_fix:
		fixes = _auto_fix_monster(monster_data)
		if not fixes.is_empty():
			var save_result := ResourceSaver.save(monster_data, monster_path)
			if save_result != OK:
				issues.append("Failed to save auto-fixed resource")

	if not monster_data.attacks.is_empty():
		issues.append("Direct attacks list is not empty")
	if not monster_data.passive_traits.is_empty():
		issues.append("Direct passive_traits list is not empty")

	issues.append_array(_validate_attack_learnset(display_name, monster_data.learnable_attacks))
	issues.append_array(_validate_trait_learnset(display_name, monster_data.learnable_traits))
	if include_balance_warnings:
		warnings.append_array(_build_balance_warnings(display_name, monster_data))
	return {"issues": issues, "warnings": warnings, "fixes": fixes}

func _auto_fix_monster(monster_data: MTMonsterData) -> Array[String]:
	var fixes: Array[String] = []
	var fixed_attacks := _normalized_learnset(monster_data.learnable_attacks, "attack")
	if fixed_attacks.get("changed", false):
		monster_data.learnable_attacks = fixed_attacks.get("entries", [])
		fixes.append_array(fixed_attacks.get("fixes", []))
	var fixed_traits := _normalized_learnset(monster_data.learnable_traits, "trait_data")
	if fixed_traits.get("changed", false):
		monster_data.learnable_traits = fixed_traits.get("entries", [])
		fixes.append_array(fixed_traits.get("fixes", []))
	return fixes

func _normalized_learnset(source: Array, key: String) -> Dictionary:
	var changed := false
	var fixes: Array[String] = []
	var normalized: Array[Dictionary] = []
	var seen: Dictionary = {}
	var source_normalized: Array[Dictionary] = []
	for raw_entry in source:
		var entry := _extract_learnset_entry(raw_entry, key)
		if entry.is_empty():
			changed = true
			fixes.append("Removed learnset entry with missing %s" % key)
			continue
		var resource = entry.get(key, null)
		var learn_level: int = max(1, int(entry.get("learn_level", 1)))
		if int(entry.get("learn_level", 1)) != learn_level:
			changed = true
			fixes.append("Clamped learn_level below 1")
		var identity := _resource_identity(resource)
		if seen.has(identity):
			changed = true
			fixes.append("Removed duplicate learnset entry: %s" % identity)
			continue
		seen[identity] = true
		var normalized_entry := {key: resource, "learn_level": learn_level}
		normalized.append(normalized_entry)
		source_normalized.append(normalized_entry)
	normalized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_level: int = int(a.get("learn_level", 1))
		var b_level: int = int(b.get("learn_level", 1))
		if a_level == b_level:
			return _resource_identity(a.get(key, null)) < _resource_identity(b.get(key, null))
		return a_level < b_level
	)
	if normalized.size() != source.size():
		changed = true
	if not _learnsets_equal(source_normalized, normalized, key):
		changed = true
		if not fixes.has("Sorted learnset by learn_level"):
			fixes.append("Sorted learnset by learn_level")
	return {"changed": changed, "entries": normalized, "fixes": fixes}

func _build_balance_warnings(_display_name: String, monster_data: MTMonsterData) -> Array[String]:
	var warnings: Array[String] = []
	var level_one_attacks := _count_entries_at_or_below_level(monster_data.learnable_attacks, "attack", 1)
	var level_one_traits := _count_entries_at_or_below_level(monster_data.learnable_traits, "trait_data", 1)
	if level_one_attacks > BalanceConstants.MAX_LEARNED_ATTACKS:
		warnings.append("More than %d attacks are available at level 1" % BalanceConstants.MAX_LEARNED_ATTACKS)
	if level_one_traits > BalanceConstants.MAX_LEARNED_TRAITS:
		warnings.append("More than %d traits are available at level 1" % BalanceConstants.MAX_LEARNED_TRAITS)
	if monster_data.learnable_attacks.size() >= 4 and _highest_learn_level(monster_data.learnable_attacks, "attack") <= 1:
		warnings.append("Attack learnset is entirely front-loaded at level 1")
	if monster_data.learnable_traits.size() >= 3 and _highest_learn_level(monster_data.learnable_traits, "trait_data") <= 1:
		warnings.append("Trait learnset is entirely front-loaded at level 1")
	var attack_gap: int = _largest_learn_gap(monster_data.learnable_attacks, "attack")
	if attack_gap >= ATTACK_GAP_WARNING_THRESHOLD:
		warnings.append("Attack learnset has a long gap of %d levels" % attack_gap)
	var trait_gap: int = _largest_learn_gap(monster_data.learnable_traits, "trait_data")
	if trait_gap >= TRAIT_GAP_WARNING_THRESHOLD:
		warnings.append("Trait learnset has a long gap of %d levels" % trait_gap)
	var duplicate_roles: Array[String] = _find_early_duplicate_attack_roles(monster_data.learnable_attacks)
	for role_warning in duplicate_roles:
		warnings.append(role_warning)
	var highest_attack_level: int = _highest_learn_level(monster_data.learnable_attacks, "attack")
	var highest_trait_level: int = _highest_learn_level(monster_data.learnable_traits, "trait_data")
	var highest_progression_level: int = max(highest_attack_level, highest_trait_level)
	var total_learnables: int = monster_data.learnable_attacks.size() + monster_data.learnable_traits.size()
	if total_learnables >= 4 and highest_progression_level > 0 and highest_progression_level <= HIGH_LEVEL_INCENTIVE_THRESHOLD:
		warnings.append("No new learn incentives after level %d" % highest_progression_level)
	return warnings

func _largest_learn_gap(learnset: Array, key: String) -> int:
	var previous_level := -1
	var largest_gap := 0
	for raw_entry in learnset:
		var entry := _extract_learnset_entry(raw_entry, key)
		if entry.is_empty():
			continue
		if entry.get(key, null) == null:
			continue
		var learn_level: int = int(entry.get("learn_level", 0))
		if previous_level >= 0:
			largest_gap = max(largest_gap, learn_level - previous_level)
		previous_level = learn_level
	return largest_gap

func _find_early_duplicate_attack_roles(learnset: Array) -> Array[String]:
	var warnings: Array[String] = []
	var role_counts: Dictionary = {}
	for raw_entry in learnset:
		var entry := _extract_learnset_entry(raw_entry, "attack")
		if entry.is_empty():
			continue
		var attack: MTAttackData = entry.get("attack", null)
		if attack == null:
			continue
		var learn_level: int = int(entry.get("learn_level", 0))
		if learn_level > EARLY_ROLE_WINDOW_LEVEL:
			continue
		var role := _attack_role_signature(attack)
		role_counts[role] = int(role_counts.get(role, 0)) + 1
	for role in role_counts.keys():
		var count: int = int(role_counts.get(role, 0))
		if count >= EARLY_ROLE_DUPLICATE_THRESHOLD:
			warnings.append("Too many similar early attacks: %s (%d by level %d)" % [str(role), count, EARLY_ROLE_WINDOW_LEVEL])
	return warnings

func _attack_role_signature(attack: MTAttackData) -> String:
	if attack == null:
		return "<null>"
	var element_name: String = MTElement.type_to_key(int(attack.element))
	var damage_type_name: String = _damage_type_to_key(int(attack.damage_type))
	var role_bits: Array[String] = [element_name, damage_type_name]
	if not attack.stat_changes.is_empty():
		role_bits.append("stat")
	if attack.lifesteal > 0.0:
		role_bits.append("lifesteal")
	if attack.priority > 0:
		role_bits.append("priority")
	return "/".join(role_bits)

func _damage_type_to_key(damage_type: int) -> String:
	match damage_type:
		MTDamageType.Type.PHYSICAL:
			return "PHYSICAL"
		MTDamageType.Type.MAGICAL:
			return "MAGICAL"
		MTDamageType.Type.STATUS:
			return "STATUS"
		_:
			return "UNKNOWN"

func _count_entries_at_or_below_level(learnset: Array, key: String, max_level: int) -> int:
	var count := 0
	for raw_entry in learnset:
		var entry := _extract_learnset_entry(raw_entry, key)
		if entry.is_empty():
			continue
		if entry.get(key, null) == null:
			continue
		if int(entry.get("learn_level", 0)) <= max_level:
			count += 1
	return count

func _highest_learn_level(learnset: Array, key: String) -> int:
	var highest := 0
	for raw_entry in learnset:
		var entry := _extract_learnset_entry(raw_entry, key)
		if entry.is_empty():
			continue
		if entry.get(key, null) == null:
			continue
		highest = max(highest, int(entry.get("learn_level", 0)))
	return highest

func _validate_attack_learnset(_display_name: String, learnset: Array) -> Array[String]:
	var issues: Array[String] = []
	var seen_paths: Dictionary = {}
	var previous_level := -1
	for index in range(learnset.size()):
		var entry := _extract_learnset_entry(learnset[index], "attack")
		if entry.is_empty():
			issues.append("Attack learnset entry %d has no attack resource" % index)
			continue
		var attack = entry.get("attack", null)
		var learn_level: int = int(entry.get("learn_level", 0))
		if attack == null:
			issues.append("Attack learnset entry %d has no attack resource" % index)
			continue
		if learn_level < 1:
			issues.append("Attack learnset entry %d has invalid learn_level %d" % [index, learn_level])
		if previous_level > learn_level:
			issues.append("Attack learnset is not sorted by learn_level")
		previous_level = learn_level
		var attack_path := _resource_identity(attack)
		if seen_paths.has(attack_path):
			issues.append("Duplicate attack learn entry: %s" % attack_path)
		else:
			seen_paths[attack_path] = true
	if learnset.is_empty():
		issues.append("Attack learnset is empty")
	elif not _has_level_one_or_earlier_entry(learnset, "attack"):
		issues.append("Attack learnset has no entry available at level 1")
	return issues

func _validate_trait_learnset(_display_name: String, learnset: Array) -> Array[String]:
	var issues: Array[String] = []
	var seen_paths: Dictionary = {}
	var previous_level := -1
	for index in range(learnset.size()):
		var entry := _extract_learnset_entry(learnset[index], "trait_data")
		if entry.is_empty():
			issues.append("Trait learnset entry %d has no trait resource" % index)
			continue
		var trait_data = entry.get("trait_data", null)
		var learn_level: int = int(entry.get("learn_level", 0))
		if trait_data == null:
			issues.append("Trait learnset entry %d has no trait resource" % index)
			continue
		if learn_level < 1:
			issues.append("Trait learnset entry %d has invalid learn_level %d" % [index, learn_level])
		if previous_level > learn_level:
			issues.append("Trait learnset is not sorted by learn_level")
		previous_level = learn_level
		var trait_path := _resource_identity(trait_data)
		if seen_paths.has(trait_path):
			issues.append("Duplicate trait learn entry: %s" % trait_path)
		else:
			seen_paths[trait_path] = true
	return issues

func _has_level_one_or_earlier_entry(learnset: Array, key: String) -> bool:
	for raw_entry in learnset:
		var entry := _extract_learnset_entry(raw_entry, key)
		if entry.is_empty():
			continue
		if entry.get(key, null) == null:
			continue
		if int(entry.get("learn_level", 0)) <= 1:
			return true
	return false

func _extract_learnset_entry(raw_entry, key: String) -> Dictionary:
	if raw_entry == null:
		return {}
	if raw_entry is Dictionary:
		var entry: Dictionary = raw_entry
		var resource = entry.get(key, null)
		if key == "trait_data" and resource == null:
			resource = entry.get("trait", null)
		if resource == null:
			return {}
		return {
			key: resource,
			"learn_level": max(1, int(entry.get("learn_level", 1)))
		}
	if raw_entry is Resource:
		var resource_value = raw_entry.get(key)
		if key == "trait_data" and resource_value == null:
			resource_value = raw_entry.get("trait")
		if resource_value == null:
			return {}
		var learn_level_value = raw_entry.get("learn_level")
		var learn_level: int = 1
		if learn_level_value != null:
			learn_level = max(1, int(learn_level_value))
		return {
			key: resource_value,
			"learn_level": learn_level
		}
	return {}

func _resource_identity(resource: Resource) -> String:
	if resource == null:
		return "<null>"
	if resource.resource_path != "":
		return resource.resource_path
	return str(resource)

func _learnsets_equal(a: Array[Dictionary], b: Array[Dictionary], key: String) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if not _learnset_entries_equal(a[i], b[i], key):
			return false
	return true

func _learnset_entries_equal(a: Dictionary, b: Dictionary, key: String) -> bool:
	return int(a.get("learn_level", 0)) == int(b.get("learn_level", 0)) \
		and _resource_identity(a.get(key, null)) == _resource_identity(b.get(key, null))

func _print_human_readable_results(results: Dictionary) -> void:
	var checked: int = int(results.get("checked_monsters", 0))
	var failed: int = int(results.get("failed_monsters", 0))
	var warned: int = int(results.get("warning_monsters", 0))
	var fixed: int = int(results.get("fixed_monsters", 0))
	var issues: Dictionary = results.get("issues", {})
	var warnings: Dictionary = results.get("warnings", {})
	var fixes: Dictionary = results.get("fixes", {})
	if fixed > 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "Auto-fixed learnsets in %d monsters." % fixed)
	if failed <= 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "Monster learnset validation passed for %d monsters." % checked)
		if warned > 0:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "Balance warnings found in %d/%d monsters." % [warned, checked])
			_print_warning_details(warnings)
		return
	DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "Monster learnset validation found issues in %d/%d monsters." % [failed, checked])
	var paths: Array[String] = []
	for path in issues.keys():
		paths.append(str(path))
	paths.sort()
	for monster_path in paths:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "FAIL - %s" % monster_path)
		var monster_issues: Array = issues.get(monster_path, [])
		for issue in monster_issues:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "  - %s" % str(issue))
	if warned > 0:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "Balance warnings found in %d/%d monsters." % [warned, checked])
		_print_warning_details(warnings)
	if fixed > 0:
		_print_fix_details(fixes)

func _print_warning_details(warnings: Dictionary) -> void:
	var paths: Array[String] = []
	for path in warnings.keys():
		paths.append(str(path))
	paths.sort()
	for monster_path in paths:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "WARN - %s" % monster_path)
		var monster_warnings: Array = warnings.get(monster_path, [])
		for warning in monster_warnings:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "  - %s" % str(warning))

func _print_fix_details(fixes: Dictionary) -> void:
	var paths: Array[String] = []
	for path in fixes.keys():
		paths.append(str(path))
	paths.sort()
	for monster_path in paths:
		DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "FIXED - %s" % monster_path)
		var monster_fixes: Array = fixes.get(monster_path, [])
		for fix in monster_fixes:
			DEBUG_LOG.debug(VALIDATOR_LOGS_ENABLED, "LearnsetValidator", "  - %s" % str(fix))
