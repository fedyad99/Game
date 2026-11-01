extends Control
## Поле дерева талантов: узлы и связи, перетаскивание мышкой/пальцем, колесо — масштаб.
## Наведение — сигнал node_hovered, клик без перетаскивания — node_clicked.

signal node_hovered(id: String, on: bool)
signal node_clicked(id: String)

const TalentTree := preload("res://scripts/meta/talent_tree.gd")
const GOLD := Color(0.95, 0.75, 0.3)
const RADIUS := {"start": 30.0, "small": 13.0, "notable": 21.0, "keystone": 27.0, "skill": 28.0}

var profile: Node
var cls := "warrior"
var offset := Vector2.ZERO    # центр дерева в координатах экрана (смещение от середины)
var zoom := 0.62
var hovered := ""
var _drag_from := Vector2.ZERO
var _drag_start := Vector2.ZERO
var _dragging := false
var _pressed := false
var _t := 0.0
var _bursts: Array = []       # [позиция в дереве, время]


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


## Навести камеру на старт класса.
func focus_class() -> void:
	var p: Vector2 = TalentTree.node(TalentTree.start_of(cls)).pos
	offset = -p * zoom * 0.55


func burst(id: String) -> void:
	_bursts.append([TalentTree.node(id).pos, 0.0])


func _to_screen(p: Vector2) -> Vector2:
	return size / 2 + offset + p * zoom


func _node_at(screen: Vector2) -> String:
	var best := ""
	var bd := INF
	for id in TalentTree.nodes():
		var n: Dictionary = TalentTree.node(id)
		var d := _to_screen(n.pos).distance_to(screen)
		if d < max(RADIUS[n.kind] * zoom + 6.0, 16.0) and d < bd:
			bd = d
			best = id
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_pressed = true
				_dragging = false
				_drag_from = event.position
				_drag_start = offset
			else:
				if _pressed and not _dragging:
					var id := _node_at(event.position)
					if id != "":
						node_clicked.emit(id)
				_pressed = false
				_dragging = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.12)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.12)
		accept_event()
	elif event is InputEventMouseMotion:
		if _pressed and event.position.distance_to(_drag_from) > 8.0:
			_dragging = true
		if _dragging:
			offset = _drag_start + event.position - _drag_from
			_clamp_offset()
		var id := _node_at(event.position)
		if id != hovered:
			if hovered != "":
				node_hovered.emit(hovered, false)
			hovered = id
			if id != "":
				node_hovered.emit(id, true)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != "" else Control.CURSOR_DRAG
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered != "":
		node_hovered.emit(hovered, false)
		hovered = ""


func zoom_by(f: float) -> void:
	_zoom_at(size / 2, f)


func _zoom_at(screen: Vector2, f: float) -> void:
	var nz: float = clamp(zoom * f, 0.35, 1.4)
	var tree_p := (screen - size / 2 - offset) / zoom
	zoom = nz
	offset = screen - size / 2 - tree_p * zoom
	_clamp_offset()


func _clamp_offset() -> void:
	var lim := 640.0 * zoom
	offset = offset.clamp(Vector2(-lim, -lim), Vector2(lim, lim))


func _process(delta: float) -> void:
	_t += delta
	for b in _bursts:
		b[1] += delta
	_bursts = _bursts.filter(func(b): return b[1] < 0.8)
	queue_redraw()


func _state(id: String) -> String:
	if profile.is_allocated(cls, id):
		return "on"
	var n := TalentTree.node(id)
	if (n.cls != "" and n.cls != cls) or n.kind == "start":
		return "locked"
	if profile.is_reachable(cls, id):
		return "ready" if profile.free_points(cls) >= TalentTree.cost(n) else "near"
	return "off"


