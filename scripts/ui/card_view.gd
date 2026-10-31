extends Control
## Карточка в духе коллекционных карточных игр: каменная рамка с цветом редкости,
## овальная картинка, лента с названием, камень редкости, свиток с описанием.
## Всё рисуется кодом, без картинок.

signal chosen(card: Dictionary)

const SIZE := Vector2(230, 330)
const RARITY_COLOR := {
	"common": Color(0.85, 0.85, 0.85), "rare": Color(0.25, 0.55, 1.0),
	"epic": Color(0.7, 0.3, 1.0), "legendary": Color(1.0, 0.6, 0.1),
}
const RARITY_NAME := {"common": "Обычная", "rare": "Редкая", "epic": "Эпическая", "legendary": "Легендарная"}
const CLASS_NAME := {"": "Общая", "warrior": "Воин", "archer": "Лучник", "mage": "Маг"}
const ART_COLOR := {
	"heart": Color(0.75, 0.15, 0.2), "sword": Color(0.55, 0.25, 0.15), "boot": Color(0.2, 0.5, 0.3),
	"bolt": Color(0.75, 0.45, 0.05), "cross": Color(0.2, 0.55, 0.3), "target": Color(0.6, 0.2, 0.2),
	"drop": Color(0.45, 0.05, 0.15), "spiral": Color(0.25, 0.3, 0.7), "shield": Color(0.3, 0.35, 0.45),
	"blade": Color(0.35, 0.3, 0.5),
}

var card: Dictionary
var interactive := true
var count := 1           # для окна «мои карточки»: сколько раз взята
var _hover := false
var _title: Label
var _desc: Label
var _footer: Label


func setup(c: Dictionary, can_click := true, times := 1) -> void:
	card = c
	interactive = can_click
	count = times


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2 if interactive else Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_title = _label(card.title, 20, Color(1, 0.95, 0.85), Rect2(18, 180, SIZE.x - 36, 30))
	_title.add_theme_constant_override("outline_size", 6)
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	_desc = _label(card.desc, 16, Color(0.15, 0.1, 0.05), Rect2(26, 232, SIZE.x - 52, 62))
	var footer_text := "%s · %s" % [CLASS_NAME.get(card["class"], ""), RARITY_NAME.get(card.rarity, "")]
	_footer = _label(footer_text, 12, Color(0.95, 0.85, 0.6), Rect2(20, 302, SIZE.x - 40, 18))
	if interactive:
		mouse_entered.connect(func(): _set_hover(true))
		mouse_exited.connect(func(): _set_hover(false))


func _label(t: String, fs: int, col: Color, r: Rect2) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(r.size.x, 0)
	l.text = t
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _set_hover(v: bool) -> void:
	_hover = v
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * (1.08 if v else 1.0), 0.12)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		chosen.emit(card)
		accept_event()


## Появление карточки: переворот и подъём снизу.
func appear(delay: float) -> void:
	modulate.a = 0.0
	scale = Vector2(0.1, 1.0)
	position.y += 60
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.25).set_delay(delay)
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", position.y - 60, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------- Рисование ----------

func _draw() -> void:
	var rc: Color = RARITY_COLOR.get(card.rarity, Color.WHITE)
	var w := SIZE.x
	var h := SIZE.y
	# Свечение при наведении / у легендарных
	if _hover or card.rarity == "legendary":
		var glow := Color(rc, 0.35 if _hover else 0.18)
		for i in 4:
			_rrect(Rect2(-6 - i * 3, -6 - i * 3, w + 12 + i * 6, h + 12 + i * 6), 26 + i * 3, Color(glow, glow.a / (i + 1)))
	# Каменная рамка
	_rrect(Rect2(0, 0, w, h), 20, Color(0.22, 0.17, 0.13))
	_rrect(Rect2(4, 4, w - 8, h - 8), 17, rc.darkened(0.35))
	_rrect(Rect2(8, 8, w - 16, h - 16), 14, Color(0.36, 0.27, 0.19))
	_rrect(Rect2(11, 11, w - 22, h - 22), 12, Color(0.45, 0.34, 0.24))
	# Овальная картинка
	var c := Vector2(w / 2, 100)
	_ellipse(c, Vector2(88, 78), Color(0.78, 0.62, 0.3))   # золотой ободок
	_ellipse(c, Vector2(82, 72), Color(0.25, 0.18, 0.1))
	var base: Color = ART_COLOR.get(card.icon, Color(0.3, 0.3, 0.3))
	for i in 8:   # радиальный градиент
		var t := i / 8.0
		_ellipse(c, Vector2(79, 69) * (1.0 - t * 0.85), base.lightened(t * 0.45))
	_icon(card.icon, c)
	# Свиток описания
	_rrect(Rect2(20, 222, w - 40, 80), 10, Color(0.55, 0.42, 0.28))
	_rrect(Rect2(23, 225, w - 46, 74), 8, Color(0.93, 0.86, 0.7))
	# Лента с названием
	var y0 := 178.0
	var ribbon := PackedVector2Array([
		Vector2(-6, y0 + 4), Vector2(12, y0), Vector2(w - 12, y0), Vector2(w + 6, y0 + 4),
		Vector2(w - 2, y0 + 18), Vector2(w + 6, y0 + 32), Vector2(w - 12, y0 + 30), Vector2(12, y0 + 30),
		Vector2(-6, y0 + 32), Vector2(2, y0 + 18)])
	draw_colored_polygon(ribbon, Color(0.5, 0.12, 0.1))
	draw_polyline(ribbon + PackedVector2Array([ribbon[0]]), Color(0.85, 0.65, 0.3), 2.0, true)
	# Камень редкости
	var g := Vector2(w / 2, y0 + 36)
	var gem := PackedVector2Array([g + Vector2(0, -9), g + Vector2(8, 0), g + Vector2(0, 9), g + Vector2(-8, 0)])
	draw_colored_polygon(gem, rc)
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.2, 0.15, 0.1), 2.0, true)
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -7), g + Vector2(4, -1), g + Vector2(-3, -1)]), Color(1, 1, 1, 0.6))
	# Сколько раз взята
	if count > 1:
		var b := Vector2(w - 22, 22)
		draw_circle(b, 17, Color(0.2, 0.12, 0.05))
		draw_circle(b, 14, Color(0.85, 0.65, 0.2))
		draw_string(get_theme_default_font(), b + Vector2(-13, 6), "x%d" % count, HORIZONTAL_ALIGNMENT_CENTER, 26, 16, Color(0.2, 0.1, 0.0))


