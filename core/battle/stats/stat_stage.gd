extends RefCounted
class_name MTStatStage

const MIN_STAGE := -5
const MAX_STAGE := 5
const STEP := 0.5   # 🔧 Balancing-Hebel

static func clamp_stage(stage: int) -> int:
	return clamp(stage, MIN_STAGE, MAX_STAGE)

static func get_multiplier(stage: int) -> float:
	stage = clamp_stage(stage)
	if stage >= 0:
		return (2.0 + stage) / 2.0
	else:
		return 2.0 / (2.0 - stage)
