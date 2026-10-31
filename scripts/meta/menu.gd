extends Control
## Главное меню (лагерь). Вкладки: Герой (класс и экипировка), Таланты, Сундуки, Библиотека.

const Classes := preload("res://scripts/player/classes.gd")
const Items := preload("res://scripts/meta/items.gd")
const Talents := preload("res://scripts/meta/talents.gd")
const CharacterModel := preload("res://scripts/game/character_model.gd")
const GOLD := Color(0.95, 0.75, 0.3)
const STAT_NAMES := {"max_hp": "Здоровье", "damage": "Урон", "attack_range": "Дальность"}

var profile: Node
var _pages := {}
var _tab_buttons := {}
var _top_label: Label
var _preview_root: Node3D
var _preview_model: Node3D
var _class_buttons := {}
var _hero_info: Label
var _equip_box: VBoxContainer
var _bag_grid: GridContainer
var _talent_grid: GridContainer
var _talent_points: Label
var _chest_count: Label
var _chest_result: PanelContainer
var _chest_result_label: Label
var _chest_draw: Control
var _library_box: VBoxContainer
var _popup: PanelContainer
var _popup_label: Label


func _ready() -> void:
	profile = get_node("/root/Profile")
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_top()
	_pages["hero"] = _build_hero_page()
	_pages["talents"] = _build_talent_page()
	_pages["chests"] = _build_chest_page()
	_pages["library"] = _build_library_page()
	_build_popup()
	_show_page("hero")
	_select_class(profile.selected_class)
	if not profile.last_run.is_empty():
		_show_run_summary()


# ---------- Общие элементы ----------

func _sb(col := Color(0.08, 0.06, 0.1, 0.92), border := GOLD.darkened(0.25), bw := 2, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


func _label(t: String, fs: int, col := Color(1, 0.95, 0.85)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


func _button(t: String, fs: int, col: Color, border := GOLD) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	b.add_theme_stylebox_override("normal", _sb(col, border, 2))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.15), border.lightened(0.3), 3))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.2), border, 3))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.18, 0.17, 0.2), Color(0.35, 0.35, 0.35), 2))
	return b


func _page() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


## Карточка предмета: рамка цвета редкости, название, слот, характеристики.
func _item_tile(it: Dictionary, width: float, state := "") -> Button:
	var col: Color = Items.RARITY_COLOR[it.rarity]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var slot_text: String = Items.SLOT_NAME[it.slot]
	if it.slot == "weapon":
		slot_text += " · " + Classes.CLASSES[it.cls].name
	b.text = "%s\n%s · %s\n%s" % [it.name, slot_text, Items.RARITY_NAME[it.rarity], Items.describe(it)]
	if state != "":
		b.text += "\n" + state
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(width, 96)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", col.lightened(0.35))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _sb(Color(0.12, 0.1, 0.14), col, 2, 8))
	b.add_theme_stylebox_override("hover", _sb(Color(0.2, 0.16, 0.22), col.lightened(0.3), 3, 8))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.2, 0.16, 0.22), col, 3, 8))
	return b


# ---------- Верх: название, ресурсы, вкладки ----------

func _build_top() -> void:
	var title := _label("ПРОКЛЯТОЕ КЛАДБИЩЕ", 30, Color(1, 0.85, 0.45))
	title.position = Vector2(24, 14)
	add_child(title)
	_top_label = _label("", 20, Color(1, 0.85, 0.4))
	_top_label.position = Vector2(24, 56)
	add_child(_top_label)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(560, 20)
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for t in [["hero", "Герой"], ["talents", "Таланты"], ["chests", "Сундуки"], ["library", "Библиотека"]]:
		var b := _button(t[1], 18, Color(0.16, 0.12, 0.2))
		b.custom_minimum_size = Vector2(160, 48)
		b.pressed.connect(_show_page.bind(t[0]))
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	var play := _button("В БОЙ!", 30, Color(0.55, 0.12, 0.08))
	play.position = Vector2(980, 630)
	play.custom_minimum_size = Vector2(270, 72)
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(play)


