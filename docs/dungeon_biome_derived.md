# Dungeon Biomes (derived from current project data)

## Data basis used
- Type chart: `data/elements/type_chart.csv`
- Existing monster roster: `data/monsters/*.tres` (8 monsters)
- Existing dungeon biome integration: `core/systems/game_balance_constants.gd`, `core/world/dungeon_scene.gd`
- Brainstorm sources:
  - `docs/monster_brainstorm_125.csv`
  - `docs/attack_brainstorm_150.csv`
  - `docs/trait_brainstorm_080.csv`

## Key signals from brainstorm data
- Monster Element 1 peaks: Water (16), Undead (15), Plant (12), Holy (11), Fire (10)
- Monster Element 2 peaks: Metal (18), Beast (12), Air (11), Earth (10), Poison (10)
- Frequent dual-element pairs: Holy+Metal, Water+Air, Undead+Poison, Plant+Beast, Fire+Earth
- Attack design emphasis: burst, control, poke (dominant categories)
- Status emphasis: bleed, burn, stagger, freeze/paralyze/poison cluster
- Trait themes with high weight: undead, beast, cosmic, holy, sound

---

## Biome set for dungeon runs

### 1) Gloomrot Catacombs
- Core identity: Undead + Poison attrition dungeon
- Primary elements: Undead, Poison, Cosmic
- Combat profile: control/sustain, curse pressure, anti-heal moments
- Status focus: poison, cursed, fear, daze
- Current roster fit:
  - common: Slime
  - uncommon: Ghostling
  - rare/boss: Wolfinator (as predator apex), Stoneback (as armored guardian)
- Future roster fit from brainstorm: Undead+Poison and Cosmic+Poison lines

### 2) Skytide Reservoir
- Core identity: Water + Air tempo biome
- Primary elements: Water, Air, Ice, Electric (secondary)
- Combat profile: poke + speed control, wet/paralyze setups
- Status focus: wet, freeze, paralyze
- Current roster fit:
  - common: Aquafin, Slime
  - uncommon: Wolf, Fernox
  - rare/boss: Wolfinator (air-hunter style)
- Future roster fit from brainstorm: Water+Air and Water+Metal branches

### 3) Sunforge Basilica
- Core identity: Holy + Metal defensive fortress
- Primary elements: Holy, Metal, Fire
- Combat profile: tank + punish + anti-debuff
- Status focus: cleanse, stagger, blind
- Current roster fit:
  - common: Stoneback
  - uncommon: Emberkat, Wolf
  - rare/boss: Wolfinator, Ghostling (as corruption counterpoint)
- Future roster fit from brainstorm: Holy+Metal (currently most frequent combo)

### 4) Thornfang Warrens
- Core identity: Plant + Beast hunt-maze
- Primary elements: Plant, Beast, Earth
- Combat profile: bruiser + sustain, trap/chase feeling
- Status focus: root, bleed, poison
- Current roster fit:
  - common: Wolf, Fernox
  - uncommon: Slime, Aquafin
  - rare/boss: Wolfinator
- Future roster fit from brainstorm: Plant+Beast lines

### 5) Emberfault Chasm
- Core identity: Fire + Earth volcanic pressure
- Primary elements: Fire, Earth, Metal
- Combat profile: burst + setup, high risk/high reward turns
- Status focus: burn, stagger
- Current roster fit:
  - common: Emberkat, Stoneback
  - uncommon: Wolf, Fernox
  - rare/boss: Wolfinator
- Future roster fit from brainstorm: Fire+Earth and Dragon+Fire branches

### 6) Stargrave Observatory
- Core identity: Cosmic + Undead mindgame biome
- Primary elements: Cosmic, Undead, Sound
- Combat profile: control + mindgame + clutch
- Status focus: silence, fear, daze
- Current roster fit:
  - common: Ghostling, Slime
  - uncommon: Wolf, Aquafin
  - rare/boss: Wolfinator, Stoneback
- Future roster fit from brainstorm: Cosmic-centric and void/casino/time trait themes

### 7) Ironhowl Bastion
- Core identity: Beast + Metal siege biome
- Primary elements: Beast, Metal, Dragon
- Combat profile: burst + bruiser + punish
- Status focus: bleed, stagger
- Current roster fit:
  - common: Wolf, Stoneback
  - uncommon: Emberkat, Fernox
  - rare/boss: Wolfinator
- Future roster fit from brainstorm: Beast-heavy and Metal secondary ecosystems

### 8) Echo Vault
- Core identity: Sound disruption dungeon
- Primary elements: Sound, Air, Holy
- Combat profile: control/tempo, ability denial and turn disruption
- Status focus: silence, daze, blind
- Current roster fit:
  - common: Ghostling, Wolf
  - uncommon: Aquafin, Fernox
  - rare/boss: Wolfinator
- Future roster fit from brainstorm: sound theme has high trait representation

---

## Run structure decision
- Keep the current run structure in code:
  - variable biome segment lengths
  - unpredictable biome order
- Do not force a fixed floor schedule for biomes.
- Future extension (not implemented yet): after a miniboss, player chooses between 2 biome paths.

---

## Practical implementation approach in this codebase

### Minimal-change phase (can be done immediately)
1. Keep existing 4 biome keys as gameplay wrappers:
   - cavern -> Gloomrot Catacombs
   - forest -> Thornfang Warrens
   - ruins -> Sunforge Basilica
   - swamp -> Skytide Reservoir
2. Only rename display strings / labels first.
3. Tune rarity and elite budget curves per wrapper in `DUNGEON_ENCOUNTER_CONFIG`.

### Expansion phase (new biome keys)
1. Add biome keys in route pools:
   - `run_biome_pool` in `core/world/dungeon_scene.gd` and `core/world/overworld.gd`
2. Add matching entries in `DUNGEON_ENCOUNTER_CONFIG` in `core/systems/game_balance_constants.gd`
3. Extend `_get_habitat_monster_paths()` in `core/world/dungeon_scene.gd`
4. Populate thief/boss templates per new biome

Status:
- Implemented in code for `emberfault_chasm`, `stargrave_observatory`, `ironhowl_bastion`, `echo_vault`.
- Dynamic segment length and unpredictable biome order remain unchanged.
- Miniboss branch choice is still future work.

### Content phase (best result)
- Add 2-4 new monsters per biome based on the listed dual-element signatures.
- Keep each biome with at least:
  - 2 common
  - 2 uncommon
  - 1 rare
  - optional very_rare/legendary slot for floor 30+

---

## Biome quality checklist (for balancing)
- Distinct status identity per biome (no duplicate status focus across adjacent segments)
- Distinct counterplay per biome (cleanse, anti-burst, anti-control, anti-sustain rotation)
- At least one clear offensive and one clear defensive answer in each biome
- Boss templates should represent the biome fantasy and not just highest BST monsters
