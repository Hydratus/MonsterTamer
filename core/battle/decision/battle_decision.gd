extends RefCounted
class_name MTBattleDecision

const DEBUG_LOG = preload("res://core/systems/debug_log.gd")

func decide(_monster: MTMonsterInstance, _battle: MTBattleController) -> MTBattleAction:
	DEBUG_LOG.error("BattleDecision", "MTBattleDecision.decide() not implemented")
	return null