func _show_page(name_: String) -> void:
	for k in _pages:
		_pages[k].visible = k == name_
		_tab_buttons[k].add_theme_stylebox_override("normal",
			_sb(Color(0.4, 0.2, 0.1) if k == name_ else Color(0.16, 0.12, 0.2), GOLD, 3 if k == name_ else 2))
	_refresh()


func _refresh() -> void:
	_top_label.text = "Золото: %d     Сундуки: %d     Очки талантов: %d" % [profile.gold, profile.chests, profile.talent_points]
	if _pages["hero"].visible:
		_refresh_hero()
	if _pages["talents"].visible:
		_refresh_talents()
	if _pages["chests"].visible:
		_chest_count.text = "Сундуков: %d" % profile.chests
	if _pages["library"].visible:
		_refresh_library()


# ---------- Вкладка «Герой» ----------

func _build_hero_page() -> Control:
	var p := _page()
	var box := VBoxContainer.new()
	box.position = Vector2(24, 100)
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	box.add_child(_label("Класс", 20))
	for cls in Classes.CLASSES:
		var info: Dictionary = Classes.CLASSES[cls]
		var b := _button("%s\n%s" % [info.name, info.desc], 15, Color(0.16, 0.12, 0.2))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(270, 86)
		b.pressed.connect(_select_class.bind(cls))
		box.add_child(b)
		_class_buttons[cls] = b
	# 3D-превью
	var cont := SubViewportContainer.new()
	cont.position = Vector2(310, 90)
	cont.size = Vector2(380, 420)
	cont.stretch = true
	p.add_child(cont)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	cont.add_child(vp)
	_preview_root = Node3D.new()
	vp.add_child(_preview_root)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.3, 5.4)
	cam.rotation_degrees.x = -8
	cam.fov = 40
	_preview_root.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.3
	_preview_root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.65, 0.85)
	_preview_root.add_child(env)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.2
	cyl.height = 0.2
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.4, 0.35, 0.45)
	base.material_override = bm
	base.position.y = -0.1
	_preview_root.add_child(base)
	_hero_info = _label("", 16, Color(0.95, 0.9, 0.8))
	_hero_info.position = Vector2(310, 515)
	_hero_info.custom_minimum_size = Vector2(380, 0)
	_hero_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(_hero_info)
	# Экипировка
	var panel := PanelContainer.new()
	panel.position = Vector2(710, 90)
	panel.custom_minimum_size = Vector2(546, 525)
	panel.add_theme_stylebox_override("panel", _sb())
	p.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(_label("Надето (нажми, чтобы снять)", 17))
	_equip_box = VBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 4)
	v.add_child(_equip_box)
	v.add_child(_label("Сумка (нажми, чтобы надеть)", 17))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 2
	_bag_grid.add_theme_constant_override("h_separation", 6)
	_bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_bag_grid)
	return p


func _select_class(cls: String) -> void:
	profile.selected_class = cls
	profile.save_profile()
	for k in _class_buttons:
		var sel: bool = k == cls
		_class_buttons[k].add_theme_stylebox_override("normal",
			_sb(Color(0.35, 0.18, 0.1) if sel else Color(0.16, 0.12, 0.2), GOLD if sel else GOLD.darkened(0.4), 3 if sel else 2))
	_show_model(true)
	_refresh()


func _show_model(cheer := false) -> void:
	if _preview_model:
		_preview_model.queue_free()
	var cls: String = profile.selected_class
	var info: Dictionary = Classes.CLASSES[cls]
	var lk: Dictionary = profile.look(cls)
	_preview_model = CharacterModel.new()
	_preview_root.add_child(_preview_model)
	_preview_model.setup(info.model, info.hide, lk.get("weapon", ""), lk.get("offhand", ""))
	_preview_model.apply_look(lk)
	_preview_model.rotation.y = PI
	_preview_model.play("Idle")
	if cheer:
		_preview_model.play_once("Cheer", 1.4)


func _process(delta: float) -> void:
	if _preview_model and _pages["hero"].visible:
		_preview_model.rotation.y += delta * 0.4


