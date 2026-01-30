extends PanelContainer
class_name BattleMessageBox

signal message_completed  # Wird ausgelöst wenn eine Message vollständig angezeigt wurde
signal all_messages_completed  # Wird ausgelöst wenn alle Messages abgearbeitet wurden

var message_label: Label
var message_queue: Array[String] = []
var current_message: String = ""
var current_char_index: int = 0
var is_displaying: bool = false
var chars_per_second: float = 80.0  # 2 Zeilen (ca. 80 Zeichen) in 1 Sekunde
var time_per_char: float = 0.0125  # 1/80 = 0.0125 Sekunden pro Buchstabe
var time_since_last_char: float = 0.0
var waiting_for_input: bool = false
var current_action_messages: Array[String] = []  # Sammelt Messages einer Action

func _ready():
	# Panel Setup - feste Größe
	custom_minimum_size = Vector2(0, 70)  # Feste Höhe von 70px
	
	# Positionierung: Unten über die gesamte Breite, 10px vom Rand (wie Enemy stats oben)
	anchor_left = 0.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 10    # 10px Abstand zum linken Rand
	offset_top = -80    # 70px Höhe für MessageBox (halbiert)
	offset_right = -10  # 10px Abstand zum rechten Rand
	offset_bottom = -10 # 10px Abstand zum unteren Rand (wie Enemy stats 10px oben)
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # Verhindert Wachsen
	
	# Label für Nachricht
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	add_child(vbox)
	
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.custom_minimum_size = Vector2(0, 40)  # Feste Mindesthöhe für konsistente Größe
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vbox.add_child(message_label)
	
	# Prompt für "Drücken um fortzufahren"
	var prompt_label = Label.new()
	prompt_label.text = "▼"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.modulate = Color(1, 1, 1, 0.7)
	prompt_label.name = "PromptLabel"
	vbox.add_child(prompt_label)
	
	visible = false
	
	# Input-Listener für "Weiter"-Knopf
	set_process_input(true)

func _process(delta):
	if not is_displaying:
		return
	
	if waiting_for_input:
		# Blinke den Prompt
		var prompt = get_node_or_null("VBoxContainer/PromptLabel")
		if prompt:
			prompt.modulate.a = 0.5 + sin(Time.get_ticks_msec() / 200.0) * 0.5
		return
	
	# Typewriter-Effekt
	time_since_last_char += delta
	
	while time_since_last_char >= time_per_char and current_char_index < current_message.length():
		current_char_index += 1
		message_label.text = current_message.substr(0, current_char_index)
		time_since_last_char -= time_per_char
	
	# Message vollständig angezeigt?
	if current_char_index >= current_message.length():
		waiting_for_input = true

func _input(event):
	if not visible or not is_displaying:
		return
	
	# Beliebige Taste oder Mausklick zum Fortfahren
	if event is InputEventKey and event.pressed and not event.echo:
		_on_continue_pressed()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_continue_pressed()

func _on_continue_pressed():
	if not waiting_for_input:
		# Überspringen zum Ende der aktuellen Nachricht
		current_char_index = current_message.length()
		message_label.text = current_message
		waiting_for_input = true
		return
	
	# Nächste Nachricht anzeigen
	waiting_for_input = false
	message_completed.emit()
	_show_next_message()

func add_message(text: String):
	# Sammle Messages für die aktuelle Action
	current_action_messages.append(text)

func flush_action_messages():
	# Kombiniere alle Messages der aktuellen Action zu einer
	if current_action_messages.size() > 0:
		var combined = "\n".join(current_action_messages)
		message_queue.append(combined)
		current_action_messages.clear()

func start_displaying():
	if message_queue.is_empty():
		all_messages_completed.emit()
		visible = false
		return
	
	visible = true
	is_displaying = true
	_show_next_message()

func _show_next_message():
	if message_queue.is_empty():
		is_displaying = false
		visible = false
		all_messages_completed.emit()
		return
	
	current_message = message_queue.pop_front()
	current_char_index = 0
	time_since_last_char = 0.0
	waiting_for_input = false
	message_label.text = ""

func clear_messages():
	message_queue.clear()
	current_action_messages.clear()
	current_message = ""
	current_char_index = 0
	is_displaying = false
	waiting_for_input = false
	message_label.text = ""
	visible = false

func skip_all():
	# Sofort alle Nachrichten überspringen
	clear_messages()
	all_messages_completed.emit()
