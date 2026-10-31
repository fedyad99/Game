extends Control
## Выбор одной из трёх карточек при повышении уровня. Игра на паузе, пока панель открыта.

signal card_chosen(card: Dictionary)

var _row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)
	var title := Label.new()
	title.text = "Новый уровень! Выбери карточку"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	v.add_child(title)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	v.add_child(_row)


func show_cards(cards: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for card in cards:
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 300)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var tag := "" if card["class"] == "" else "\n[%s]" % card["class"]
		b.text = "%s\n\n%s%s" % [card.title, card.desc, tag]
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): card_chosen.emit(card))
		_row.add_child(b)
	visible = true
