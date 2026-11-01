extends Control
## Живой фон лагеря: ночное небо, луна, холмы и кресты кладбища, туман и летящие искры костра.

var _t := 0.0
var _stars: Array = []
var _embers: Array = []   # [pos, vel, life, size]
var _graves: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 90:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.55), rng.randf_range(0.6, 2.0), rng.randf() * TAU])
	for i in 14:
		_graves.append([rng.randf(), rng.randf_range(0.8, 1.3), rng.randi() % 3, rng.randf_range(-0.12, 0.12)])


func _process(delta: float) -> void:
	_t += delta
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var vp := size
	if randf() < delta * 14.0:
		_embers.append([Vector2(randf_range(0.0, vp.x), vp.y + 10), Vector2(randf_range(-15, 15), randf_range(-60, -30)), randf_range(4.0, 8.0), randf_range(1.5, 3.5)])
	for e in _embers:
		e[0] += e[1] * delta
		e[0].x += sin(_t * 1.3 + e[3] * 10.0) * 12.0 * delta
		e[2] -= delta
	_embers = _embers.filter(func(e): return e[2] > 0.0)
	queue_redraw()


func _draw() -> void:
	var vp := size
	# Небо: вертикальный градиент полосами
	var top := Color(0.05, 0.04, 0.12)
	var bottom := Color(0.22, 0.12, 0.22)
	var bands := 24
	for i in bands:
		var k := float(i) / bands
		draw_rect(Rect2(0, vp.y * k, vp.x, vp.y / bands + 1), top.lerp(bottom, k))
	for s in _stars:
		var a: float = 0.4 + 0.4 * sin(_t * 1.5 + s[2])
		draw_circle(Vector2(s[0].x * vp.x, s[0].y * vp.y), s[1], Color(1, 1, 0.95, a))
	# Луна с ореолом
	var moon := Vector2(vp.x * 0.82, vp.y * 0.2)
	for i in 6:
		draw_circle(moon, 70 + i * 22, Color(0.9, 0.85, 1.0, 0.03))
	draw_circle(moon, 52, Color(0.95, 0.93, 0.85))
	draw_circle(moon + Vector2(16, -10), 46, Color(0.9, 0.88, 0.8, 0.35))
	draw_circle(moon + Vector2(-14, 12), 8, Color(0.8, 0.78, 0.72, 0.5))
	# Дальние холмы
	_hills(vp, vp.y * 0.62, 60.0, 0.004, Color(0.13, 0.09, 0.18))
	_hills(vp, vp.y * 0.72, 40.0, 0.007, Color(0.09, 0.06, 0.13))
	# Кресты и надгробия
	for g in _graves:
		var x: float = g[0] * vp.x
		var y := vp.y * 0.78 + sin(x * 0.007) * 30.0
		var h: float = 34.0 * g[1]
		var col := Color(0.06, 0.04, 0.09)
		draw_set_transform(Vector2(x, y), g[3])
		match g[2]:
			0:
				draw_rect(Rect2(-3, -h, 6, h), col)
				draw_rect(Rect2(-11, -h * 0.75, 22, 6), col)
			1:
				draw_rect(Rect2(-10, -h * 0.7, 20, h * 0.7), col)
				draw_circle(Vector2(0, -h * 0.7), 10, col)
			_:
				draw_rect(Rect2(-8, -h * 0.5, 16, h * 0.5), col)
		draw_set_transform(Vector2.ZERO)
	_hills(vp, vp.y * 0.86, 20.0, 0.011, Color(0.05, 0.03, 0.07))
	# Туман
	for i in 3:
		var y := vp.y * (0.7 + i * 0.08)
		var x := fmod(_t * (12.0 + i * 6.0), vp.x * 1.5) - vp.x * 0.25
		for j in 5:
			draw_circle(Vector2(x + j * 140 - 280, y), 90, Color(0.6, 0.55, 0.75, 0.025))
			draw_circle(Vector2(x + j * 140 - 280 - vp.x * 0.75, y + 20), 90, Color(0.6, 0.55, 0.75, 0.02))
	# Отсвет костра снизу
	for i in 8:
		draw_circle(Vector2(vp.x * 0.5, vp.y + 80), 200 + i * 60, Color(1.0, 0.45, 0.1, 0.025 + 0.006 * sin(_t * 6.0 + i)))
	for e in _embers:
		var a: float = clamp(e[2] / 4.0, 0.0, 1.0)
		draw_circle(e[0], e[3] * 2.2, Color(1, 0.5, 0.1, a * 0.2))
		draw_circle(e[0], e[3], Color(1, 0.8, 0.35, a))
	# Виньетка
	for i in 10:
		var w := 14.0
		var c := Color(0, 0, 0, 0.05)
		draw_rect(Rect2(0, 0, vp.x, w * i), c)
		draw_rect(Rect2(0, vp.y - w * i, vp.x, w * i), c)
		draw_rect(Rect2(0, 0, w * i, vp.y), c)
		draw_rect(Rect2(vp.x - w * i, 0, w * i, vp.y), c)


func _hills(vp: Vector2, base: float, amp: float, freq: float, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, vp.y))
	var x := 0.0
	while x <= vp.x + 20:
		pts.append(Vector2(x, base + sin(x * freq + base) * amp + sin(x * freq * 2.7) * amp * 0.3))
		x += 20.0
	pts.append(Vector2(vp.x, vp.y))
	draw_colored_polygon(pts, col)
