extends RefCounted
class_name MTBattleSceneAdapter

var _scene

func _init(scene_ref) -> void:
	_scene = scene_ref

func add_battle_message(text: String) -> void:
	if _scene != null:
		_scene.add_battle_message(text)

func clear_all_messages() -> void:
	if _scene != null and _scene.message_box != null:
		_scene.message_box.clear_messages()

func clear_current_action_messages() -> void:
	if _scene != null and _scene.message_box != null:
		_scene.message_box.current_action_messages.clear()

func flush_action_messages() -> void:
	if _scene != null:
		_scene.flush_action_messages()

func show_battle_messages() -> void:
	if _scene != null:
		_scene.show_battle_messages()

func queue_message_step(step: Callable) -> void:
	if _scene != null:
		_scene.queue_message_step(step)

func queue_exp_step(step: Callable) -> void:
	if _scene != null:
		_scene.queue_exp_step(step, [])

func queue_exp_step_front(step: Callable) -> void:
	if _scene != null:
		_scene.queue_exp_step_front(step, [])

func update_hud_with_active() -> void:
	if _scene != null:
		_scene.update_hud_with_active()

func has_pending_action_messages() -> bool:
	return _scene != null and _scene.message_box != null and _scene.message_box.current_action_messages.size() > 0

func has_queued_messages() -> bool:
	return _scene != null and _scene.message_box != null and _scene.message_box.message_queue.size() > 0

func show_player_menu(monster: MTMonsterInstance) -> void:
	if _scene != null:
		_scene.show_player_menu(monster)

func show_forced_switch_menu(team_index: int) -> void:
	if _scene != null:
		_scene.show_forced_switch_menu(team_index)

func hide_ui() -> void:
	if _scene != null:
		_scene.hide_ui()

func finish_battle(winner_team_index: int) -> void:
	if _scene != null:
		_scene.on_battle_finished(winner_team_index)

func perform_capture_attempt(actor: MTMonsterInstance, target: MTMonsterInstance, item: MTItemData) -> void:
	if _scene != null:
		_scene.perform_capture_attempt(actor, target, item)

func get_item_user_name(actor: MTMonsterInstance) -> String:
	if _scene != null:
		return str(_scene.get_item_user_name(actor))
	if actor != null and actor.data != null:
		return _monster_name(actor)
	return TranslationServer.translate("Player")

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name
