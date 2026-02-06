extends Resource
class_name NPCData

@export var display_name: String = ""
@export_multiline var dialogue_before: String = ""
@export_multiline var dialogue_after: String = ""
@export var battle_once: bool = true
@export var team_entries: Array[NPCMonsterEntry] = []

@export var walk_path: Array[Vector2i] = []
@export var walk_path_relative: bool = true
@export var walk_delay: float = 0.6
@export var walk_duration: float = 0.25
@export var walk_enabled: bool = false
