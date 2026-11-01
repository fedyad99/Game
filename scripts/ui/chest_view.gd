extends Control
## Нарисованный сундук с анимацией: покачивание в ожидании, тряска, открытие крышки,
## свет изнутри цвета редкости, лучи и искры. Сигнал opened — крышка открылась (пора показать добычу).

signal opened

var shake := 0.0        # 0..1 сила тряски
var lid := 0.0          # 0 — закрыт, 1 — открыт
var glow := 0.0         # свечение изнутри
var glow_color := Color(1, 0.85, 0.4)
var count := 0          # сколько сундуков есть (значок)
var busy := false
var _t := 0.0
var _sparks: Array = []   # [pos, vel, life, color]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	for s in _sparks:
		s[1].y += 260.0 * delta
		s[0] += s[1] * delta
		s[2] -= delta
	_sparks = _sparks.filter(func(s): return s[2] > 0.0)
	if glow > 0.05 and randf() < delta * 30.0 * glow:
		var c := size / 2 + Vector2(randf_range(-80, 80), 10)
		_sparks.append([c, Vector2(randf_range(-40, 40), randf_range(-220, -120)), randf_range(0.6, 1.2), glow_color.lightened(0.4)])
	queue_redraw()


## Открыть: тряска -> крышка -> вспышка. color — цвет добычи (редкость).
func play_open(color: Color) -> void:
	if busy:
		return
	busy = true
	glow_color = color
	lid = 0.0
	glow = 0.0
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("chest_shake", 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(self, "shake", 1.0, 0.15)
	tw.tween_interval(0.45)
	tw.tween_callback(func():
		shake = 0.0
		if sfx:
			sfx.play("chest_open", 0.0, 0.0)
		for i in 40:
			var a := randf_range(-PI * 0.95, -PI * 0.05)
			_sparks.append([size / 2 + Vector2(0, 10), Vector2(cos(a), sin(a)) * randf_range(150, 420), randf_range(0.6, 1.4), color.lightened(randf_range(0.0, 0.6))]))
	tw.tween_property(self, "lid", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "glow", 1.0, 0.3)
	tw.tween_callback(func(): opened.emit())
	tw.tween_interval(1.2)
	tw.tween_callback(func(): busy = false)


## Закрыть обратно (после показа добычи).
func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "glow", 0.0, 0.4)
	tw.parallel().tween_property(self, "lid", 0.0, 0.35)


func bounce() -> void:
	pivot_offset = size / 2
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 0.9), 0.08)
	tw.tween_property(self, "scale", Vector2(0.95, 1.08), 0.1)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)


