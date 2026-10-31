extends Control
## Окно «Мои карточки»: все карточки, взятые в этом забеге. Открывается кнопкой или клавишей Tab.

const CardView := preload("res://scripts/ui/card_view.gd")
const DECK_SCALE := 0.78

var _grid: GridContainer
var _empty: Label
var _stats: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var title := Label.new()
	title.text = "Мои карточки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 24
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.0))
	add_child(title)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stats.position.y = 72
	_stats.add_theme_font_size_override("font_size", 16)
	_stats.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	add_child(_stats)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 105
	scroll.offset_bottom = -80
	scroll.offset_left = 40
	scroll.offset_right = -40
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 30)
	_grid.add_theme_constant_override("v_separation", 18)
	center.add_child(_grid)
	_empty = Label.new()
	_empty.text = "Пока ни одной карточки.\nПобеждай врагов, чтобы получить уровень."
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.add_theme_font_size_override("font_size", 22)
	add_child(_empty)
	var close := Button.new()
	close.text = "Закрыть (Tab)"
	close.custom_minimum_size = Vector2(220, 52)
	close.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	close.position = Vector2(-110, -66)
	close.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.06, 0.1, 0.9) if st == "normal" else Color(0.25, 0.15, 0.08, 0.95)
		sb.border_color = Color(0.95, 0.75, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		close.add_theme_stylebox_override(st, sb)
	close.pressed.connect(func(): hide_deck())
	add_child(close)


## taken — массив id карточек в порядке получения.
func show_deck(taken: Array, player) -> void:
	for c in _grid.get_children():
		c.queue_free()
	var counts := {}
	var order := []
	for id in taken:
		if not counts.has(id):
			order.append(id)
			counts[id] = 0
		counts[id] += 1
	var cards_db = get_node("/root/Cards")
	for id in order:
		var slot := Control.new()   # карточки в колоде чуть меньше
		slot.custom_minimum_size = CardView.SIZE * DECK_SCALE
		var v := CardView.new()
		v.setup(cards_db.by_id(id), false, counts[id])
		v.scale = Vector2.ONE * DECK_SCALE
		slot.add_child(v)
		_grid.add_child(slot)
	_empty.visible = order.is_empty()
	var st: Dictionary = player.stats
	_stats.text = "Урон %d   ·   Здоровье %d   ·   Скорость атаки x%.2f   ·   Крит %d%%   ·   Вампиризм %d%%" % [
		st.damage * st.damage_mult, st.max_hp, st.attack_speed_mult, st.crit_chance * 100, st.lifesteal * 100]
	visible = true
	get_tree().paused = true


func hide_deck() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode in [KEY_TAB, KEY_ESCAPE]:
		hide_deck()
		get_viewport().set_input_as_handled()