func _refresh_hero() -> void:
	var cls: String = profile.selected_class
	for c in _equip_box.get_children():
		c.queue_free()
	for key in ["weapon_" + cls, "armor", "amulet"]:
		if profile.equipped.has(key):
			var it := Items.by_id(profile.equipped[key])
			var b := _item_tile(it, 520)
			b.custom_minimum_size.y = 80
			b.pressed.connect(func():
				profile.unequip(key)
				_show_model()
				_refresh())
			_equip_box.add_child(b)
		else:
			var slot: String = "weapon" if key.begins_with("weapon") else key
			var l := _label("%s: стандартное" % Items.SLOT_NAME[slot] if slot == "weapon" else "%s: пусто" % Items.SLOT_NAME[slot], 15, Color(0.6, 0.6, 0.65))
			l.custom_minimum_size = Vector2(520, 40)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_equip_box.add_child(l)
	for c in _bag_grid.get_children():
		c.queue_free()
	for id in profile.owned:
		var it := Items.by_id(id)
		if it.is_empty() or profile.is_equipped(id) or (it.slot == "weapon" and it.cls != cls):
			continue
		var b := _item_tile(it, 257)
		b.pressed.connect(func():
			profile.equip(id)
			_show_model(true)
			_refresh())
		_bag_grid.add_child(b)
	if _bag_grid.get_child_count() == 0:
		_bag_grid.add_child(_label("Пусто. Открывай сундуки!", 15, Color(0.6, 0.6, 0.65)))
	# Итоговые характеристики
	var info: Dictionary = Classes.CLASSES[cls]
	var bonus: Dictionary = profile.total_bonus(cls)
	var hp: float = round((info.stats.max_hp + bonus.get("max_hp", 0.0)) * (1.0 + bonus.get("max_hp_pct", 0.0)))
	var dmg: float = (info.stats.damage + bonus.get("damage", 0.0)) * (1.0 + bonus.get("damage_mult", 0.0))
	var lines := ["%s" % info.name, "Здоровье %d   ·   Урон %d   ·   Дальность %s" % [hp, round(dmg), str(snapped(info.stats.attack_range + bonus.get("attack_range", 0.0), 0.1))]]
	var extra := []
	if bonus.get("crit_chance", 0.0) > 0:
		extra.append("крит +%d%%" % round(bonus.crit_chance * 100))
	if bonus.get("attack_speed_mult", 0.0) > 0:
		extra.append("скор. атаки +%d%%" % round(bonus.attack_speed_mult * 100))
	if bonus.get("lifesteal", 0.0) > 0:
		extra.append("вампиризм +%d%%" % round(bonus.lifesteal * 100))
	if bonus.get("damage_taken_mult", 0.0) < 0:
		extra.append("защита +%d%%" % round(-bonus.damage_taken_mult * 100))
	if extra.size() > 0:
		lines.append(", ".join(extra))
	_hero_info.text = "\n".join(lines)


# ---------- Вкладка «Таланты» ----------

func _build_talent_page() -> Control:
	var p := _page()
	_talent_points = _label("", 22, Color(0.6, 0.9, 1.0))
	_talent_points.position = Vector2(24, 100)
	p.add_child(_talent_points)
	var hint := _label("Очки талантов выпадают из сундуков и даются за победу над боссом.", 15, Color(0.75, 0.72, 0.85))
	hint.position = Vector2(24, 132)
	p.add_child(hint)
	_talent_grid = GridContainer.new()
	_talent_grid.position = Vector2(24, 170)
	_talent_grid.columns = 3
	_talent_grid.add_theme_constant_override("h_separation", 14)
	_talent_grid.add_theme_constant_override("v_separation", 14)
	p.add_child(_talent_grid)
	return p


