extends RefCounted
class_name MTDungeonQuestHelper

const NPCDataClass = preload("res://core/world/npc_data.gd")
const INVALID_CELL := Vector2i(-1, -1)

static func _has_game() -> bool:
	return _get_game() != null

static func _get_game():
	var loop := Engine.get_main_loop()
	if loop == null or not loop is SceneTree:
		return null
	return (loop as SceneTree).root.get_node_or_null("Game")

static func _is_invalid_cell(cell: Vector2i) -> bool:
	return cell == INVALID_CELL

static func _get_last_dynamic_npc(owner):
	if owner._dynamic_npcs.is_empty():
		return null
	return owner._dynamic_npcs[owner._dynamic_npcs.size() - 1]

static func maybe_spawn_quest_npc(owner) -> void:
	if owner._has_quest_this_floor:
		return
	if owner.current_floor >= owner.floor_count:
		return
	var effective_spawn_chance: float = owner._get_effective_quest_spawn_chance()
	if owner._rng.randf() > effective_spawn_chance:
		return

	var room_index: int = owner._pick_normal_room_index()
	if room_index < 0:
		return

	var reserved: Dictionary = {}
	reserved[owner._player_spawn_cell] = true
	if owner._stairs_npc != null and owner._stairs_npc.visible:
		reserved[owner._world_to_cell(owner._stairs_npc.global_position)] = true

	var cell: Vector2i = owner._pick_cell_in_room(room_index, reserved)
	if _is_invalid_cell(cell):
		return

	var quest_type: int = owner._rng.randi_range(0, 2)
	owner._active_quest = {
		"quest_type": quest_type,
		"accepted": quest_type == owner.QUEST_TYPE.THIEF_AMBUSH,
		"completed": false,
		"ready_to_turn_in": false,
		"shop_unlocked": false,
		"delivery_item_id": "",
		"monsters_killed": 0,
		"monsters_needed": owner._rng.randi_range(2, 4)
	}
	owner._has_quest_this_floor = true

	var quest_npc_data: MTNPCData = create_quest_npc_data(owner, quest_type)
	owner._spawn_dynamic_npc(cell, quest_npc_data)
	owner._quest_npc = _get_last_dynamic_npc(owner)
	if quest_type == owner.QUEST_TYPE.ITEM_DELIVERY:
		spawn_delivery_quest_item(owner, cell)

	var quest_names: Array[String] = ["Item Delivery", "Monster Hunt", "Thief Ambush"]
	owner._log_dungeon("[Dungeon] quest spawned type=%s cell=%s" % [quest_names[quest_type], str(cell)])

static func create_quest_npc_data(owner, quest_type: int) -> MTNPCData:
	var data := NPCDataClass.new()
	var dialogue_before := ""
	var dialogue_after := ""
	var interaction_id := "dungeon_quest"

	match quest_type:
		owner.QUEST_TYPE.ITEM_DELIVERY:
			data.display_name = TranslationServer.translate("Merchant")
			dialogue_before = TranslationServer.translate("Please, find me a healing potion on this level!")
			dialogue_after = TranslationServer.translate("Thank you! You're a lifesaver.")
			interaction_id = "dungeon_quest_delivery"
		owner.QUEST_TYPE.MONSTER_HUNT:
			data.display_name = TranslationServer.translate("Hunter")
			dialogue_before = TranslationServer.translate("Help me defeat the monsters on this floor!")
			dialogue_after = TranslationServer.translate("Excellent work! You're a true warrior.")
			interaction_id = "dungeon_quest_hunt"
		owner.QUEST_TYPE.THIEF_AMBUSH:
			data.display_name = TranslationServer.translate("Thief")
			dialogue_before = TranslationServer.translate("You've encountered a notorious thief!")
			dialogue_after = TranslationServer.translate("Ha! You win this time...")
			interaction_id = "dungeon_quest_thief"

	data.dialogue_before = dialogue_before
	data.dialogue_after = dialogue_after
	data.interaction_id = interaction_id
	data.battle_once = false
	data.walk_enabled = false

	if quest_type == owner.QUEST_TYPE.THIEF_AMBUSH:
		for entry in owner._build_thief_team_entries():
			if entry != null:
				data.team_entries.append(entry)

	return data

static func pick_or_create_random_item(owner) -> String:
	if owner.item_reward_pool.is_empty():
		return "lesser_healing_potion"
	return owner.item_reward_pool[owner._rng.randi_range(0, owner.item_reward_pool.size() - 1)]

static func spawn_delivery_quest_item(owner, quest_cell: Vector2i) -> void:
	var reserved: Dictionary = {}
	reserved[owner._player_spawn_cell] = true
	reserved[quest_cell] = true
	if owner._stairs_npc != null and owner._stairs_npc.visible:
		reserved[owner._world_to_cell(owner._stairs_npc.global_position)] = true
	if owner._boss_npc != null and owner._boss_npc.visible:
		reserved[owner._world_to_cell(owner._boss_npc.global_position)] = true
	for npc in owner._dynamic_npcs:
		if npc == null or not npc.visible:
			continue
		reserved[owner._world_to_cell(npc.global_position)] = true

	var room_index: int = owner._pick_normal_room_index()
	if room_index < 0:
		return
	var cell: Vector2i = owner._pick_cell_in_room(room_index, reserved)
	if _is_invalid_cell(cell):
		return

	var delivery_item_id: String = "quest_delivery_satchel_floor_%d" % owner.current_floor
	owner._active_quest["delivery_item_id"] = delivery_item_id
	owner._spawn_dynamic_npc(cell, create_delivery_quest_item_npc_data())
	owner._quest_item_npc = _get_last_dynamic_npc(owner)
	owner._log_dungeon("[Dungeon] delivery item spawned id=%s cell=%s" % [delivery_item_id, str(cell)])

