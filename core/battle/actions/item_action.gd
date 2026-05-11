extends MTBattleAction
class_name MTItemAction

const ItemDataClass = preload("res://core/items/item_data.gd")

var item: MTItemData
var evolution_target_monster: MTMonsterData

func _resolve_battle_ref(controller = null) -> MTBattleController:
	if controller != null:
		return controller as MTBattleController
	return battle

func execute(controller = null) -> Variant:
	var battle_ref: MTBattleController = _resolve_battle_ref(controller)
	if item == null or target == null:
		return null
	if item.category == ItemDataClass.Category.SOULBINDER:
		if battle_ref != null:
			battle_ref.perform_capture_attempt(actor, target, item)
		if item.consumable:
			_game_remove_item(item.id, 1)
		return null
	var had_effect := false
	if item.heal_max > 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var heal_amount := rng.randi_range(item.heal_min, item.heal_max)
		var before := target.hp
		target.hp = min(target.hp + heal_amount, target.get_max_hp())
		var healed := target.hp - before
		if healed > 0:
			had_effect = true
		if battle_ref != null and healed > 0:
			var user_name: String = str(battle_ref.get_item_user_name(actor))
			battle_ref.log_message(TranslationServer.translate("%s uses %s on %s for %d HP.") % [user_name, TranslationServer.translate(item.name), _monster_name(target), healed])
	var evolution_context := _build_evolution_context()
	if target.can_evolve(evolution_context):
		var evolution_logger := Callable()
		if battle_ref != null:
			evolution_logger = Callable(battle_ref, "log_message")
		if target.apply_evolution(evolution_logger, evolution_target_monster, evolution_context):
			had_effect = true
	if item.consumable and had_effect:
		_game_remove_item(item.id, 1)
	return null

func _build_evolution_context() -> Dictionary:
	if item == null:
		return {}
	return {
		"used_item_id": str(item.id)
	}

func _game_remove_item(item_id: String, quantity: int) -> void:
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return
	var game := (loop as SceneTree).root.get_node_or_null("Game")
	if game == null:
		return
	game.remove_item(item_id, quantity)

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name
