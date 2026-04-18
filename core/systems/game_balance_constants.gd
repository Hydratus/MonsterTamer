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

# ================================================================
# DUNGEON ENCOUNTERS
# ================================================================
const ENCOUNTER_RARITY_ORDER: Array[String] = [
	"common",
	"uncommon",
	"rare",
	"very_rare",
	"legendary"
]

const ENCOUNTER_SEGMENT_RULES := {
	"min_len": 3,
	"max_len": 7,
	"candidate_min": 4,
	"candidate_max": 7
}

const ENCOUNTER_RARITY_WEIGHT_RULES: Array[Dictionary] = [
	{
		"start_min": 1,
		"start_max": 5,
		"weights": {
			"common": 70,
			"uncommon": 30,
			"rare": 0,
			"very_rare": 0,
			"legendary": 0
		}
	},
	{
		"start_min": 6,
		"start_max": 10,
		"weights": {
			"common": 45,
			"uncommon": 50,
			"rare": 5,
			"very_rare": 0,
			"legendary": 0
		}
	},
	{
		"start_min": 11,
		"start_max": 15,
		"weights": {
			"common": 20,
			"uncommon": 55,
			"rare": 22,
			"very_rare": 3,
			"legendary": 0
		}
	},
	{
		"start_min": 16,
		"start_max": 20,
		"weights": {
			"common": 10,
			"uncommon": 45,
			"rare": 35,
			"very_rare": 9,
			"legendary": 1
		}
	},
	{
		"start_min": 21,
		"start_max": 25,
		"weights": {
			"common": 5,
			"uncommon": 38,
			"rare": 42,
			"very_rare": 13,
			"legendary": 2
		}
	},
	{
		"start_min": 26,
		"start_max": 30,
		"weights": {
			"common": 0,
			"uncommon": 34,
			"rare": 45,
			"very_rare": 18,
			"legendary": 3
		}
	},
	{
		"start_min": 31,
		"start_max": 35,
		"weights": {
			"common": 0,
			"uncommon": 28,
			"rare": 52,
			"very_rare": 18,
			"legendary": 2
		}
	},
	{
		"start_min": 36,
		"start_max": 40,
		"weights": {
			"common": 0,
			"uncommon": 24,
			"rare": 52,
			"very_rare": 21,
			"legendary": 3
		}
	},
	{
		"start_min": 41,
		"start_max": 45,
		"weights": {
			"common": 0,
			"uncommon": 22,
			"rare": 50,
			"very_rare": 24,
			"legendary": 4
		}
	},
	{
		"start_min": 46,
		"start_max": 50,
		"weights": {
			"common": 0,
			"uncommon": 20,
			"rare": 49,
			"very_rare": 26,
			"legendary": 5
		}
	},
	{
		"start_min": 51,
		"start_max": 999,
		"weights": {
			"common": 0,
			"uncommon": 18,
			"rare": 48,
			"very_rare": 28,
			"legendary": 6
		}
	}
]

const ELITE_BUDGET_RULES: Array[Dictionary] = [
	{
		"start_min": 1,
		"start_max": 5,
		"budget_min": 45,
		"budget_max": 65,
		"team_min": 2,
		"team_max": 3
	},
	{
		"start_min": 6,
		"start_max": 10,
		"budget_min": 58,
		"budget_max": 82,
		"team_min": 2,
		"team_max": 3
	},
	{
		"start_min": 11,
		"start_max": 15,
		"budget_min": 72,
		"budget_max": 100,
		"team_min": 2,
		"team_max": 4
	},
	{
		"start_min": 16,
		"start_max": 20,
		"budget_min": 86,
		"budget_max": 116,
		"team_min": 2,
		"team_max": 4
	},
	{
		"start_min": 21,
		"start_max": 25,
		"budget_min": 100,
		"budget_max": 132,
		"team_min": 3,
		"team_max": 4
	},
	{
		"start_min": 26,
		"start_max": 30,
		"budget_min": 114,
		"budget_max": 148,
		"team_min": 3,
		"team_max": 4
	},
	{
		"start_min": 31,
		"start_max": 35,
		"budget_min": 128,
		"budget_max": 164,
		"team_min": 3,
		"team_max": 5
	},
	{
		"start_min": 36,
		"start_max": 40,
		"budget_min": 142,
		"budget_max": 180,
		"team_min": 3,
		"team_max": 5
	},
	{
		"start_min": 41,
		"start_max": 45,
		"budget_min": 156,
		"budget_max": 196,
		"team_min": 3,
		"team_max": 5
	},
	{
		"start_min": 46,
		"start_max": 50,
		"budget_min": 170,
		"budget_max": 214,
		"team_min": 3,
		"team_max": 5
	},
	{
		"start_min": 51,
		"start_max": 999,
		"budget_min": 184,
		"budget_max": 232,
		"team_min": 3,
		"team_max": 5
	}
]

