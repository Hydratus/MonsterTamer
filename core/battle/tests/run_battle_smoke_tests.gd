extends SceneTree

const BattleSmokeTestsClass = preload("res://core/battle/tests/battle_smoke_tests.gd")

func _init() -> void:
	var results: Dictionary = BattleSmokeTestsClass.run_all()
	print("[SmokeTest] %s" % JSON.stringify(results))
	if bool(results.get("all_passed", false)):
		quit(0)
	else:
		quit(1)