func _refresh_talents() -> void:
	_talent_points.text = "Очки талантов: %d" % profile.talent_points
	for c in _talent_grid.get_children():
		c.queue_free()
	for t in Talents.TALENTS:
		var rank: int = profile.talent_rank(t.id)
		var maxed: bool = rank >= t.max
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(395, 132)
		panel.add_theme_stylebox_override("panel", _sb(Color(0.12, 0.1, 0.16), GOLD if maxed else (Color(0.5, 0.8, 1.0) if rank > 0 else Color(0.35, 0.3, 0.45)), 2, 10))
		_talent_grid.add_child(panel)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		panel.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(t.name, 19, Color(1, 0.9, 0.6)))
		var d := _label(t.desc, 14, Color(0.85, 0.82, 0.9))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		v.add_child(d)
		var pips := ""
		for i in t.max:
			pips += "◆ " if i < rank else "◇ "
		v.add_child(_label("%s  %d/%d" % [pips, rank, t.max], 16, Color(0.5, 0.85, 1.0)))
		var b := _button("МАКС" if maxed else "+1\n(%d оч.)" % t.cost, 15, Color(0.15, 0.3, 0.45), Color(0.5, 0.8, 1.0))
		b.custom_minimum_size = Vector2(90, 90)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = not profile.can_upgrade(t.id)
		b.pressed.connect(func():
			if profile.upgrade_talent(t.id):
				_refresh())
		h.add_child(b)


# ---------- Вкладка «Сундуки» ----------

func _build_chest_page() -> Control:
	var p := _page()
	_chest_draw = Control.new()
	_chest_draw.position = Vector2(140, 170)
	_chest_draw.size = Vector2(260, 200)
	_chest_draw.draw.connect(_draw_chest)
	p.add_child(_chest_draw)
	_chest_count = _label("", 26, Color(1, 0.85, 0.4))
	_chest_count.position = Vector2(150, 390)
	_chest_count.custom_minimum_size = Vector2(240, 0)
	_chest_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(_chest_count)
	var open := _button("Открыть сундук", 20, Color(0.45, 0.25, 0.08))
	open.position = Vector2(130, 440)
	open.custom_minimum_size = Vector2(280, 58)
	open.pressed.connect(_open_chest)
	p.add_child(open)
	var buy := _button("Купить сундук за %d золота" % profile.CHEST_PRICE, 17, Color(0.2, 0.28, 0.12))
	buy.position = Vector2(130, 510)
	buy.custom_minimum_size = Vector2(280, 50)
	buy.pressed.connect(func():
		if profile.buy_chest():
			_refresh()
			_chest_bounce()
		else:
			_popup_show("Не хватает золота.\nСундук стоит %d." % profile.CHEST_PRICE, Color(0.9, 0.4, 0.3)))
	p.add_child(buy)
	var odds := _label("Что внутри:\n• Экипировка — 50%\n   (обычная 50%, редкая 30%, эпическая 15%, легендарная 5%)\n   повтор превращается в золото\n• Очки талантов — 30%\n• Золото — 20%\n\nСундуки также дают за мини-боссов (1)\nи за победу над боссом (2).", 16, Color(0.85, 0.82, 0.9))
	odds.position = Vector2(470, 120)
	p.add_child(odds)
	_chest_result = PanelContainer.new()
	_chest_result.position = Vector2(470, 400)
	_chest_result.custom_minimum_size = Vector2(460, 150)
	_chest_result.visible = false
	p.add_child(_chest_result)
	_chest_result_label = _label("", 20)
	_chest_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chest_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chest_result.add_child(_chest_result_label)
	return p


func _draw_chest() -> void:
	var c := _chest_draw
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(20, 80, w - 40, h - 90), Color(0.45, 0.26, 0.1))
	c.draw_rect(Rect2(20, 80, w - 40, h - 90), Color(0.2, 0.1, 0.03), false, 4)
	var lid := PackedVector2Array([Vector2(20, 82), Vector2(30, 30), Vector2(w - 30, 30), Vector2(w - 20, 82)])
	c.draw_colored_polygon(lid, Color(0.55, 0.32, 0.12))
	c.draw_polyline(lid, Color(0.2, 0.1, 0.03), 4)
	for x in [50.0, w - 62.0]:
		c.draw_rect(Rect2(x, 30, 12, h - 40), Color(0.85, 0.65, 0.2))
	c.draw_rect(Rect2(w / 2 - 18, 70, 36, 40), Color(0.9, 0.72, 0.25))
	c.draw_circle(Vector2(w / 2, 92), 6, Color(0.2, 0.1, 0.03))


