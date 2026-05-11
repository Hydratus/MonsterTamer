@tool
extends Resource
class_name MTMonsterData

const EvolutionEntryDataClass = preload("res://core/monsters/evolution_entry_data.gd")
const AttackLearnDataClass = preload("res://core/monsters/attack_learn_data.gd")
const TraitLearnDataClass = preload("res://core/monsters/trait_learn_data.gd")

# Growth rate enum - wie schnell das Monster levelt
enum GrowthType {
	FAST,       # Schnell - Level × 100 EXP
	NORMAL,     # Normal - Level × 150 EXP
	SLOW,       # Langsam - Level × 200 EXP
	VERY_SLOW   # Sehr langsam - Level × 250 EXP
}

@export var name: String

# BASE STATS
@export var base_max_hp: int = 20
@export var base_max_energy: int = 10
@export var base_strength: int = 5
@export var base_magic: int = 5
@export var base_defense: int = 5
@export var base_resistance: int = 5
@export var base_speed: int = 10

# LIFESTEAL
@export_range(0.0, 1.0, 0.01)
var base_lifesteal: float = 0.0

# LEVEL
@export_range(1, 100)
var level: int = 1

# EXPERIENCE
@export_range(10, 1000)
var base_exp: int = 100
@export var growth_rate: GrowthType = GrowthType.NORMAL

# CAPTURE
@export_range(1, 100)
var base_catch_rate: int = 50

# ELEMENTS
@export_enum(
	"Fire:1",
	"Plant:2",
	"Water:3",
	"Undead:4",
	"Electric:5",
	"Sound:6",
	"Cosmic:7",
	"Holy:8",
	"Poison:9",
	"Metal:10",
	"Dragon:11",
	"Air:12",
	"Beast:13",
	"Earth:14",
	"Ice:15"
)
var elements: Array[int] = []

# ATTACKS
@export var attacks: Array[MTAttackData] = []

# TRAITS
@export var passive_traits: Array[MTTraitData] = []

# EVOLUTION
@export var evolution: Resource
var _evolutions: Array[Resource] = []
@export var evolutions: Array[Resource]:
	get:
		return _evolutions
	set(value):
		_evolutions = _normalize_evolution_entries(value)
var _editor_add_evolution_entry_internal := false
@export var editor_add_evolution_entry: bool:
	get:
		return _editor_add_evolution_entry_internal
	set(value):
		_editor_add_evolution_entry_internal = false
		if not value or not Engine.is_editor_hint():
			return
		var updated := _evolutions.duplicate()
		updated.append(EvolutionEntryDataClass.new())
		evolutions = updated
		emit_changed()
		notify_property_list_changed()

func _normalize_evolution_entries(source: Array) -> Array[Resource]:
	var normalized: Array[Resource] = []
	for raw_entry in source:
		if raw_entry == null:
			if Engine.is_editor_hint():
				normalized.append(EvolutionEntryDataClass.new())
			continue
		if raw_entry is Resource:
			normalized.append(raw_entry)
	return normalized

# ATTACK LEARNING
var _learnable_attacks: Array = []
@export var learnable_attacks: Array:
	get:
		return _learnable_attacks
	set(value):
		_learnable_attacks = _normalize_learnable_entries(value, AttackLearnDataClass, "attack")
var _editor_add_attack_learn_entry_internal := false
@export var editor_add_attack_learn_entry: bool:
	get:
		return _editor_add_attack_learn_entry_internal
	set(value):
		_editor_add_attack_learn_entry_internal = false
		if not value or not Engine.is_editor_hint():
			return
		var updated := _learnable_attacks.duplicate()
		updated.append(AttackLearnDataClass.new())
		learnable_attacks = updated
		emit_changed()
		notify_property_list_changed()

# TRAIT LEARNING
var _learnable_traits: Array = []
@export var learnable_traits: Array:
	get:
		return _learnable_traits
	set(value):
		_learnable_traits = _normalize_learnable_entries(value, TraitLearnDataClass, "trait_data")
var _editor_add_trait_learn_entry_internal := false
@export var editor_add_trait_learn_entry: bool:
	get:
		return _editor_add_trait_learn_entry_internal
	set(value):
		_editor_add_trait_learn_entry_internal = false
		if not value or not Engine.is_editor_hint():
			return
		var updated := _learnable_traits.duplicate()
		updated.append(TraitLearnDataClass.new())
		learnable_traits = updated
		emit_changed()
		notify_property_list_changed()

func _normalize_learnable_entries(source: Array, resource_class, key: String) -> Array:
	var normalized: Array = []
	for raw_entry in source:
		if raw_entry == null:
			if Engine.is_editor_hint():
				normalized.append(resource_class.new())
			continue
		if raw_entry is Resource:
			normalized.append(raw_entry)
			continue
		if raw_entry is Dictionary:
			if Engine.is_editor_hint():
				normalized.append(_learnable_dictionary_to_resource(raw_entry, resource_class, key))
			else:
				normalized.append(raw_entry)
	return normalized

func _learnable_dictionary_to_resource(entry: Dictionary, resource_class, key: String) -> Resource:
	var resource: Resource = resource_class.new()
	resource.set(key, entry.get(key, null))
	resource.set("learn_level", max(1, int(entry.get("learn_level", 1))))
	return resource
