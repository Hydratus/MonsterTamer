extends MTBattleAction
class_name MTRestAction

var energy_ratio: float = 0.25

func execute(_controller = null) -> Variant:
	if actor == null:
		return null
	var max_energy: int = actor.get_max_energy()
	if max_energy <= 0:
		return null
	var recover_amount: int = max(1, int(ceil(float(max_energy) * energy_ratio)))
	var before_energy: int = actor.energy
	actor.energy = min(max_energy, actor.energy + recover_amount)
	var restored: int = actor.energy - before_energy
	battle_log("%s uses Rest!" % actor.data.name)
	battle_log("%s restores %d Energy. (%d/%d EN)" % [actor.data.name, restored, actor.energy, max_energy])
	return null
