extends Control
## Выбор одной из трёх карточек при повышении уровня. Игра на паузе, пока панель открыта.

signal card_chosen(card: Dictionary)

const CardView := preload("res://scripts/ui/card_view.gd")

var _holder: Control
var _title: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_title = Label.new()
	_title.text = "Новый уровень! Выбери карточку"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.0))
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.position.y = 70
	add_child(_title)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)


func show_cards(cards: Array, level := 0) -> void:
	for c in _holder.get_children():
		c.queue_free()
	if level > 0:
		_title.text = "Уровень %d! Выбери карточку" % level
	var vp := get_viewport_rect().size
	var gap := 36.0
	var total := cards.size() * CardView.SIZE.x + (cards.size() - 1) * gap
	var x0 := (vp.x - total) / 2.0
	for i in cards.size():
		var v := CardView.new()
		v.setup(cards[i])
		v.position = Vector2(x0 + i * (CardView.SIZE.x + gap), vp.y / 2 - CardView.SIZE.y / 2 + 30)
		_holder.add_child(v)
		v.appear(0.08 * i)
		v.chosen.connect(func(card): card_chosen.emit(card))
	visible = true
