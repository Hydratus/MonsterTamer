extends RefCounted
class_name MTMonsterTeam

# Das Team mit allen Monstern
var monsters: Array[MTMonsterInstance] = []

# Index des aktuell aktiven Monsters
var active_monster_index: int = 0

# Initialisiere das Team
func _init(team_monsters: Array[MTMonsterInstance]):
	monsters = team_monsters
	active_monster_index = _find_first_alive_index()

func _find_first_alive_index() -> int:
	for i in range(monsters.size()):
		if monsters[i] != null and monsters[i].is_alive():
			return i
	return -1

# Bekomme das aktuelle aktive Monster
func get_active_monster() -> MTMonsterInstance:
	if active_monster_index < 0 or active_monster_index >= monsters.size():
		return null
	return monsters[active_monster_index]

# Wechsle zu einem bestimmten Monster
func switch_to_monster(index: int) -> bool:
	if index < 0 or index >= monsters.size():
		return false
	
	if monsters[index] == null or not monsters[index].is_alive():
		return false
	
	if index == active_monster_index:
		return false  # Schon aktiv
	
	# Setze alle Stat-Stages des alten aktiven Monsters auf 0 (Buffs/Debuffs entfernen)
	var old_monster = get_active_monster()
	if old_monster != null:
		for stat in MTMonsterInstance.StatType.values():
			old_monster.stat_stages[stat] = 0
	
	active_monster_index = index
	return true

# Alternative: switch_to (neuer Name)
func switch_to(index: int) -> bool:
	return switch_to_monster(index)

# Wechsle zum nächsten lebenden Monster
func switch_to_next_alive() -> bool:
	for i in range(monsters.size()):
		if i != active_monster_index and monsters[i] != null and monsters[i].is_alive():
			# Setze alle Stat-Stages des alten aktiven Monsters auf 0 (Buffs/Debuffs entfernen)
			var old_monster = get_active_monster()
			if old_monster != null:
				for stat in MTMonsterInstance.StatType.values():
					old_monster.stat_stages[stat] = 0
			
			active_monster_index = i
			return true
	
	return false  # Kein anderes lebendes Monster gefunden

# Prüfe ob das Team noch lebende Monster hat
func has_alive_monsters() -> bool:
	for monster in monsters:
		if monster != null and monster.is_alive():
			return true
	return false

# Bekomme alle lebenden Monster
func get_alive_monsters() -> Array[MTMonsterInstance]:
	var alive: Array[MTMonsterInstance] = []
	for monster in monsters:
		if monster != null and monster.is_alive():
			alive.append(monster)
	return alive

# Bekomme die Anzahl lebender Monster
func get_alive_count() -> int:
	var count = 0
	for monster in monsters:
		if monster != null and monster.is_alive():
			count += 1
	return count

func swap_positions(index_a: int, index_b: int) -> bool:
	if index_a < 0 or index_b < 0:
		return false
	if index_a >= monsters.size() or index_b >= monsters.size():
		return false
	if index_a == index_b:
		return true
	var temp: MTMonsterInstance = monsters[index_a]
	monsters[index_a] = monsters[index_b]
	monsters[index_b] = temp
	if active_monster_index == index_a:
		active_monster_index = index_b
	elif active_monster_index == index_b:
		active_monster_index = index_a
	return true

func remove_monster(monster: MTMonsterInstance) -> bool:
	if monster == null:
		return false
	var index := monsters.find(monster)
	if index == -1:
		return false
	remove_monster_at(index)
	return true

func remove_monster_at(index: int) -> MTMonsterInstance:
	if index < 0 or index >= monsters.size():
		return null
	var removed: MTMonsterInstance = monsters[index]
	monsters.remove_at(index)
	if monsters.is_empty():
		active_monster_index = -1
		return removed
	if index < active_monster_index:
		active_monster_index -= 1
	elif index == active_monster_index:
		active_monster_index = min(active_monster_index, monsters.size() - 1)
		if monsters[active_monster_index] == null or not monsters[active_monster_index].is_alive():
			active_monster_index = _find_first_alive_index()
	return removed
