extends Control
## Игровой интерфейс: портрет с уровнем, полоски здоровья и опыта, время/убийства/золото,
## полоска босса, ячейка навыка и кнопка «Мои карточки». Всё рисуется кодом.

signal deck_pressed

const GOLD := Color(0.95, 0.75, 0.3)
const DARK := Color(0.08, 0.06, 0.1, 0.85)

var hp := 100.0
var max_hp := 100.0
var xp := 0
var xp_need := 6
var level := 1
var time_s := 0.0
var kills := 0
var gold := 0
var boss_name := ""
var boss_hp := 0.0
var boss_max := 1.0
var skills: Array = []   # [[id, название, доля перезарядки 0..1], ...]
var portrait_color := Color(0.2, 0.3, 0.55)   # цвет портрета зависит от класса
var _shown_hp := 100.0    # плавная «тень» урона на полоске
var _level_pulse := 0.0
var _font: Font
var _deck_btn: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_deck_btn = Button.new()
	_deck_btn.text = "  Карточки  [Tab]"
	_deck_btn.focus_mode = Control.FOCUS_NONE
	_deck_btn.custom_minimum_size = Vector2(190, 46)
	_deck_btn.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = DARK if st == "normal" else Color(0.25, 0.15, 0.08, 0.95)
		sb.border_color = GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		_deck_btn.add_theme_stylebox_override(st, sb)
	_deck_btn.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	_deck_btn.pressed.connect(func(): deck_pressed.emit())
	add_child(_deck_btn)


func set_level(l: int) -> void:
	if l > level:
		_level_pulse = 1.0
	level = l


func _process(delta: float) -> void:
	_shown_hp = move_toward(_shown_hp, hp, max_hp * delta * 0.6) if _shown_hp > hp else hp
	_level_pulse = max(0.0, _level_pulse - delta * 1.5)
	var vp := get_viewport_rect().size
	_deck_btn.position = Vector2(vp.x - 210, vp.y - 66)
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	_draw_player_frame()
	_draw_info(vp)
	if boss_name != "":
		_draw_boss(vp)
	for i in skills.size():
		_draw_skill(Vector2(vp.x - 260 - i * 82, vp.y - 62), skills[i][0], skills[i][1], skills[i][2])