func _draw() -> void:
	# Фон поля: тёмный круг-«звёздная карта»
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.07, 0.55))
	var c := _to_screen(Vector2.ZERO)
	for i in 4:
		draw_arc(c, (150 + i * 150) * zoom, 0, TAU, 96, Color(0.6, 0.5, 0.8, 0.06), 1.5, true)
	var ccol: Color = TalentTree.CLASS_COLOR[cls]
	# Связи
	for e in TalentTree.edges():
		var a := TalentTree.node(e[0])
		var b := TalentTree.node(e[1])
		var sa := _state(e[0])
		var sb := _state(e[1])
		var col := Color(0.35, 0.32, 0.4, 0.7)
		var w := 3.0
		if sa == "on" and sb == "on":
			col = GOLD
			w = 6.0
		elif (sa == "on" and sb in ["ready", "near"]) or (sb == "on" and sa in ["ready", "near"]):
			col = Color(0.85, 0.8, 0.65, 0.6 + 0.25 * sin(_t * 4.0))
			w = 4.0
		elif sa == "locked" or sb == "locked":
			col = Color(0.25, 0.2, 0.28, 0.5)
		draw_line(_to_screen(a.pos), _to_screen(b.pos), col.darkened(0.6), (w + 3.0) * zoom * 1.3, true)
		draw_line(_to_screen(a.pos), _to_screen(b.pos), col, w * zoom * 1.3, true)
	# Узлы
	for id in TalentTree.nodes():
		var n: Dictionary = TalentTree.node(id)
		var p := _to_screen(n.pos)
		var r: float = RADIUS[n.kind] * zoom * 1.3
		if p.x < -60 or p.y < -60 or p.x > size.x + 60 or p.y > size.y + 60:
			continue
		var st := _state(id)
		var own: Color = TalentTree.CLASS_COLOR.get(n.cls, Color(0.75, 0.7, 0.85))
		var fill := Color(0.12, 0.1, 0.15)
		var ring := Color(0.4, 0.37, 0.45)
		match st:
			"on":
				fill = own.darkened(0.25)
				ring = GOLD
				draw_circle(p, r * 1.6, Color(GOLD, 0.12))
			"ready":
				ring = Color(1, 0.95, 0.7).lerp(GOLD, 0.5 + 0.5 * sin(_t * 5.0))
				draw_circle(p, r * (1.35 + 0.1 * sin(_t * 5.0)), Color(1, 0.9, 0.5, 0.12))
			"near":
				ring = Color(0.7, 0.65, 0.55)
			"locked":
				fill = Color(0.08, 0.07, 0.1)
				ring = Color(0.25, 0.22, 0.28)
		if id == hovered:
			draw_circle(p, r * 1.5, Color(1, 1, 1, 0.12))
		if n.kind in ["notable", "keystone", "skill", "start"]:
			# Двойная оправа у крупных узлов
			draw_circle(p, r + 5 * zoom, Color(0.1, 0.07, 0.04))
			draw_arc(p, r + 3 * zoom, 0, TAU, 32, ring.darkened(0.2), 3.0 * zoom, true)
		if n.kind == "skill":
			# Ромб навыка
			var pts := PackedVector2Array([p + Vector2(0, -r * 1.25), p + Vector2(r * 1.25, 0), p + Vector2(0, r * 1.25), p + Vector2(-r * 1.25, 0)])
			draw_colored_polygon(pts, fill if st != "on" else own)
			draw_polyline(pts + PackedVector2Array([pts[0]]), ring, 3.5 * zoom, true)
		else:
			draw_circle(p, r, fill)
			draw_arc(p, r, 0, TAU, 32, ring, (3.0 if n.kind == "small" else 4.0) * zoom, true)
		_glyph(n, p, r * 0.62, Color(1, 0.97, 0.88) if st == "on" else (Color(0.9, 0.85, 0.75) if st != "locked" else Color(0.35, 0.32, 0.38)))
	# Вспышки при изучении
	for b in _bursts:
		var k: float = b[1] / 0.8
		var p2 := _to_screen(b[0])
		draw_arc(p2, (20 + 90 * k) * zoom, 0, TAU, 40, Color(1, 0.85, 0.4, 1.0 - k), 5.0 * (1.0 - k) + 1.0, true)
		draw_circle(p2, (30 * (1.0 - k)) * zoom, Color(1, 0.95, 0.7, 0.6 * (1.0 - k)))
	# Подпись класса у старта
	var sp := _to_screen(TalentTree.node(TalentTree.start_of(cls)).pos)
	draw_string(get_theme_default_font(), sp + Vector2(-60, -48 * zoom - 6), "Твой старт", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, ccol)


