extends Control
## Иконка предмета: рамка цвета редкости и картинка. Оружие — заранее отрисованная
## 3D-модель (assets/icons/items/<id>.png), доспех и амулет рисуются кодом в цвет предмета.
## Наведение мышкой — сигнал hovered, нажатие — pressed, двойной клик — activated.

signal hovered(icon: Control, on: bool)
signal pressed(icon: Control)
signal activated(icon: Control)

const Items := preload("res://scripts/meta/items.gd")
const ICON_DIR := "res://assets/icons/items/"

var item: Dictionary = {}
var slot_hint := ""        # пустая ячейка: какой слот показать бледным значком
var owned := true          # false — предмет ещё не найден (тусклый, с замком)
var equipped := false      # зелёная галочка в углу
var selected := false      # подсветка выбранной иконки
var _hover := false
var _tex: Texture2D


static func create(it: Dictionary, size_px := 84.0) -> Control:
	var ic: Control = load("res://scripts/ui/item_icon.gd").new()
	ic.item = it
	ic.custom_minimum_size = Vector2(size_px, size_px)
	return ic


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = custom_minimum_size / 2
	if not item.is_empty() and ResourceLoader.exists(ICON_DIR + item.id + ".png"):
		_tex = load(ICON_DIR + item.id + ".png")
	mouse_entered.connect(func():
		_hover = true
		scale = Vector2(1.06, 1.06)
		hovered.emit(self, true)
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		scale = Vector2.ONE
		hovered.emit(self, false)
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			activated.emit(self)
		else:
			pressed.emit(self)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit(self)
		accept_event()


func _process(_d: float) -> void:
	# Легендарные предметы мерцают
	if not item.is_empty() and item.rarity == "legendary" and owned:
		queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func _draw() -> void:
	var s := size
	var r := Rect2(Vector2.ZERO, s)
	if item.is_empty():
		_box(r, Color(0.1, 0.08, 0.12, 0.9), Color(0.35, 0.3, 0.4), 2)
		if slot_hint != "":
			_draw_slot_glyph(r.get_center(), s.x * 0.3, Color(1, 1, 1, 0.13))
		return
	var col: Color = Items.RARITY_COLOR[item.rarity]
	if not owned:
		col = col.darkened(0.55)
	# Фон: тёмный с цветным свечением снизу
	_box(r, Color(0.09, 0.07, 0.11), col, 0)
	for i in 6:
		var k := float(i) / 6.0
		var c := Color(col, 0.05 + 0.05 * k)
		draw_circle(Vector2(s.x / 2, s.y * 0.55), s.x * (0.42 - k * 0.07), c)
	if item.rarity == "legendary" and owned:
		var t := Time.get_ticks_msec() / 400.0
		draw_circle(Vector2(s.x / 2, s.y / 2), s.x * 0.3, Color(1, 0.7, 0.2, 0.08 + 0.05 * sin(t)))
	# Картинка
	var mod := Color.WHITE if owned else Color(0.35, 0.35, 0.42, 0.9)
	if _tex:
		draw_texture_rect(_tex, r.grow(-s.x * 0.06), false, mod)
	elif item.slot == "armor":
		_draw_armor(r.get_center(), s.x * 0.34, item.look.get("cape", Color.GRAY) * mod)
	elif item.slot == "amulet":
		_draw_amulet(r.get_center(), s.x * 0.34, item.look.get("aura", Color.WHITE) * mod)
	# Рамка
	var bw := 3 if (_hover or selected) else 2
	var border := col.lightened(0.35) if (_hover or selected) else col
	_box(r, Color(0, 0, 0, 0), border, bw)
	if selected:
		_box(r.grow(3), Color(0, 0, 0, 0), Color(1, 0.95, 0.7), 2)
	# Уголки
	for p in [Vector2(4, 4), Vector2(s.x - 4, 4), Vector2(4, s.y - 4), Vector2(s.x - 4, s.y - 4)]:
		draw_circle(p, 3, border)
	if equipped:
		var c2 := Vector2(s.x - 13, 13)
		draw_circle(c2, 10, Color(0.1, 0.35, 0.12))
		draw_circle(c2, 8, Color(0.3, 0.85, 0.35))
		draw_polyline(PackedVector2Array([c2 + Vector2(-4, 0), c2 + Vector2(-1, 3), c2 + Vector2(4, -3)]), Color.WHITE, 2.5, true)
	if not owned:
		_draw_lock(Vector2(s.x / 2, s.y / 2), s.x * 0.14)


func _box(r: Rect2, bg: Color, border: Color, bw: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, r)


## Нагрудник: плечи, корпус и пояс в цвете доспеха.
func _draw_armor(c: Vector2, k: float, col: Color) -> void:
	var dark := col.darkened(0.45)
	var body := PackedVector2Array([
		c + Vector2(-0.55, -0.85) * k, c + Vector2(-0.22, -0.7) * k, c + Vector2(0, -0.45) * k, c + Vector2(0.22, -0.7) * k,
		c + Vector2(0.55, -0.85) * k, c + Vector2(1.05, -0.55) * k, c + Vector2(0.85, -0.05) * k, c + Vector2(0.62, -0.2) * k,
		c + Vector2(0.62, 0.85) * k, c + Vector2(-0.62, 0.85) * k, c + Vector2(-0.62, -0.2) * k, c + Vector2(-0.85, -0.05) * k,
		c + Vector2(-1.05, -0.55) * k])
	draw_colored_polygon(body, col)
	draw_polyline(body + PackedVector2Array([body[0]]), dark, 2.5, true)
	draw_line(c + Vector2(0, -0.45) * k, c + Vector2(0, 0.55) * k, dark, 2.0, true)
	draw_rect(Rect2(c + Vector2(-0.62, 0.5) * k, Vector2(1.24, 0.18) * k), dark)
	draw_rect(Rect2(c + Vector2(-0.1, 0.48) * k, Vector2(0.2, 0.22) * k), Color(0.95, 0.8, 0.35))
	# Блик
	draw_line(c + Vector2(-0.4, -0.3) * k, c + Vector2(-0.4, 0.3) * k, Color(1, 1, 1, 0.35), 3.0, true)


## Амулет: цепочка и камень цвета свечения.
func _draw_amulet(c: Vector2, k: float, col: Color) -> void:
	var chain := Color(0.95, 0.8, 0.4)
	draw_arc(c + Vector2(0, -0.35) * k, 0.75 * k, PI * 1.08, PI * 1.92, 20, chain, 2.5, true)
	draw_arc(c + Vector2(0, -0.35) * k, 0.75 * k, PI * 0.08 + PI, PI * 0.2 + PI, 4, chain, 2.5, true)
	var g := c + Vector2(0, 0.35) * k
	var gem := PackedVector2Array([g + Vector2(0, -0.55) * k, g + Vector2(0.45, -0.1) * k, g + Vector2(0, 0.6) * k, g + Vector2(-0.45, -0.1) * k])
	draw_circle(g, 0.62 * k, Color(col, 0.25))
	draw_colored_polygon(gem, col)
	draw_polyline(gem + PackedVector2Array([gem[0]]), chain, 3.0, true)
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -0.45) * k, g + Vector2(0.2, -0.12) * k, g + Vector2(-0.1, 0.05) * k]), Color(1, 1, 1, 0.55))
	draw_line(c + Vector2(-0.75, -0.35) * k, g + Vector2(-0.2, -0.5) * k, chain, 2.5, true)
	draw_line(c + Vector2(0.75, -0.35) * k, g + Vector2(0.2, -0.5) * k, chain, 2.5, true)


func _draw_lock(c: Vector2, k: float) -> void:
	draw_arc(c + Vector2(0, -0.4) * k, 0.55 * k, PI, TAU, 12, Color(0.75, 0.75, 0.8), 3.0, true)
	draw_rect(Rect2(c + Vector2(-0.85, -0.4) * k, Vector2(1.7, 1.3) * k), Color(0.75, 0.75, 0.8))
	draw_circle(c + Vector2(0, 0.15) * k, 0.2 * k, Color(0.2, 0.2, 0.25))


## Бледный значок пустой ячейки.
func _draw_slot_glyph(c: Vector2, k: float, col: Color) -> void:
	match slot_hint:
		"weapon":
			draw_line(c + Vector2(-0.8, 0.8) * k, c + Vector2(0.8, -0.8) * k, col, 6.0, true)
			draw_line(c + Vector2(-0.6, 0.2) * k, c + Vector2(-0.2, 0.6) * k, col, 6.0, true)
		"armor":
			_draw_armor(c, k, col)
		"amulet":
			_draw_amulet(c, k, col)
