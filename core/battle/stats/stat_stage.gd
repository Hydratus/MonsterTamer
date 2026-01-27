extends RefCounted
class_name StatStage

const MIN_STAGE := -5
const MAX_STAGE := 5
const STEP := 0.5   # 🔧 Balancing-Hebel

static func clamp_stage(stage: int) -> int:
	return clamp(stage, MIN_STAGE, MAX_STAGE)

static func get_multiplier(stage: int) -> float:
	stage = clamp_stage(stage)
	return 1.0 + stage * STEP
