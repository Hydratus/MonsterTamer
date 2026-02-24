extends BattleAction
class_name ItemAction

const ItemDataClass = preload("res://core/items/item_data.gd")

var item: ItemData
var amount: int = 0

func execute(controller = null) -> Variant:
	var battle_ref = controller if controller != null else battle
	if item == null or target == null:
		return null
	if item.category == ItemDataClass.Category.SOULBINDER:
		if battle_ref != null and battle_ref.scene != null and battle_ref.scene.has_method("perform_capture_attempt"):
			battle_ref.scene.perform_capture_attempt(actor, target, item)
		if item.consumable:
			Game.remove_item(item.id, 1)
		return null
	if item.heal_max > 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		amount = rng.randi_range(item.heal_min, item.heal_max)
		var before := target.hp
		target.hp = min(target.hp + amount, target.get_max_hp())
		var healed := target.hp - before
		if battle_ref != null:
			var user_name := actor.data.name
			if battle_ref.scene != null and battle_ref.scene.has_method("get_item_user_name"):
				user_name = battle_ref.scene.get_item_user_name(actor)
			battle_ref.log_message("%s uses %s on %s for %d HP." % [user_name, item.name, target.data.name, healed])
		else:
			print(actor.data.name, "uses", item.name, "on", target.data.name, "for", healed)
	if item.consumable:
		Game.remove_item(item.id, 1)
	return null
