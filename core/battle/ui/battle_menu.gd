extends CanvasLayer
class_name BattleMenu

signal action_selected(attack: AttackData)

@onready var vbox := $Control/VBoxContainer   # 👈 PFAD WICHTIG

func show_attacks(monster: MonsterInstance):
	print("SHOW ATTACKS:", monster.data.name, monster.attacks.size())
	for child in vbox.get_children():
		child.queue_free()

	for attack in monster.attacks:
		var button := Button.new()
		button.text = attack.name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		button.pressed.connect(func():
			action_selected.emit(attack)
		)

		vbox.add_child(button)

	visible = true


func hide_menu():
	visible = false