func _rrect(r: Rect2, radius: int, col: Color, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _text(pos: Vector2, t: String, fs: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(_font, pos, t, align, width, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, t, align, width, fs, col)


## Полоска с градиентом, бликом и рамкой.
func _bar(r: Rect2, ratio: float, col: Color, ghost := -1.0) -> void:
	_rrect(r.grow(3), 9, Color(0.15, 0.1, 0.06), GOLD.darkened(0.2), 2)
	_rrect(r, 7, Color(0.05, 0.03, 0.05))
	if ghost > ratio:
		_rrect(Rect2(r.position, Vector2(r.size.x * ghost, r.size.y)), 7, Color(1, 0.9, 0.6, 0.8))
	if ratio > 0.0:
		var fill := Rect2(r.position, Vector2(max(r.size.x * ratio, 8), r.size.y))
		_rrect(fill, 7, col)
		_rrect(Rect2(fill.position + Vector2(3, 2), Vector2(fill.size.x - 6, fill.size.y * 0.38)), 5, Color(1, 1, 1, 0.22))


func _draw_player_frame() -> void:
	var c := Vector2(62, 62)
	# Портрет
	draw_circle(c, 50, Color(0.15, 0.1, 0.06))
	draw_circle(c, 46, GOLD.darkened(0.15))
	draw_circle(c, 41, portrait_color)
	draw_circle(c + Vector2(0, -6), 30, portrait_color.lightened(0.2))
	# Шлем-эмблема
	var helm := PackedVector2Array([c + Vector2(-16, 14), c + Vector2(-18, -10), c + Vector2(-8, -22), c + Vector2(8, -22),
		c + Vector2(18, -10), c + Vector2(16, 14), c + Vector2(6, 22), c + Vector2(-6, 22)])
	draw_colored_polygon(helm, Color(0.85, 0.87, 0.92))
	draw_rect(Rect2(c + Vector2(-12, -4), Vector2(24, 5)), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(c + Vector2(-2, -4), Vector2(4, 20)), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(c + Vector2(-3, -30), Vector2(6, 10)), Color(0.85, 0.2, 0.2))
	# Значок уровня
	var b := c + Vector2(36, 36)
	var pr := 18 + 6 * _level_pulse
	draw_circle(b, pr + 3, Color(0.15, 0.1, 0.06))
	draw_circle(b, pr, GOLD.lerp(Color(1, 1, 0.7), _level_pulse))
	_text(b + Vector2(-20, 7), str(level), 20, Color(0.25, 0.12, 0.0) if _level_pulse <= 0 else Color.WHITE, 40, HORIZONTAL_ALIGNMENT_CENTER)
	# Здоровье
	var hr := Rect2(120, 30, 300, 26)
	var hp_col := Color(0.85, 0.15, 0.15) if hp / max_hp > 0.3 else Color(1.0, 0.3, 0.1).lerp(Color(1, 0.1, 0.1), absf(sin(Time.get_ticks_msec() / 150.0)))
	_bar(hr, hp / max_hp, hp_col, _shown_hp / max_hp)
	_text(Vector2(hr.position.x, hr.position.y + 20), "%d / %d" % [ceil(hp), max_hp], 17, Color.WHITE, hr.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	# Опыт
	var xr := Rect2(120, 66, 260, 14)
	_bar(xr, float(xp) / max(1, xp_need), Color(0.35, 0.6, 1.0))
	_text(Vector2(xr.position.x + 4, xr.position.y + 31), "Уровень %d  ·  %d / %d опыта" % [level, xp, xp_need], 14, Color(0.85, 0.9, 1.0))


func _draw_info(vp: Vector2) -> void:
	var r := Rect2(vp.x - 300, 18, 282, 46)
	_rrect(r, 12, DARK, GOLD.darkened(0.2), 2)
	var x := r.position.x + 18
	var y := r.position.y + 31
	# Часы
	draw_arc(Vector2(x + 8, y - 8), 9, 0, TAU, 20, Color(0.9, 0.9, 1), 2.5, true)
	draw_line(Vector2(x + 8, y - 8), Vector2(x + 8, y - 14), Color(0.9, 0.9, 1), 2)
	draw_line(Vector2(x + 8, y - 8), Vector2(x + 13, y - 8), Color(0.9, 0.9, 1), 2)
	_text(Vector2(x + 22, y), "%d:%02d" % [int(time_s) / 60, int(time_s) % 60], 19, Color.WHITE)
	# Черепок
	x += 98
	draw_circle(Vector2(x + 8, y - 10), 9, Color(0.92, 0.9, 0.85))
	draw_rect(Rect2(x + 3, y - 4, 10, 6), Color(0.92, 0.9, 0.85))
	draw_circle(Vector2(x + 4, y - 10), 2.5, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(x + 12, y - 10), 2.5, Color(0.1, 0.1, 0.1))
	_text(Vector2(x + 22, y), str(kills), 19, Color.WHITE)
	# Монета
	x += 82
	draw_circle(Vector2(x + 8, y - 8), 10, Color(0.75, 0.5, 0.1))
	draw_circle(Vector2(x + 8, y - 8), 7.5, Color(1, 0.82, 0.3))
	_text(Vector2(x + 22, y), str(gold), 19, Color(1, 0.88, 0.45))


func _draw_boss(vp: Vector2) -> void:
	var w := 520.0
	var r := Rect2(vp.x / 2 - w / 2, 92, w, 20)
	_text(Vector2(r.position.x, r.position.y - 10), boss_name, 24, Color(1, 0.8, 0.5), w, HORIZONTAL_ALIGNMENT_CENTER)
	_bar(r, boss_hp / boss_max, Color(0.6, 0.15, 0.75))
	_text(Vector2(r.position.x, r.position.y + 16), "%d / %d" % [ceil(boss_hp), boss_max], 14, Color.WHITE, w, HORIZONTAL_ALIGNMENT_CENTER)
	for s in [-1, 1]:
		var p := Vector2(vp.x / 2 + s * (w / 2 + 18), r.position.y + 10)
		var d := PackedVector2Array([p + Vector2(0, -14), p + Vector2(12, 0), p + Vector2(0, 14), p + Vector2(-12, 0)])
		draw_colored_polygon(d, Color(0.6, 0.15, 0.75))
		draw_polyline(d + PackedVector2Array([d[0]]), GOLD, 2, true)


const SKILL_COLORS := {"whirlwind": Color(0.6, 0.45, 0.2), "volley": Color(0.25, 0.55, 0.3), "meteor": Color(0.75, 0.3, 0.1),
	"charge": Color(0.7, 0.25, 0.2), "warcry": Color(0.8, 0.5, 0.15), "trap": Color(0.45, 0.45, 0.5),
	"pierce": Color(0.2, 0.5, 0.45), "frost_nova": Color(0.25, 0.55, 0.85), "chain_lightning": Color(0.35, 0.35, 0.85)}


func _draw_skill(c: Vector2, id: String, skill_name: String, skill_ratio: float) -> void:
	draw_circle(c, 30, Color(0.15, 0.1, 0.06))
	draw_circle(c, 27, GOLD.darkened(0.15) if skill_ratio <= 0.0 else GOLD.darkened(0.5))
	draw_circle(c, 24, SKILL_COLORS.get(id, Color(0.25, 0.3, 0.7)))
	var w := Color(1, 0.95, 0.82)
	match id:
		"charge", "pierce":
			draw_line(c + Vector2(-12, 0), c + Vector2(12, 0), w, 3.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(14, 0), c + Vector2(5, -7), c + Vector2(5, 7)]), w)
			draw_line(c + Vector2(-14, -6), c + Vector2(-6, -6), w, 2.0, true)
			draw_line(c + Vector2(-14, 6), c + Vector2(-6, 6), w, 2.0, true)
		"warcry":
			for i in 3:
				draw_arc(c + Vector2(-8, 0), 6 + i * 6, -0.7, 0.7, 10, w, 2.5, true)
		"trap":
			draw_arc(c, 10, 0, TAU, 20, w, 3.0, true)
			for i in 6:
				var a := TAU * i / 6.0
				draw_line(c + Vector2(cos(a), sin(a)) * 10, c + Vector2(cos(a), sin(a)) * 16, w, 2.0, true)
		"frost_nova":
			for i in 3:
				var a := PI * i / 3.0
				draw_line(c - Vector2(cos(a), sin(a)) * 14, c + Vector2(cos(a), sin(a)) * 14, w, 2.5, true)
		"chain_lightning":
			draw_polyline(PackedVector2Array([c + Vector2(4, -16), c + Vector2(-6, 0), c + Vector2(4, 0), c + Vector2(-4, 16)]), w, 3.0, true)
		_:
			for i in 3:
				draw_arc(c, 6 + i * 6, i * 1.2, i * 1.2 + PI * 1.4, 16, w, 3.0, true)
	if skill_ratio > 0.0:   # затемнение перезарядки по кругу
		var pts := PackedVector2Array([c])
		var steps := 32
		for i in steps + 1:
			var a := -PI / 2 + TAU * skill_ratio * i / steps
			pts.append(c + Vector2(cos(a), sin(a)) * 24)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
	_text(c + Vector2(-40, 46), skill_name, 14, Color(1, 0.9, 0.7), 80, HORIZONTAL_ALIGNMENT_CENTER)