const DUNGEON_ENCOUNTER_CONFIG := {
	"default": {
		"rarity_pools": {
			"common": [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			],
			"uncommon": [
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/aquafin/aquafin.tres",
				"res://data/monsters/emberkat/emberkat.tres"
			],
			"rare": [
				"res://data/monsters/wolfinator/wolfinator.tres"
			],
			"very_rare": [],
			"legendary": []
		},
		"monster_costs": {
			"res://data/monsters/slime/slime.tres": 10,
			"res://data/monsters/wolf/wolf.tres": 12,
			"res://data/monsters/stoneback/stoneback.tres": 14,
			"res://data/monsters/ghostling/ghostling.tres": 16,
			"res://data/monsters/fernox/fernox.tres": 17,
			"res://data/monsters/aquafin/aquafin.tres": 18,
			"res://data/monsters/emberkat/emberkat.tres": 19,
			"res://data/monsters/wolfinator/wolfinator.tres": 24
		},
		"thief_team_templates": [
			[
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/wolf/wolf.tres"
			],
			[
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres"
			]
		],
		"boss_team_templates": [
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/stoneback/stoneback.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			],
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/wolf/wolf.tres"
			]
		]
	},
	"cavern": {
		"rarity_weight_rules": [
			{"start_min": 1, "start_max": 5, "weights": {"common": 82, "uncommon": 18, "rare": 0, "very_rare": 0, "legendary": 0}},
			{"start_min": 6, "start_max": 10, "weights": {"common": 60, "uncommon": 38, "rare": 2, "very_rare": 0, "legendary": 0}},
			{"start_min": 11, "start_max": 15, "weights": {"common": 38, "uncommon": 50, "rare": 11, "very_rare": 1, "legendary": 0}},
			{"start_min": 16, "start_max": 20, "weights": {"common": 24, "uncommon": 50, "rare": 22, "very_rare": 4, "legendary": 0}},
			{"start_min": 21, "start_max": 25, "weights": {"common": 15, "uncommon": 46, "rare": 30, "very_rare": 8, "legendary": 1}},
			{"start_min": 26, "start_max": 30, "weights": {"common": 8, "uncommon": 42, "rare": 37, "very_rare": 11, "legendary": 2}},
			{"start_min": 31, "start_max": 35, "weights": {"common": 4, "uncommon": 40, "rare": 46, "very_rare": 8, "legendary": 2}},
			{"start_min": 36, "start_max": 40, "weights": {"common": 2, "uncommon": 36, "rare": 47, "very_rare": 12, "legendary": 3}},
			{"start_min": 41, "start_max": 45, "weights": {"common": 0, "uncommon": 34, "rare": 46, "very_rare": 16, "legendary": 4}},
			{"start_min": 46, "start_max": 50, "weights": {"common": 0, "uncommon": 30, "rare": 45, "very_rare": 19, "legendary": 6}},
			{"start_min": 51, "start_max": 999, "weights": {"common": 0, "uncommon": 28, "rare": 44, "very_rare": 21, "legendary": 7}}
		],
		"elite_budget_rules": [
			{"start_min": 1, "start_max": 5, "budget_min": 42, "budget_max": 62, "team_min": 2, "team_max": 3},
			{"start_min": 6, "start_max": 10, "budget_min": 52, "budget_max": 74, "team_min": 2, "team_max": 3},
			{"start_min": 11, "start_max": 15, "budget_min": 64, "budget_max": 90, "team_min": 2, "team_max": 4},
			{"start_min": 16, "start_max": 20, "budget_min": 76, "budget_max": 104, "team_min": 2, "team_max": 4},
			{"start_min": 21, "start_max": 25, "budget_min": 90, "budget_max": 120, "team_min": 2, "team_max": 4},
			{"start_min": 26, "start_max": 30, "budget_min": 102, "budget_max": 134, "team_min": 3, "team_max": 4},
			{"start_min": 31, "start_max": 35, "budget_min": 116, "budget_max": 150, "team_min": 3, "team_max": 5},
			{"start_min": 36, "start_max": 40, "budget_min": 128, "budget_max": 164, "team_min": 3, "team_max": 5},
			{"start_min": 41, "start_max": 45, "budget_min": 142, "budget_max": 180, "team_min": 3, "team_max": 5},
			{"start_min": 46, "start_max": 50, "budget_min": 156, "budget_max": 198, "team_min": 3, "team_max": 5},
			{"start_min": 51, "start_max": 999, "budget_min": 170, "budget_max": 214, "team_min": 3, "team_max": 5}
		],
		"rarity_pools": {
			"common": [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			],
			"uncommon": [
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/emberkat/emberkat.tres"
			],
			"rare": [
				"res://data/monsters/wolfinator/wolfinator.tres"
			],
			"very_rare": [],
			"legendary": []
		},
		"thief_team_templates": [
			[
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			],
			[
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			]
		],
		"boss_team_templates": [
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/stoneback/stoneback.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			],
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/slime/slime.tres"
			]
		]
	},
	"forest": {
		"rarity_weight_rules": [
			{"start_min": 1, "start_max": 5, "weights": {"common": 68, "uncommon": 32, "rare": 0, "very_rare": 0, "legendary": 0}},
			{"start_min": 6, "start_max": 10, "weights": {"common": 42, "uncommon": 52, "rare": 6, "very_rare": 0, "legendary": 0}},
			{"start_min": 11, "start_max": 15, "weights": {"common": 22, "uncommon": 54, "rare": 20, "very_rare": 4, "legendary": 0}},
			{"start_min": 16, "start_max": 20, "weights": {"common": 12, "uncommon": 48, "rare": 30, "very_rare": 9, "legendary": 1}},
			{"start_min": 21, "start_max": 25, "weights": {"common": 6, "uncommon": 42, "rare": 36, "very_rare": 14, "legendary": 2}},
			{"start_min": 26, "start_max": 30, "weights": {"common": 2, "uncommon": 36, "rare": 40, "very_rare": 19, "legendary": 3}},
			{"start_min": 31, "start_max": 35, "weights": {"common": 0, "uncommon": 34, "rare": 46, "very_rare": 16, "legendary": 4}},
			{"start_min": 36, "start_max": 40, "weights": {"common": 0, "uncommon": 30, "rare": 46, "very_rare": 18, "legendary": 6}},
			{"start_min": 41, "start_max": 45, "weights": {"common": 0, "uncommon": 28, "rare": 44, "very_rare": 21, "legendary": 7}},
			{"start_min": 46, "start_max": 50, "weights": {"common": 0, "uncommon": 24, "rare": 43, "very_rare": 24, "legendary": 9}},
			{"start_min": 51, "start_max": 999, "weights": {"common": 0, "uncommon": 22, "rare": 42, "very_rare": 26, "legendary": 10}}
		],
		"elite_budget_rules": [
			{"start_min": 1, "start_max": 5, "budget_min": 50, "budget_max": 70, "team_min": 2, "team_max": 3},
			{"start_min": 6, "start_max": 10, "budget_min": 60, "budget_max": 84, "team_min": 2, "team_max": 3},
			{"start_min": 11, "start_max": 15, "budget_min": 74, "budget_max": 102, "team_min": 2, "team_max": 4},
			{"start_min": 16, "start_max": 20, "budget_min": 88, "budget_max": 118, "team_min": 2, "team_max": 4},
			{"start_min": 21, "start_max": 25, "budget_min": 102, "budget_max": 134, "team_min": 3, "team_max": 4},
			{"start_min": 26, "start_max": 30, "budget_min": 116, "budget_max": 150, "team_min": 3, "team_max": 4},
			{"start_min": 31, "start_max": 35, "budget_min": 130, "budget_max": 166, "team_min": 3, "team_max": 5},
			{"start_min": 36, "start_max": 40, "budget_min": 144, "budget_max": 182, "team_min": 3, "team_max": 5},
			{"start_min": 41, "start_max": 45, "budget_min": 158, "budget_max": 198, "team_min": 3, "team_max": 5},
			{"start_min": 46, "start_max": 50, "budget_min": 172, "budget_max": 216, "team_min": 3, "team_max": 5},
			{"start_min": 51, "start_max": 999, "budget_min": 186, "budget_max": 232, "team_min": 3, "team_max": 5}
		],
		"rarity_pools": {
			"common": [
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/slime/slime.tres"
			],
			"uncommon": [
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/aquafin/aquafin.tres"
			],
			"rare": [
				"res://data/monsters/wolfinator/wolfinator.tres"
			],
			"very_rare": [],
			"legendary": []
		},
		"thief_team_templates": [
			[
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/fernox/fernox.tres"
			],
			[
				"res://data/monsters/aquafin/aquafin.tres",
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres"
			]
		],
		"boss_team_templates": [
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/aquafin/aquafin.tres"
			],
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/wolf/wolf.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/slime/slime.tres"
			]
		]
	},
	"ruins": {
		"rarity_weight_rules": [
			{"start_min": 1, "start_max": 5, "weights": {"common": 62, "uncommon": 38, "rare": 0, "very_rare": 0, "legendary": 0}},
			{"start_min": 6, "start_max": 10, "weights": {"common": 30, "uncommon": 54, "rare": 16, "very_rare": 0, "legendary": 0}},
			{"start_min": 11, "start_max": 15, "weights": {"common": 10, "uncommon": 48, "rare": 35, "very_rare": 7, "legendary": 0}},
			{"start_min": 16, "start_max": 20, "weights": {"common": 2, "uncommon": 40, "rare": 42, "very_rare": 14, "legendary": 2}},
			{"start_min": 21, "start_max": 25, "weights": {"common": 0, "uncommon": 33, "rare": 45, "very_rare": 18, "legendary": 4}},
			{"start_min": 26, "start_max": 30, "weights": {"common": 0, "uncommon": 27, "rare": 46, "very_rare": 22, "legendary": 5}},
			{"start_min": 31, "start_max": 35, "weights": {"common": 0, "uncommon": 26, "rare": 50, "very_rare": 18, "legendary": 6}},
			{"start_min": 36, "start_max": 40, "weights": {"common": 0, "uncommon": 22, "rare": 49, "very_rare": 20, "legendary": 9}},
			{"start_min": 41, "start_max": 45, "weights": {"common": 0, "uncommon": 18, "rare": 47, "very_rare": 24, "legendary": 11}},
			{"start_min": 46, "start_max": 50, "weights": {"common": 0, "uncommon": 14, "rare": 45, "very_rare": 27, "legendary": 14}},
			{"start_min": 51, "start_max": 999, "weights": {"common": 0, "uncommon": 12, "rare": 44, "very_rare": 29, "legendary": 15}}
		],
		"elite_budget_rules": [
			{"start_min": 1, "start_max": 5, "budget_min": 56, "budget_max": 78, "team_min": 2, "team_max": 3},
			{"start_min": 6, "start_max": 10, "budget_min": 68, "budget_max": 94, "team_min": 2, "team_max": 3},
			{"start_min": 11, "start_max": 15, "budget_min": 84, "budget_max": 112, "team_min": 2, "team_max": 4},
			{"start_min": 16, "start_max": 20, "budget_min": 98, "budget_max": 128, "team_min": 2, "team_max": 4},
			{"start_min": 21, "start_max": 25, "budget_min": 114, "budget_max": 146, "team_min": 3, "team_max": 4},
			{"start_min": 26, "start_max": 30, "budget_min": 128, "budget_max": 162, "team_min": 3, "team_max": 4},
			{"start_min": 31, "start_max": 35, "budget_min": 142, "budget_max": 178, "team_min": 3, "team_max": 5},
			{"start_min": 36, "start_max": 40, "budget_min": 156, "budget_max": 194, "team_min": 3, "team_max": 5},
			{"start_min": 41, "start_max": 45, "budget_min": 172, "budget_max": 214, "team_min": 3, "team_max": 5},
			{"start_min": 46, "start_max": 50, "budget_min": 188, "budget_max": 232, "team_min": 3, "team_max": 5},
			{"start_min": 51, "start_max": 999, "budget_min": 204, "budget_max": 250, "team_min": 3, "team_max": 5}
		],
		"rarity_pools": {
			"common": [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres"
			],
			"uncommon": [
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			],
			"rare": [
				"res://data/monsters/wolfinator/wolfinator.tres"
			],
			"very_rare": [],
			"legendary": []
		},
		"thief_team_templates": [
			[
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/wolf/wolf.tres"
			],
			[
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/stoneback/stoneback.tres",
				"res://data/monsters/slime/slime.tres"
			]
		],
		"boss_team_templates": [
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/stoneback/stoneback.tres"
			],
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/emberkat/emberkat.tres",
				"res://data/monsters/wolf/wolf.tres"
			]
		]
	},
	"swamp": {
		"rarity_weight_rules": [
			{"start_min": 1, "start_max": 5, "weights": {"common": 56, "uncommon": 44, "rare": 0, "very_rare": 0, "legendary": 0}},
			{"start_min": 6, "start_max": 10, "weights": {"common": 24, "uncommon": 56, "rare": 20, "very_rare": 0, "legendary": 0}},
			{"start_min": 11, "start_max": 15, "weights": {"common": 6, "uncommon": 48, "rare": 36, "very_rare": 9, "legendary": 1}},
			{"start_min": 16, "start_max": 20, "weights": {"common": 0, "uncommon": 40, "rare": 41, "very_rare": 17, "legendary": 2}},
			{"start_min": 21, "start_max": 25, "weights": {"common": 0, "uncommon": 34, "rare": 42, "very_rare": 20, "legendary": 4}},
			{"start_min": 26, "start_max": 30, "weights": {"common": 0, "uncommon": 28, "rare": 42, "very_rare": 24, "legendary": 6}},
			{"start_min": 31, "start_max": 35, "weights": {"common": 0, "uncommon": 22, "rare": 44, "very_rare": 25, "legendary": 9}},
			{"start_min": 36, "start_max": 40, "weights": {"common": 0, "uncommon": 18, "rare": 42, "very_rare": 28, "legendary": 12}},
			{"start_min": 41, "start_max": 45, "weights": {"common": 0, "uncommon": 14, "rare": 40, "very_rare": 31, "legendary": 15}},
			{"start_min": 46, "start_max": 50, "weights": {"common": 0, "uncommon": 10, "rare": 38, "very_rare": 34, "legendary": 18}},
			{"start_min": 51, "start_max": 999, "weights": {"common": 0, "uncommon": 8, "rare": 36, "very_rare": 35, "legendary": 21}}
		],
		"elite_budget_rules": [
			{"start_min": 1, "start_max": 5, "budget_min": 62, "budget_max": 86, "team_min": 2, "team_max": 3},
			{"start_min": 6, "start_max": 10, "budget_min": 76, "budget_max": 104, "team_min": 2, "team_max": 3},
			{"start_min": 11, "start_max": 15, "budget_min": 94, "budget_max": 124, "team_min": 2, "team_max": 4},
			{"start_min": 16, "start_max": 20, "budget_min": 110, "budget_max": 142, "team_min": 3, "team_max": 4},
			{"start_min": 21, "start_max": 25, "budget_min": 126, "budget_max": 160, "team_min": 3, "team_max": 4},
			{"start_min": 26, "start_max": 30, "budget_min": 142, "budget_max": 178, "team_min": 3, "team_max": 5},
			{"start_min": 31, "start_max": 35, "budget_min": 158, "budget_max": 196, "team_min": 3, "team_max": 5},
			{"start_min": 36, "start_max": 40, "budget_min": 174, "budget_max": 216, "team_min": 3, "team_max": 5},
			{"start_min": 41, "start_max": 45, "budget_min": 192, "budget_max": 236, "team_min": 3, "team_max": 5},
			{"start_min": 46, "start_max": 50, "budget_min": 210, "budget_max": 258, "team_min": 4, "team_max": 5},
			{"start_min": 51, "start_max": 999, "budget_min": 228, "budget_max": 278, "team_min": 4, "team_max": 5}
		],
		"rarity_pools": {
			"common": [
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres"
			],
			"uncommon": [
				"res://data/monsters/aquafin/aquafin.tres",
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/ghostling/ghostling.tres"
			],
			"rare": [
				"res://data/monsters/wolfinator/wolfinator.tres"
			],
			"very_rare": [],
			"legendary": []
		},
		"thief_team_templates": [
			[
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/aquafin/aquafin.tres"
			],
			[
				"res://data/monsters/fernox/fernox.tres",
				"res://data/monsters/slime/slime.tres",
				"res://data/monsters/wolf/wolf.tres"
			]
		],
		"boss_team_templates": [
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/aquafin/aquafin.tres",
				"res://data/monsters/fernox/fernox.tres"
			],
			[
				"res://data/monsters/wolfinator/wolfinator.tres",
				"res://data/monsters/ghostling/ghostling.tres",
				"res://data/monsters/slime/slime.tres"
			]
		]
	}
}
