extends Resource
class_name MTNPCData

@export var display_name: String = ""
@export_multiline var dialogue_before: String = ""
@export_multiline var dialogue_after: String = ""
@export var interaction_id: String = ""
@export var battle_once: bool = true
@export var team_entries: Array[MTNPCMonsterEntry] = []

@export var gives_items: bool = false
@export var give_item_ids: Array[String] = []
@export var give_item_amount: int = 1

@export var walk_path: Array[Vector2i] = []
@export var walk_path_relative: bool = true
@export var walk_delay: float = 0.6
@export var walk_duration: float = 0.25
@export var walk_enabled: bool = false