func _rrect(r: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


func _poly(pts: Array, c: Vector2, s: float, col: Color) -> void:
	var p := PackedVector2Array()
	for v in pts:
		p.append(c + v * s)
	draw_colored_polygon(p, Color(0.1, 0.05, 0.02, 0.6))   # тень
	for i in p.size():
		p[i] -= Vector2(2, 2)
	draw_colored_polygon(p, col)


## Картинки карточек: простые силуэты.
func _icon(kind: String, c: Vector2) -> void:
	var col := Color(1.0, 0.95, 0.82)
	match kind:
		"heart":
			draw_circle(c + Vector2(-14, -8), 18, col)
			draw_circle(c + Vector2(14, -8), 18, col)
			_poly([Vector2(-31, -2), Vector2(31, -2), Vector2(0, 34)], c, 1.0, col)
		"sword", "blade":
			var L := 1.25 if kind == "blade" else 1.0
			_poly([Vector2(-5, 18), Vector2(-5, -38 * L), Vector2(0, -48 * L), Vector2(5, -38 * L), Vector2(5, 18)], c, 1.0, col)
			_poly([Vector2(-20, 14), Vector2(20, 14), Vector2(20, 22), Vector2(-20, 22)], c, 1.0, Color(0.85, 0.65, 0.25))
			_poly([Vector2(-4, 22), Vector2(4, 22), Vector2(4, 40), Vector2(-4, 40)], c, 1.0, Color(0.5, 0.3, 0.15))
			draw_circle(c + Vector2(0, 44), 6, Color(0.85, 0.65, 0.25))
		"boot":
			_poly([Vector2(-14, -36), Vector2(10, -36), Vector2(10, 10), Vector2(34, 18), Vector2(34, 32), Vector2(-14, 32)], c, 1.0, col)
			_poly([Vector2(-18, -40), Vector2(14, -40), Vector2(14, -30), Vector2(-18, -30)], c, 1.0, Color(0.85, 0.65, 0.25))
		"bolt":
			_poly([Vector2(6, -44), Vector2(-22, 6), Vector2(-2, 6), Vector2(-10, 44), Vector2(22, -8), Vector2(2, -8), Vector2(14, -44)], c, 1.0, Color(1, 0.9, 0.3))
		"cross":
			_poly([Vector2(-10, -36), Vector2(10, -36), Vector2(10, -10), Vector2(36, -10), Vector2(36, 10), Vector2(10, 10),
				Vector2(10, 36), Vector2(-10, 36), Vector2(-10, 10), Vector2(-36, 10), Vector2(-36, -10), Vector2(-10, -10)], c, 1.0, Color(0.6, 1, 0.6))
		"target":
			for i in 4:
				draw_circle(c, 38 - i * 10, col if i % 2 == 0 else Color(0.6, 0.15, 0.15))
		"drop":
			draw_circle(c + Vector2(0, 12), 24, Color(0.9, 0.1, 0.15))
			_poly([Vector2(-21, 2), Vector2(0, -40), Vector2(21, 2)], c, 1.0, Color(0.9, 0.1, 0.15))
			draw_circle(c + Vector2(-8, 8), 6, Color(1, 0.6, 0.6))
		"spiral":
			for i in 3:
				draw_arc(c, 12 + i * 12, i * 1.2, i * 1.2 + PI * 1.4, 24, col, 6.0, true)
		"shield":
			_poly([Vector2(-30, -36), Vector2(30, -36), Vector2(30, 0), Vector2(0, 40), Vector2(-30, 0)], c, 1.0, Color(0.75, 0.78, 0.85))
			_poly([Vector2(-4, -30), Vector2(4, -30), Vector2(4, 28), Vector2(-4, 28)], c, 1.0, Color(0.85, 0.65, 0.25))
		_:
			draw_circle(c, 30, col)
