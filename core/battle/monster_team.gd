extends RefCounted
class_name MonsterTeam

# Das Team mit allen Monstern
var monsters: Array[MonsterInstance] = []

# Index des aktuell aktiven Monsters
var active_monster_index: int = 0

# Initialisiere das Team
func _init(team_monsters: Array[MonsterInstance]):
	monsters = team_monsters
	active_monster_index = 0

# Bekomme das aktuelle aktive Monster
func get_active_monster() -> MonsterInstance:
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
	
	active_monster_index = index
	return true

# Wechsle zum nächsten lebenden Monster
func switch_to_next_alive() -> bool:
	for i in range(monsters.size()):
		if i != active_monster_index and monsters[i] != null and monsters[i].is_alive():
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
func get_alive_monsters() -> Array[MonsterInstance]:
	var alive: Array[MonsterInstance] = []
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
