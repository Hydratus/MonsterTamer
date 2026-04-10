extends MTBattleAction
class_name MTRestAction

var energy_ratio: float = 0.25

func _resolve_battle_ref(controller = null) -> MTBattleController:
	if controller != null:
		return controller as MTBattleController
	return battle

func execute(controller = null) -> Variant:
	var battle_ref := _resolve_battle_ref(controller)
	if battle == null and battle_ref != null:
		battle = battle_ref
	if actor == null:
		return null
	var max_energy: int = actor.get_max_energy()
	if max_energy <= 0:
		return null
	var recover_amount: int = max(1, int(ceil(float(max_energy) * energy_ratio)))
	var before_energy: int = actor.energy
	actor.energy = min(max_energy, actor.energy + recover_amount)
	var restored: int = actor.energy - before_energy
	var actor_name := _monster_name(actor)
	battle_log(TranslationServer.translate("%s uses Rest!") % actor_name)
	battle_log(TranslationServer.translate("%s restores %d Energy. (%d/%d EN)") % [actor_name, restored, actor.energy, max_energy])
	return null

func _monster_name(monster: MTMonsterInstance) -> String:
	if monster == null or monster.data == null:
		return TranslationServer.translate("Unknown")
	return monster.data.name