## Значок внутри узла по главному эффекту.
func _glyph(n: Dictionary, c: Vector2, k: float, col: Color) -> void:
	var key := ""
	if n.kind == "skill":
		key = n.skill
	elif n.kind == "start":
		key = "start_" + n.cls
	elif not n.stats.is_empty():
		key = n.stats.keys()[0]
	var w: float = max(1.5, k * 0.22)
	match key:
		"max_hp", "max_hp_pct":
			draw_circle(c + Vector2(-k * 0.35, -k * 0.15), k * 0.42, col)
			draw_circle(c + Vector2(k * 0.35, -k * 0.15), k * 0.42, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.75, 0), c + Vector2(k * 0.75, 0), c + Vector2(0, k * 0.8)]), col)
		"damage", "damage_mult":
			draw_line(c + Vector2(-k * 0.7, k * 0.7), c + Vector2(k * 0.7, -k * 0.7), col, w * 1.4, true)
			draw_line(c + Vector2(-k * 0.6, k * 0.1), c + Vector2(-k * 0.1, k * 0.6), col, w, true)
		"attack_speed_mult":
			draw_polyline(PackedVector2Array([c + Vector2(k * 0.2, -k), c + Vector2(-k * 0.4, 0), c + Vector2(k * 0.3, 0), c + Vector2(-k * 0.2, k)]), col, w, true)
		"crit_chance":
			draw_arc(c, k * 0.7, 0, TAU, 20, col, w, true)
			draw_circle(c, k * 0.2, col)
		"move_speed_mult":
			draw_line(c + Vector2(-k * 0.7, 0), c + Vector2(k * 0.7, 0), col, w, true)
			draw_line(c + Vector2(k * 0.2, -k * 0.5), c + Vector2(k * 0.7, 0), col, w, true)
			draw_line(c + Vector2(k * 0.2, k * 0.5), c + Vector2(k * 0.7, 0), col, w, true)
		"regen":
			draw_rect(Rect2(c - Vector2(k * 0.2, k * 0.7), Vector2(k * 0.4, k * 1.4)), col)
			draw_rect(Rect2(c - Vector2(k * 0.7, k * 0.2), Vector2(k * 1.4, k * 0.4)), col)
		"damage_taken_mult":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.65, -k * 0.6), c + Vector2(k * 0.65, -k * 0.6), c + Vector2(k * 0.55, k * 0.2), c + Vector2(0, k * 0.8), c + Vector2(-k * 0.55, k * 0.2)]), col)
		"lifesteal":
			draw_circle(c + Vector2(0, k * 0.25), k * 0.45, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.42, k * 0.1), c + Vector2(0, -k * 0.75), c + Vector2(k * 0.42, k * 0.1)]), col)
		"attack_range":
			draw_line(c + Vector2(-k * 0.7, k * 0.7), c + Vector2(k * 0.6, -k * 0.6), col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.75, -k * 0.75), c + Vector2(k * 0.15, -k * 0.6), c + Vector2(k * 0.6, -k * 0.15)]), col)
		"skill_cd_mult":
			draw_arc(c, k * 0.7, -PI / 2, PI * 1.1, 20, col, w, true)
			draw_line(c, c + Vector2(0, -k * 0.5), col, w, true)
			draw_line(c, c + Vector2(k * 0.35, 0), col, w, true)
		"second_wind":
			draw_arc(c, k * 0.7, 0, PI * 1.6, 20, col, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.7, -k * 0.5), c + Vector2(k * 1.0, k * 0.1), c + Vector2(k * 0.35, k * 0.05)]), col)
		"gold_mult", "xp_mult":
			for i in 5:
				var a := -PI / 2 + TAU * i / 5.0
				draw_line(c, c + Vector2(cos(a), sin(a)) * k * 0.8, col, w, true)
		"start_warrior", "charge", "warcry":
			draw_line(c + Vector2(0, -k * 0.85), c + Vector2(0, k * 0.5), col, w * 1.5, true)
			draw_line(c + Vector2(-k * 0.45, k * 0.2), c + Vector2(k * 0.45, k * 0.2), col, w, true)
			if key == "warcry":
				draw_arc(c + Vector2(k * 0.2, 0), k * 0.9, -0.6, 0.6, 8, col, w * 0.7, true)
		"start_archer", "trap", "pierce":
			draw_arc(c + Vector2(k * 0.3, 0), k * 0.8, PI * 0.6, PI * 1.4, 16, col, w, true)
			draw_line(c + Vector2(-k * 0.75, 0), c + Vector2(k * 0.8, 0), col, w * 0.8, true)
			if key == "trap":
				draw_circle(c, k * 0.25, col)
		"start_mage", "frost_nova", "chain_lightning":
			for i in 4:
				var a := TAU * i / 4.0 + _t * 0.5
				draw_line(c, c + Vector2(cos(a), sin(a)) * k * 0.85, col, w, true)
			draw_circle(c, k * 0.3, col)
		_:
			draw_circle(c, k * 0.3, col)
