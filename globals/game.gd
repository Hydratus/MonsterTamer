extends Node

var party := []
var inventory := {}

func _ready() -> void:
	# Give 1 Secret Key on first game load if player doesn't already have one
	if not inventory.has("secret_key"):
		add_item("secret_key", 1)
var flags := {}
var player_name: String = "Player"
var run_gold: int = 0
var soul_essence: int = 0
var meta_unlocks: Dictionary = {}

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func add_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	var current := get_item_count(item_id)
	inventory[item_id] = current + amount

func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var current := get_item_count(item_id)
	if current < amount:
		return false
	var next := current - amount
	if next <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = next
	return true

func reset_run_state(starting_gold: int = 0) -> void:
	run_gold = max(0, starting_gold)

func add_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	run_gold += amount

func spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_gold < amount:
		return false
	run_gold -= amount
	return true

func add_soul_essence(amount: int) -> void:
	if amount <= 0:
		return
	soul_essence += amount

func spend_soul_essence(amount: int) -> bool:
	if amount <= 0:
		return true
	if soul_essence < amount:
		return false
	soul_essence -= amount
	return true

func get_meta_unlock_level(unlock_id: String) -> int:
	if unlock_id == "":
		return 0
	return int(meta_unlocks.get(unlock_id, 0))

func has_meta_unlock(unlock_id: String) -> bool:
	return get_meta_unlock_level(unlock_id) > 0

func buy_meta_unlock(unlock_id: String, cost: int, max_level: int = 1) -> bool:
	if unlock_id == "":
		return false
	if cost < 0:
		return false
	var current_level: int = get_meta_unlock_level(unlock_id)
	if current_level >= max(1, max_level):
		return false
	if not spend_soul_essence(cost):
		return false
	meta_unlocks[unlock_id] = current_level + 1
	return true