static func create_delivery_quest_item_npc_data() -> MTNPCData:
	var data := NPCDataClass.new()
	data.display_name = TranslationServer.translate("Lost Satchel")
	data.dialogue_before = TranslationServer.translate("You found the merchant's lost satchel.")
	data.dialogue_after = ""
	data.interaction_id = "dungeon_quest_delivery_item"
	data.battle_once = false
	data.walk_enabled = false
	return data

static func handle_quest_delivery(owner, npc) -> bool:
	if not _has_game():
		return true
	var game = _get_game()
	if owner._active_quest.get("completed", false) and owner._active_quest.get("shop_unlocked", false):
		return owner._handle_merchant_shop(npc)
	var delivery_item_id: String = str(owner._active_quest.get("delivery_item_id", ""))
	if delivery_item_id == "":
		owner._enqueue_message(TranslationServer.translate("The merchant seems to have lost track of the package."))
		return true
	if not owner._active_quest.get("accepted", false):
		owner._active_quest["accepted"] = true
		owner._enqueue_message(TranslationServer.translate("Merchant Quest: Find the lost satchel somewhere on this floor."))
		return true
	if game.get_item_count(delivery_item_id) <= 0:
		owner._enqueue_message(TranslationServer.translate("Merchant Quest: Please find my lost satchel and bring it back."))
		return true
	game.remove_item(delivery_item_id, 1)
	owner._active_quest["completed"] = true
	owner._active_quest["ready_to_turn_in"] = false
	owner._active_quest["shop_unlocked"] = true
	owner._enqueue_message(TranslationServer.translate("Quest Complete: You returned the lost satchel."))
	owner._award_quest_rewards()
	owner._enqueue_message(TranslationServer.translate("Merchant unlocked: Trade with run gold is now available."))
	owner._log_dungeon("[Dungeon] quest completed type=delivery")
	return true

static func handle_quest_hunt(owner, _npc) -> bool:
	if not owner._active_quest.get("accepted", false):
		owner._active_quest["accepted"] = true
		var target_count: int = owner._active_quest.get("monsters_needed", 2)
		owner._enqueue_message(TranslationServer.translate("Hunter Quest accepted: Defeat %d wild encounters on this floor.") % target_count)
		owner._log_dungeon("[Dungeon] quest hunt accepted target=%d" % target_count)
		return true
	if owner._active_quest.get("ready_to_turn_in", false):
		owner._active_quest["completed"] = true
		owner._active_quest["ready_to_turn_in"] = false
		if owner._quest_npc != null:
			owner._set_npc_active(owner._quest_npc, false, Vector2i.ZERO)
		owner._enqueue_message(TranslationServer.translate("Quest Complete: The hunter rewards your work."))
		owner._award_quest_rewards()
		owner._log_dungeon("[Dungeon] quest completed type=hunt")
		return true
	var needed: int = owner._active_quest.get("monsters_needed", 2)
	var killed: int = owner._active_quest.get("monsters_killed", 0)
	owner._enqueue_message(TranslationServer.translate("Hunt Quest: %d/%d encounters defeated. Return when the hunt is done.") % [killed, needed])
	owner._log_dungeon("[Dungeon] quest hunt status=%d/%d" % [killed, needed])
	return true

static func handle_quest_delivery_item(owner, npc) -> bool:
	if not _has_game():
		return true
	var game = _get_game()
	var delivery_item_id: String = str(owner._active_quest.get("delivery_item_id", ""))
	if delivery_item_id == "":
		return true
	game.add_item(delivery_item_id, 1)
	if npc != null:
		owner._set_npc_active(npc, false, Vector2i.ZERO)
	owner._active_quest["ready_to_turn_in"] = true
	owner._enqueue_message(TranslationServer.translate("You found the lost satchel. Return it to the merchant."))
	owner._log_dungeon("[Dungeon] quest delivery item picked id=%s" % delivery_item_id)
	return true

static func handle_quest_thief(owner, _npc) -> bool:
	owner._enqueue_message(TranslationServer.translate("The thief engages you in battle!"))
	return false

static func award_quest_rewards(owner) -> void:
	if _has_game():
		var game = _get_game()
		game.add_run_gold(owner.quest_reward_gold)
		game.add_soul_essence(owner.quest_reward_soul_essence)
		owner._enqueue_message(TranslationServer.translate("Received %d gold and %d Soul Essence!") % [owner.quest_reward_gold, owner.quest_reward_soul_essence])
		owner._log_dungeon("[Dungeon] quest reward gold=%d essence=%d" % [owner.quest_reward_gold, owner.quest_reward_soul_essence])
	else:
		owner._enqueue_message(TranslationServer.translate("Quest rewarded! (Game singleton not found)"))
		owner._log_dungeon("[Dungeon] quest reward failed - Game not initialized")

static func reset_floor_quest_state(owner) -> void:
	var old_delivery_item_id: String = str(owner._active_quest.get("delivery_item_id", ""))
	if old_delivery_item_id != "" and _has_game():
		var game = _get_game()
		game.remove_item(old_delivery_item_id, game.get_item_count(old_delivery_item_id))
	owner._active_quest.clear()
	owner._has_quest_this_floor = false
	owner._quest_npc = null
	owner._quest_item_npc = null
	owner._merchant_shop_index = 0
