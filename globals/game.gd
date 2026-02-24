extends Node

var party := []
var inventory := {}
var flags := {}
var player_name: String = "Player"

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
