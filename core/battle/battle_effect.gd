extends RefCounted
class_name BattleEffect

var source
var target

func on_apply() -> void:
	pass

func on_remove() -> void:
	pass

func on_turn_start():
	pass

func on_before_damage(context: Dictionary):
	pass

func on_after_damage(context: Dictionary):
	pass

func on_stat_calculation(stat: int, value: int) -> int:
	return value