func _chest_bounce() -> void:
	_chest_draw.pivot_offset = _chest_draw.size / 2
	var tw := create_tween()
	tw.tween_property(_chest_draw, "scale", Vector2(1.15, 0.9), 0.08)
	tw.tween_property(_chest_draw, "scale", Vector2(0.95, 1.1), 0.1)
	tw.tween_property(_chest_draw, "scale", Vector2.ONE, 0.12)


func _open_chest() -> void:
	var res: Dictionary = profile.open_chest()
	if res.is_empty():
		_popup_show("Сундуков нет.\nКупи сундук за золото или\nпобеждай мини-боссов.", Color(0.8, 0.8, 0.8))
		return
	_chest_bounce()
	var text := ""
	var border := GOLD
	match res.type:
		"item":
			var it: Dictionary = res.item
			border = Items.RARITY_COLOR[it.rarity]
			text = "%s предмет!\n%s\n%s" % [Items.RARITY_NAME[it.rarity], it.name, Items.describe(it)]
		"duplicate":
			var it: Dictionary = res.item
			border = Items.RARITY_COLOR[it.rarity]
			text = "%s — уже есть.\nПревращён в +%d золота" % [it.name, res.gold]
		"talent":
			border = Color(0.5, 0.85, 1.0)
			text = "Очки талантов: +%d" % res.points
		"gold":
			text = "Золото: +%d" % res.gold
	_chest_result_label.text = text
	_chest_result.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.1, 0.97), border, 4))
	_chest_result.visible = true
	_chest_result.pivot_offset = _chest_result.custom_minimum_size / 2
	_chest_result.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(_chest_result, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()


# ---------- Вкладка «Библиотека» ----------

func _build_library_page() -> Control:
	var p := _page()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 96)
	scroll.size = Vector2(940, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	_library_box = VBoxContainer.new()
	_library_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_library_box)
	return p


func _refresh_library() -> void:
	for c in _library_box.get_children():
		c.queue_free()
	var found := 0
	for id in profile.owned:
		if not Items.by_id(id).is_empty():
			found += 1
	_library_box.add_child(_label("Найдено %d из %d предметов" % [found, Items.ITEMS.size()], 18, Color(1, 0.85, 0.45)))
	var groups := [["Оружие воина", "weapon", "warrior"], ["Оружие лучника", "weapon", "archer"], ["Оружие мага", "weapon", "mage"],
		["Доспехи", "armor", ""], ["Амулеты", "amulet", ""]]
	for g in groups:
		_library_box.add_child(_label(g[0], 17, Color(0.85, 0.8, 0.95)))
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_library_box.add_child(grid)
		for it in Items.ITEMS:
			if it.slot != g[1] or (g[2] != "" and it.get("cls", "") != g[2]):
				continue
			var have: bool = it.id in profile.owned
			var state := "Надето" if profile.is_equipped(it.id) else ("Есть" if have else "Не найдено")
			var b := _item_tile(it, 228, state)
			if not have:
				b.modulate = Color(1, 1, 1, 0.45)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(b)


# ---------- Всплывающее окно ----------

func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.visible = false
	_popup.custom_minimum_size = Vector2(460, 230)
	_popup.position = Vector2(410, 230)
	add_child(_popup)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup.add_child(v)
	_popup_label = _label("", 20)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_popup_label)
	var ok := _button("Отлично", 18, Color(0.3, 0.2, 0.1))
	ok.custom_minimum_size = Vector2(180, 46)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(func(): _popup.visible = false)
	v.add_child(ok)


func _popup_show(t: String, border: Color) -> void:
	_popup_label.text = t
	_popup.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.1, 0.97), border, 4))
	_popup.visible = true
	_popup.pivot_offset = _popup.custom_minimum_size / 2
	_popup.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_run_summary() -> void:
	var r: Dictionary = profile.last_run
	_popup_show("%s\n\nВремя %d:%02d · Уровень %d · Убито %d\n\nНаграда: +%d золота, +%d сундук(ов)" % [
		"ПОБЕДА!" if r.victory else "Забег окончен", int(r.time) / 60, int(r.time) % 60, r.level, r.kills, r.gold, r.chests], GOLD)
	profile.last_run = {}
