extends SceneTree

const BattleSmokeTestsClass = preload("res://core/battle/tests/battle_smoke_tests.gd")
const DEBUG_LOG = preload("res://core/systems/debug_log.gd")
const SMOKE_TEST_LOGS_ENABLED := true

func _init() -> void:
	var results: Dictionary = BattleSmokeTestsClass.run_all()
	var fails_only := _is_fails_only_enabled()
	var no_json := _is_no_json_enabled()
	_print_human_readable_results(results, fails_only)
	if not no_json:
		DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTestJSON", JSON.stringify(results))
	if bool(results.get("all_passed", false)):
		quit(0)
	else:
		quit(1)

func _print_human_readable_results(results: Dictionary, fails_only: bool) -> void:
	var keys: Array = []
	for key in results.keys():
		if str(key) == "all_passed":
			continue
		keys.append(str(key))
	keys.sort()

	var passed_count := 0
	var failed_count := 0

	if fails_only:
		DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTest", "Battle smoke results (fails only):")
	else:
		DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTest", "Battle smoke results:")
	for key in keys:
		var passed := bool(results.get(key, false))
		if passed:
			passed_count += 1
			if not fails_only:
				DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTest", "PASS - %s" % key)
		else:
			failed_count += 1
			DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTest", "FAIL - %s" % key)

	DEBUG_LOG.debug(SMOKE_TEST_LOGS_ENABLED, "SmokeTest", "Summary: %d passed, %d failed, %d total" % [passed_count, failed_count, passed_count + failed_count])

func _is_fails_only_enabled() -> bool:
	return _has_cli_flag("--fails-only")

func _is_no_json_enabled() -> bool:
	return _has_cli_flag("--no-json")

func _has_cli_flag(flag: String) -> bool:
	for arg in OS.get_cmdline_args():
		if arg == flag:
			return true
	for arg in OS.get_cmdline_user_args():
		if arg == flag:
			return true
	return false