func _draw() -> void:
	var c := size / 2 + Vector2(0, 40)
	var w := 230.0
	var h := 120.0
	# Лучи света
	if glow > 0.01:
		for i in 14:
			var a := _t * 0.35 + TAU * i / 14.0
			var p1 := c + Vector2(0, -h * 0.4)
			var pts := PackedVector2Array([p1, p1 + Vector2(cos(a - 0.08), sin(a - 0.08)) * 330, p1 + Vector2(cos(a + 0.08), sin(a + 0.08)) * 330])
			draw_colored_polygon(pts, Color(glow_color, 0.08 * glow))
		for i in 6:
			draw_circle(c + Vector2(0, -h * 0.4), 60 + i * 30, Color(glow_color, 0.05 * glow))
	# Тень
	draw_set_transform(c + Vector2(0, h * 0.5 + 8), 0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, w * 0.6, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# Покачивание / тряска
	var idle_rot := sin(_t * 2.0) * 0.015 if not busy else 0.0
	var shake_off := Vector2(randf_range(-6, 6), randf_range(-3, 3)) * shake
	var rot := idle_rot + randf_range(-0.05, 0.05) * shake
	draw_set_transform(c + shake_off, rot)
	var body := Rect2(-w / 2, -h * 0.35, w, h * 0.85)
	var wood := Color(0.5, 0.29, 0.12)
	var dark := Color(0.22, 0.11, 0.04)
	var metal := Color(0.92, 0.72, 0.28)
	# Внутренность (видно, когда крышка поднята)
	var open_h := 22.0 * lid
	if lid > 0.02:
		# Задняя стенка изнутри и сияние добычи
		draw_rect(Rect2(-w / 2 + 6, -h * 0.35 - open_h, w - 12, open_h + 4), Color(0.12, 0.05, 0.02))
		draw_rect(Rect2(-w / 2 + 12, -h * 0.35 - open_h * 0.7, w - 24, open_h * 0.7 + 2), Color(glow_color.lerp(Color.WHITE, 0.5), glow))
	# Корпус
	draw_rect(body, wood)
	for i in 3:
		draw_line(Vector2(-w / 2, body.position.y + body.size.y * (i + 1) / 4.0), Vector2(w / 2, body.position.y + body.size.y * (i + 1) / 4.0), dark, 2.0)
	draw_rect(body, dark, false, 5.0)
	for x in [-w / 2 + 28, w / 2 - 40]:
		draw_rect(Rect2(x, body.position.y, 12, body.size.y), metal)
		draw_rect(Rect2(x, body.position.y, 12, body.size.y), metal.darkened(0.4), false, 2.0)
	for p in [Vector2(-w / 2 + 6, body.position.y + 6), Vector2(w / 2 - 6, body.position.y + 6), Vector2(-w / 2 + 6, body.end.y - 6), Vector2(w / 2 - 6, body.end.y - 6)]:
		draw_circle(p, 6, metal)
	# Крышка: при открытии уходит вверх и «поворачивается» к зрителю внутренней стороной
	# Крышка откидывается назад: нижний край (петли) уходит вверх-назад,
	# видна её внутренняя, более тёмная сторона
	var lift := -h * 0.35 - open_h
	var lid_h := h * 0.5 + h * 0.25 * lid
	var top_y := lift - lid_h
	var inset := 10.0 + 8.0 * lid
	var lid_pts := PackedVector2Array([Vector2(-w / 2 + 4 * lid, lift), Vector2(-w / 2 + inset, top_y), Vector2(w / 2 - inset, top_y), Vector2(w / 2 - 4 * lid, lift)])
	draw_colored_polygon(lid_pts, wood.lightened(0.08).lerp(Color(0.32, 0.17, 0.07), lid))
	if lid > 0.3:
		draw_rect(Rect2(-w / 2 + inset + 8, top_y + 8, w - 2 * inset - 16, lid_h - 14), Color(0.25, 0.12, 0.05))
	draw_polyline(lid_pts + PackedVector2Array([lid_pts[0]]), dark, 5.0)
	for x in [-w / 2 + 28, w / 2 - 40]:
		draw_rect(Rect2(x, top_y, 12, lift - top_y), metal)
	# Замок
	if lid < 0.3:
		draw_rect(Rect2(-20, -h * 0.35 - 20, 40, 44), metal)
		draw_rect(Rect2(-20, -h * 0.35 - 20, 40, 44), metal.darkened(0.45), false, 3.0)
		draw_circle(Vector2(0, -h * 0.35), 6, dark)
		draw_rect(Rect2(-2, -h * 0.35, 4, 12), dark)
	# Блеск
	var shine := fmod(_t * 0.6, 3.0)
	if shine < 1.0 and not busy:
		var x := -w / 2 + shine * w
		draw_line(Vector2(x, body.position.y + 4), Vector2(x - 20, body.end.y - 4), Color(1, 1, 1, 0.18), 8.0)
	draw_set_transform(Vector2.ZERO)
	for s in _sparks:
		var a: float = clamp(s[2], 0.0, 1.0)
		draw_circle(s[0], 5.0 * a, Color(s[3], a * 0.3))
		draw_circle(s[0], 2.2, Color(s[3], a))
	# Сколько сундуков
	if count > 0:
		var b := Vector2(size.x / 2 + w / 2 - 6, c.y - h * 0.9)
		draw_circle(b, 22, Color(0.15, 0.08, 0.03))
		draw_circle(b, 19, Color(0.85, 0.2, 0.15))
		var font := get_theme_default_font()
		draw_string(font, b + Vector2(-20, 7), str(count), HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color.WHITE)
