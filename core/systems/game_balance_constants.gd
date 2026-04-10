extends Node

# ================================================================
# TEAM & PARTY
# ================================================================
const TEAM_SIZE_CAP := 5

# ================================================================
# STAT CALCULATIONS (Monster Instance)
# ================================================================
## HP Calculation: ((2 × base_max_hp × level) / 100) + level + HP_LEVEL_BONUS
const STAT_SCALE_MULTIPLIER := 2.0
const STAT_SCALE_DIVISOR := 100.0
const HP_LEVEL_BONUS := 5

## Energy Calculation: ((2 × base_max_energy × level) / 100) + ENERGY_BASE_BONUS
const ENERGY_BASE_BONUS := 3

## Other Stats Calculation: ((2 × base_stat × level) / 100) + STAT_BASE_BONUS
const STAT_BASE_BONUS := 5

# ================================================================
# EXPERIENCE & LEVELING
# ================================================================
## EXP Distribution to Team when a monster KO's opponent
const TEAM_EXP_BONUS_PER_EXTRA_MEMBER := 0.375  # Per extra team member
const TEAM_EXP_MAX_MULTIPLIER := 2.5             # Maximum EXP multiplier with full team

## Catch-up Weighting (low-level monsters get bonus EXP)
const TEAM_EXP_CATCHUP_LEVEL_SPAN := 10.0       # Level difference for catch-up bonus calculation
const TEAM_EXP_CATCHUP_MAX_BONUS := 1.0         # Maximum catch-up multiplier (level*2)

## Active Fighter Bonus
const TEAM_EXP_ACTIVE_FIGHTER_BONUS := 0.10     # 10% extra EXP for the monster that dealt damage

# ================================================================
# DAMAGE CALCULATION
# ================================================================
## Critical Hit System
const CRIT_DAMAGE_MULTIPLIER_DEFAULT := 1.5
const CRIT_RATE_DEFAULT := 0.10

## Effectiveness Modifiers
const SUPER_EFFECTIVE_MULTIPLIER := 2.0
const NOT_VERY_EFFECTIVE_MULTIPLIER := 0.5
const NO_EFFECT_MULTIPLIER := 0.0

# ================================================================
# STATUS & STAT STAGES
# ================================================================
const STAT_STAGE_MIN := -6
const STAT_STAGE_MAX := 6

# ================================================================
# GAME STATE INITIALIZATION
# ================================================================
const STARTING_GOLD_DUNGEON := 0
const STARTING_ITEMS := {
	"lesser_healing_potion": 3,
	"lesser_binding_rune": 10,
	"secret_key": 1
}
