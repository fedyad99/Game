extends Control
## Главное меню (лагерь). Вкладки: Герой, Таланты (дерево), Сундуки, Библиотека.
## При первом запуске сначала показывается выбор класса.

const Classes := preload("res://scripts/player/classes.gd")
const Items := preload("res://scripts/meta/items.gd")
const TalentTree := preload("res://scripts/meta/talent_tree.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const MenuBg := preload("res://scripts/ui/menu_bg.gd")
const HeroPreview := preload("res://scripts/ui/hero_preview.gd")
const TreeView := preload("res://scripts/ui/talent_tree_view.gd")
const ChestView := preload("res://scripts/ui/chest_view.gd")

const GOLD := Color(0.95, 0.75, 0.3)
const PANEL := Color(0.07, 0.05, 0.1, 0.88)
const CLASS_COLOR := {"warrior": Color(0.75, 0.3, 0.2), "archer": Color(0.25, 0.6, 0.3), "mage": Color(0.45, 0.3, 0.8)}

var profile: Node
var sfx: Node
var _pages := {}
var _tab_buttons := {}
var _current_page := ""
var _res_gold: Label
var _res_chests: Label
var _res_points: Label
var _sound_btn: Button
var _music_btn: Button
# Герой
var _preview: SubViewportContainer
var _class_cards := {}
var _hero_info: Label
var _hero_skills: Label
var _equip_row: HBoxContainer
var _bag_grid: GridContainer
var _hero_detail: HBoxContainer
var _hero_sel := ""
# Таланты
var _tree: Control
var _tree_points: Label
var _tree_reset: Button
# Сундуки
var _chest: Control
var _chest_result: PanelContainer
var _chest_result_icon: CenterContainer
var _chest_result_label: Label
var _open_btn: Button
var _pending_loot := {}
# Библиотека
var _library_box: VBoxContainer
var _lib_detail: VBoxContainer
var _lib_sel := ""
# Общие
var _tooltip: PanelContainer
var _tooltip_box: VBoxContainer
var _tooltip_owner: Object
var _popup_layer: Control
var _popup: PanelContainer
var _popup_label: Label
var _popup_buttons: HBoxContainer
var _class_select: Control


func _ready() -> void:
	profile = get_node("/root/Profile")
	sfx = get_node("/root/Sfx")
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBg.new())
	_build_top()
	_pages["hero"] = _build_hero_page()
	_pages["talents"] = _build_talent_page()
	_pages["chests"] = _build_chest_page()
	_pages["library"] = _build_library_page()
	_build_play_button()
	_build_tooltip()
	_build_popup()
	_show_page("hero", false)
	_update_class_cards()
	_preview.show_hero(profile.selected_class, profile.look(profile.selected_class), true)
	sfx.music("menu")
	if not profile.class_chosen:
		_show_class_select()
	elif not profile.last_run.is_empty():
		_show_run_summary()


# ---------- Общие элементы ----------

func _sb(col := PANEL, border := GOLD.darkened(0.25), bw := 2, radius := 12, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 3)
	return sb


func _panel_sb() -> StyleBoxFlat:
	var sb := _sb(PANEL, GOLD.darkened(0.3), 2, 14)
	sb.set_content_margin_all(14)
	return sb


func _label(t: String, fs: int, col := Color(1, 0.95, 0.85)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Кнопка с золотой рамкой, тенью, звуком и «пружинкой» при наведении.
func _button(t: String, fs: int, col: Color, border := GOLD) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6))
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_stylebox_override("normal", _sb(col, border.darkened(0.15), 2, 10))
	b.add_theme_stylebox_override("hover", _sb(col.lightened(0.18), border.lightened(0.3), 3, 10))
	b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.25), border, 3, 10))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.16, 0.15, 0.18), Color(0.35, 0.35, 0.35), 2, 10))
	_juice(b)
	return b


func _juice(b: Control) -> void:
	b.mouse_entered.connect(func():
		if b is BaseButton and b.disabled:
			return
		sfx.play("hover", -6.0, 0.1)
		b.pivot_offset = b.size / 2
		b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.08))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	if b is BaseButton:
		b.button_down.connect(func(): sfx.play("click", 0.0, 0.05))


func _page() -> Control:
	var p := Control.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	return p


func _header(t: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := Control.new()
	gem.custom_minimum_size = Vector2(12, 12)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.draw.connect(func():
		gem.draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(12, 6), Vector2(6, 12), Vector2(0, 6)]), GOLD))
	h.add_child(gem)
	h.add_child(_label(t, 18, Color(1, 0.88, 0.55)))
	return h


# ---------- Верх: название, ресурсы, вкладки, звук ----------

func _build_top() -> void:
	var title := _label("ПРОКЛЯТОЕ КЛАДБИЩЕ", 32, Color(1, 0.85, 0.45))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.0))
	title.position = Vector2(24, 8)
	add_child(title)
	var res := HBoxContainer.new()
	res.position = Vector2(24, 54)
	res.add_theme_constant_override("separation", 10)
	add_child(res)
	_res_gold = _chip(res, "gold")
	_res_chests = _chip(res, "chest")
	_res_points = _chip(res, "star")
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(536, 16)
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for t in [["hero", "Герой"], ["talents", "Таланты"], ["chests", "Сундуки"], ["library", "Библиотека"]]:
		var b := _button(t[1], 18, Color(0.16, 0.11, 0.2))
		b.custom_minimum_size = Vector2(146, 50)
		b.pressed.connect(func(): _show_page(t[0]))
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	_sound_btn = _button("", 14, Color(0.16, 0.11, 0.2))
	_sound_btn.custom_minimum_size = Vector2(50, 50)
	_sound_btn.position = Vector2(1150, 16)
	_sound_btn.draw.connect(func(): _draw_speaker(_sound_btn, profile.sound_on))
	_sound_btn.pressed.connect(func():
		profile.set_sound(not profile.sound_on)
		_sound_btn.queue_redraw())
	add_child(_sound_btn)
	_music_btn = _button("", 14, Color(0.16, 0.11, 0.2))
	_music_btn.custom_minimum_size = Vector2(50, 50)
	_music_btn.position = Vector2(1206, 16)
	_music_btn.draw.connect(func(): _draw_note(_music_btn, profile.music_on))
	_music_btn.pressed.connect(func():
		profile.set_music(not profile.music_on)
		_music_btn.queue_redraw())
	add_child(_music_btn)


## Плашка ресурса со значком.
func _chip(parent: Control, kind: String) -> Label:
	var p := PanelContainer.new()
	var sb := _sb(Color(0.06, 0.04, 0.08, 0.85), GOLD.darkened(0.4), 1, 16, false)
	sb.content_margin_left = 38
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var l := _label("", 17, Color(1, 0.9, 0.6))
	p.add_child(l)
	p.draw.connect(_draw_chip_icon.bind(p, kind))
	return l


func _draw_chip_icon(p: Control, kind: String) -> void:
	var c := Vector2(20, p.size.y / 2)
	match kind:
		"gold":
			p.draw_circle(c, 11, Color(0.7, 0.45, 0.08))
			p.draw_circle(c, 8.5, Color(1, 0.82, 0.3))
			p.draw_rect(Rect2(c + Vector2(-1.5, -6), Vector2(3, 12)), Color(0.8, 0.55, 0.1))
		"chest":
			p.draw_rect(Rect2(c + Vector2(-10, -2), Vector2(20, 11)), Color(0.55, 0.32, 0.12))
			p.draw_rect(Rect2(c + Vector2(-10, -9), Vector2(20, 7)), Color(0.68, 0.42, 0.15))
			p.draw_rect(Rect2(c + Vector2(-2, -4), Vector2(4, 6)), Color(1, 0.8, 0.3))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + PI * i / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 4.5))
			p.draw_colored_polygon(pts, Color(0.55, 0.85, 1.0))


func _draw_speaker(b: Button, on: bool) -> void:
	var c := b.size / 2
	var col := Color(1, 0.92, 0.75) if on else Color(0.5, 0.45, 0.45)
	b.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -5), c + Vector2(-6, -5), c + Vector2(2, -12), c + Vector2(2, 12), c + Vector2(-6, 5), c + Vector2(-12, 5)]), col)
	if on:
		b.draw_arc(c + Vector2(4, 0), 7, -0.8, 0.8, 8, col, 2.0, true)
		b.draw_arc(c + Vector2(4, 0), 12, -0.8, 0.8, 8, col, 2.0, true)
	else:
		b.draw_line(c + Vector2(6, -6), c + Vector2(16, 6), Color(0.9, 0.3, 0.3), 3.0)
		b.draw_line(c + Vector2(16, -6), c + Vector2(6, 6), Color(0.9, 0.3, 0.3), 3.0)


func _draw_note(b: Button, on: bool) -> void:
	var c := b.size / 2
	var col := Color(1, 0.92, 0.75) if on else Color(0.5, 0.45, 0.45)
	b.draw_circle(c + Vector2(-6, 9), 5, col)
	b.draw_circle(c + Vector2(8, 6), 5, col)
	b.draw_line(c + Vector2(-2, 9), c + Vector2(-2, -11), col, 2.5)
	b.draw_line(c + Vector2(12, 6), c + Vector2(12, -14), col, 2.5)
	b.draw_line(c + Vector2(-2, -11), c + Vector2(12, -14), col, 4.0)
	if not on:
		b.draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), Color(0.9, 0.3, 0.3), 3.0)


func _build_play_button() -> void:
	var play := _button("В БОЙ!", 32, Color(0.6, 0.12, 0.06))
	play.position = Vector2(986, 632)
	play.custom_minimum_size = Vector2(270, 72)
	play.pressed.connect(func():
		sfx.play("warcry", -4.0)
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	add_child(play)
	# Мягкое пульсирующее свечение кнопки
	var tw := play.create_tween().set_loops()
	tw.tween_property(play, "self_modulate", Color(1.3, 1.12, 1.0), 0.9)
	tw.tween_property(play, "self_modulate", Color.WHITE, 0.9)


func _show_page(name_: String, animate := true) -> void:
	if name_ == _current_page:
		return
	if _current_page != "" and animate:
		sfx.play("tab", -2.0, 0.0)
	_current_page = name_
	_tooltip.visible = false
	for k in _pages:
		var p: Control = _pages[k]
		p.visible = k == name_
		var sel: bool = k == name_
		_tab_buttons[k].add_theme_stylebox_override("normal",
			_sb(Color(0.45, 0.22, 0.08) if sel else Color(0.16, 0.11, 0.2), GOLD if sel else GOLD.darkened(0.15), 3 if sel else 2, 10))
	var page: Control = _pages[name_]
	if animate:
		page.modulate.a = 0.0
		page.position.y = 16
		var tw := page.create_tween().set_parallel()
		tw.tween_property(page, "modulate:a", 1.0, 0.22)
		tw.tween_property(page, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_refresh()


func _refresh() -> void:
	_res_gold.text = str(profile.gold)
	_res_chests.text = str(profile.chests)
	_res_points.text = "%d оч. талантов" % profile.free_points()
	match _current_page:
		"hero":
			_refresh_hero()
		"talents":
			_refresh_talents()
		"chests":
			_chest.count = profile.chests
		"library":
			_refresh_library()


# ---------- Подсказка при наведении ----------

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.top_level = true
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 20
	add_child(_tooltip)
	_tooltip_box = VBoxContainer.new()
	_tooltip_box.add_theme_constant_override("separation", 2)
	_tooltip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_box)


func _show_tooltip(owner_: Object, border: Color) -> void:
	_tooltip_owner = owner_
	_tooltip.add_theme_stylebox_override("panel", _sb(Color(0.05, 0.04, 0.07, 0.97), border, 2, 8))
	_tooltip.reset_size()
	_tooltip.visible = true


func _process(_delta: float) -> void:
	if _tooltip.visible:
		if _tooltip_owner is Control and (not is_instance_valid(_tooltip_owner) or not _tooltip_owner.is_visible_in_tree()):
			_tooltip.visible = false
			return
		_tooltip.reset_size()
		var vp := get_viewport_rect().size
		var pos := get_global_mouse_position() + Vector2(18, 18)
		pos.x = min(pos.x, vp.x - _tooltip.size.x - 6)
		pos.y = min(pos.y, vp.y - _tooltip.size.y - 6)
		_tooltip.position = pos


## Описание предмета: название, редкость и слот, характеристики, состояние.
func _fill_info(box: Container, it: Dictionary, state := "", name_size := 20) -> void:
	for c in box.get_children():
		c.queue_free()
	var col: Color = Items.RARITY_COLOR[it.rarity]
	box.add_child(_label(it.name, name_size, col.lightened(0.25)))
	var slot_text: String = Items.SLOT_NAME[it.slot]
	if it.slot == "weapon":
		slot_text += " · " + Classes.CLASSES[it.cls].name
	box.add_child(_label("%s · %s" % [Items.RARITY_NAME[it.rarity], slot_text], 14, Color(0.75, 0.72, 0.82)))
	for line in Items.describe(it).split("\n"):
		box.add_child(_label(line, 16, Color(0.55, 0.95, 0.55)))
	if state != "":
		box.add_child(_label(state, 14, Color(0.95, 0.85, 0.55)))


func _icon(it: Dictionary, size_px := 78.0) -> Control:
	var ic := ItemIcon.create(it, size_px)
	ic.hovered.connect(_on_icon_hover)
	ic.mouse_entered.connect(func(): sfx.play("hover", -8.0, 0.15))
	return ic


func _on_icon_hover(ic: Control, on: bool) -> void:
	if not on or ic.item.is_empty():
		if _tooltip_owner == ic:
			_tooltip.visible = false
		return
	_fill_info(_tooltip_box, ic.item, _state_text(ic.item))
	_show_tooltip(ic, Items.RARITY_COLOR[ic.item.rarity])


func _state_text(it: Dictionary) -> String:
	if profile.is_equipped(it.id):
		return "Надето"
	if not it.id in profile.owned:
		return "Ещё не найдено"
	var key := Items.equip_key(it)
	if profile.equipped.has(key):
		return "Сейчас надето: " + Items.by_id(profile.equipped[key]).name
	return "В сумке"


# ---------- Всплывающее окно ----------

func _build_popup() -> void:
	_popup_layer = Control.new()
	_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.visible = false
	add_child(_popup_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_layer.add_child(center)
	_popup = PanelContainer.new()
	_popup.custom_minimum_size = Vector2(480, 220)
	center.add_child(_popup)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup.add_child(v)
	_popup_label = _label("", 20)
	_popup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_popup_label)
	_popup_buttons = HBoxContainer.new()
	_popup_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_buttons.add_theme_constant_override("separation", 16)
	v.add_child(_popup_buttons)


## Окно с текстом. Если передан on_yes — две кнопки (да/отмена), иначе одна «Хорошо».
func _popup_show(t: String, border: Color, on_yes: Callable = Callable(), yes_text := "Да") -> void:
	_popup_label.text = t
	_popup.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.05, 0.1, 0.98), border, 4, 16))
	for c in _popup_buttons.get_children():
		c.queue_free()
	if on_yes.is_valid():
		var yes := _button(yes_text, 18, Color(0.2, 0.35, 0.15))
		yes.custom_minimum_size = Vector2(170, 50)
		yes.pressed.connect(func():
			_popup_layer.visible = false
			on_yes.call())
		_popup_buttons.add_child(yes)
		var no := _button("Отмена", 18, Color(0.3, 0.15, 0.12))
		no.custom_minimum_size = Vector2(150, 50)
		no.pressed.connect(func(): _popup_layer.visible = false)
		_popup_buttons.add_child(no)
	else:
		var ok := _button("Хорошо", 18, Color(0.35, 0.22, 0.1))
		ok.custom_minimum_size = Vector2(180, 50)
		ok.pressed.connect(func(): _popup_layer.visible = false)
		_popup_buttons.add_child(ok)
	_popup_layer.visible = true
	_popup.pivot_offset = _popup.size / 2
	_popup.scale = Vector2(0.7, 0.7)
	_popup.modulate.a = 0.0
	var tw := _popup.create_tween().set_parallel()
	tw.tween_property(_popup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_popup, "modulate:a", 1.0, 0.15)


func _show_run_summary() -> void:
	var r: Dictionary = profile.last_run
	_popup_show("%s\n\nВремя %d:%02d · Уровень %d · Убито %d\n\nНаграда: +%d золота, +%d сундук(ов), +%d оч. талантов" % [
		"ПОБЕДА!" if r.victory else "Забег окончен", int(r.time) / 60, int(r.time) % 60, r.level, r.kills, r.gold, r.chests, r.get("points", 0)], GOLD)
	profile.last_run = {}


# ---------- Выбор класса (первый запуск) ----------

func _show_class_select() -> void:
	_class_select = Control.new()
	_class_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_class_select)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.93)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_class_select.add_child(dim)
	var title := _label("Выбери своего героя", 36, Color(1, 0.85, 0.45))
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.0))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position.y = 14
	_class_select.add_child(title)
	var sub := _label("Позже класс можно сменить в лагере, но это стоит %d золота." % profile.CLASS_CHANGE_PRICE, 16, Color(0.75, 0.72, 0.85))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position.y = 64
	_class_select.add_child(sub)
	var i := 0
	for cls in Classes.CLASSES:
		var info: Dictionary = Classes.CLASSES[cls]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.06, 0.11, 0.97), CLASS_COLOR[cls].lightened(0.2), 3, 16))
		card.position = Vector2(40 + i * 410, 100)
		card.custom_minimum_size = Vector2(380, 600)
		_class_select.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var pv: SubViewportContainer = HeroPreview.new()
		pv.custom_minimum_size = Vector2(350, 300)
		pv.set_distance(4.8, 1.2)
		pv.spin = 0.0
		v.add_child(pv)
		pv.show_hero(cls, Items.DEFAULT_LOOK[cls])
		pv.face(0.45)
		var name_l := _label(info.name, 28, CLASS_COLOR[cls].lightened(0.45))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var d := _label(info.desc, 15, Color(0.85, 0.82, 0.9))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
		var st: Dictionary = info.stats
		var s := _label("Здоровье %d · Урон %d · Дальность %s" % [st.max_hp, st.damage, str(st.attack_range)], 14, Color(0.6, 0.95, 0.6))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
		var sk := []
		for k in TalentTree.SKILLS:
			if TalentTree.SKILLS[k].cls == cls:
				sk.append(TalentTree.SKILLS[k].name)
		var u := _label("Уникальные навыки: " + ", ".join(sk), 14, Color(0.95, 0.85, 0.55))
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		u.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		u.custom_minimum_size.x = 350
		v.add_child(u)
		var b := _button("Играть за: " + info.name, 20, CLASS_COLOR[cls].darkened(0.35))
		b.custom_minimum_size = Vector2(330, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _choose_first_class(cls))
		v.add_child(b)
		# Появление карточек по очереди
		card.modulate.a = 0.0
		card.position.y += 40
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.12 * i)
		tw.tween_property(card, "position:y", 100.0, 0.4).set_delay(0.12 * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1


func _choose_first_class(cls: String) -> void:
	profile.change_class(cls)
	sfx.play("class_pick")
	var tw := _class_select.create_tween()
	tw.tween_property(_class_select, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_class_select.queue_free)
	_update_class_cards()
	_preview.show_hero(cls, profile.look(cls), true)
	_refresh()


# ---------- Вкладка «Герой» ----------

func _build_hero_page() -> Control:
	var p := _page()
	var left := VBoxContainer.new()
	left.position = Vector2(24, 100)
	left.add_theme_constant_override("separation", 8)
	p.add_child(left)
	left.add_child(_header("Класс"))
	for cls in Classes.CLASSES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(280, 84)
		b.pressed.connect(func(): _on_class_card(cls))
		_juice(b)
		left.add_child(b)
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -10
		h.add_theme_constant_override("separation", 12)
		b.add_child(h)
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(54, 54)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.draw.connect(_draw_class_badge.bind(badge, cls))
		h.add_child(badge)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		v.add_child(_label(Classes.CLASSES[cls].name, 20, Color(1, 0.92, 0.75)))
		var state := _label("", 14, Color(0.75, 0.72, 0.85))
		v.add_child(state)
		_class_cards[cls] = {"button": b, "state": state}
	left.add_child(_header("Навыки класса"))
	_hero_skills = _label("", 14, Color(0.85, 0.82, 0.9))
	_hero_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_skills.custom_minimum_size = Vector2(280, 0)
	left.add_child(_hero_skills)
	# 3D-превью
	_preview = HeroPreview.new()
	_preview.position = Vector2(318, 92)
	_preview.size = Vector2(380, 400)
	p.add_child(_preview)
	var stats := PanelContainer.new()
	stats.position = Vector2(326, 500)
	stats.custom_minimum_size = Vector2(364, 112)
	stats.add_theme_stylebox_override("panel", _panel_sb())
	p.add_child(stats)
	_hero_info = _label("", 15, Color(0.95, 0.9, 0.8))
	_hero_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats.add_child(_hero_info)
	# Экипировка
	var panel := PanelContainer.new()
	panel.position = Vector2(712, 96)
	panel.custom_minimum_size = Vector2(544, 524)
	panel.add_theme_stylebox_override("panel", _panel_sb())
	p.add_child(panel)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 6)
	panel.add_child(v2)
	v2.add_child(_header("Надето"))
	_equip_row = HBoxContainer.new()
	_equip_row.add_theme_constant_override("separation", 14)
	v2.add_child(_equip_row)
	v2.add_child(_header("Сумка"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(516, 146)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v2.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 7
	_bag_grid.add_theme_constant_override("h_separation", 6)
	_bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_bag_grid)
	v2.add_child(HSeparator.new())
	_hero_detail = HBoxContainer.new()
	_hero_detail.add_theme_constant_override("separation", 12)
	_hero_detail.custom_minimum_size = Vector2(516, 116)
	v2.add_child(_hero_detail)
	return p


func _draw_class_badge(badge: Control, cls: String) -> void:
	var c := Vector2(27, 27)
	badge.draw_circle(c, 27, Color(0.1, 0.06, 0.03))
	badge.draw_circle(c, 24, CLASS_COLOR[cls])
	var w := Color(1, 0.95, 0.85)
	match cls:
		"warrior":
			badge.draw_line(c + Vector2(-10, 12), c + Vector2(12, -12), w, 4.0, true)
			badge.draw_line(c + Vector2(-12, 2), c + Vector2(-2, 12), w, 3.0, true)
		"archer":
			badge.draw_arc(c + Vector2(6, 0), 15, PI * 0.6, PI * 1.4, 16, w, 3.0, true)
			badge.draw_line(c + Vector2(-12, 0), c + Vector2(14, 0), w, 2.5, true)
		"mage":
			for i in 4:
				var a := PI / 4 + TAU * i / 4.0
				badge.draw_line(c, c + Vector2(cos(a), sin(a)) * 14, w, 3.0, true)
			badge.draw_circle(c, 6, w)


func _update_class_cards() -> void:
	for cls in _class_cards:
		var sel: bool = cls == profile.selected_class
		var b: Button = _class_cards[cls].button
		var col: Color = CLASS_COLOR[cls]
		b.add_theme_stylebox_override("normal", _sb(col.darkened(0.55) if sel else Color(0.1, 0.08, 0.13, 0.92), GOLD if sel else col.darkened(0.2), 3 if sel else 2, 12))
		b.add_theme_stylebox_override("hover", _sb(col.darkened(0.45), GOLD.lightened(0.2), 3, 12))
		b.add_theme_stylebox_override("pressed", _sb(col.darkened(0.6), GOLD, 3, 12))
		var cost: int = profile.class_change_cost(cls)
		var st: Label = _class_cards[cls].state
		st.text = "Твой класс" if sel else ("Сменить: %d золота" % cost if cost > 0 else "Выбрать")
		st.add_theme_color_override("font_color", Color(0.6, 1, 0.6) if sel else (Color(1, 0.85, 0.4) if profile.gold >= cost else Color(0.85, 0.5, 0.45)))


func _on_class_card(cls: String) -> void:
	if cls == profile.selected_class:
		_preview.show_hero(cls, profile.look(cls), true)
		return
	var cost: int = profile.class_change_cost(cls)
	if profile.gold < cost:
		sfx.play("error")
		_popup_show("Смена класса стоит %d золота.\nУ тебя %d." % [cost, profile.gold], Color(0.9, 0.4, 0.3))
		return
	_popup_show("Сменить класс на «%s» за %d золота?\n\nДерево талантов у каждого класса своё,\nпрогресс не пропадёт." % [Classes.CLASSES[cls].name, cost],
		CLASS_COLOR[cls].lightened(0.3), func():
			if profile.change_class(cls):
				sfx.play("class_pick")
				sfx.play("buy")
				_hero_sel = ""
				_update_class_cards()
				_preview.show_hero(cls, profile.look(cls), true)
				_refresh(), "Сменить")


func _refresh_hero() -> void:
	var cls: String = profile.selected_class
	_update_class_cards()
	if _hero_sel != "" and not _hero_sel in profile.owned:
		_hero_sel = ""
	var sel_it := Items.by_id(_hero_sel)
	if not sel_it.is_empty() and sel_it.slot == "weapon" and sel_it.cls != cls:
		_hero_sel = ""
	for c in _equip_row.get_children():
		c.queue_free()
	for key in profile.slot_keys(cls):
		var slot: String = "weapon" if key.begins_with("weapon") else key
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		_equip_row.add_child(col)
		var ic: Control
		if profile.equipped.has(key):
			var it := Items.by_id(profile.equipped[key])
			ic = _icon(it, 104)
			ic.equipped = true
			ic.selected = it.id == _hero_sel
			ic.pressed.connect(func(_i): _select_item(it.id))
			ic.activated.connect(func(_i): _toggle_equip(it.id))
		else:
			ic = ItemIcon.create({}, 104)
			ic.slot_hint = slot
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(ic)
		var name_l := _label(Items.SLOT_NAME[slot], 13, Color(0.75, 0.72, 0.82))
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.custom_minimum_size.x = 104
		col.add_child(name_l)
	for c in _bag_grid.get_children():
		c.queue_free()
	for id in profile.owned:
		var it := Items.by_id(id)
		if it.is_empty() or profile.is_equipped(id) or (it.slot == "weapon" and it.cls != cls):
			continue
		var ic := _icon(it, 68)
		ic.selected = id == _hero_sel
		ic.pressed.connect(func(_i): _select_item(id))
		ic.activated.connect(func(_i): _toggle_equip(id))
		_bag_grid.add_child(ic)
	if _bag_grid.get_child_count() == 0:
		_bag_grid.add_child(_label("Пусто. Открывай сундуки!", 15, Color(0.6, 0.6, 0.65)))
	_refresh_hero_detail()
	# Итоговые характеристики
	var info: Dictionary = Classes.CLASSES[cls]
	var bonus: Dictionary = profile.total_bonus(cls)
	var hp: float = round((info.stats.max_hp + bonus.get("max_hp", 0.0)) * (1.0 + bonus.get("max_hp_pct", 0.0)))
	var dmg: float = (info.stats.damage + bonus.get("damage", 0.0)) * (1.0 + bonus.get("damage_mult", 0.0))
	var lines := ["%s" % info.name, "Здоровье %d  ·  Урон %d  ·  Дальность %s" % [hp, round(dmg), str(snapped(info.stats.attack_range + bonus.get("attack_range", 0.0), 0.1))]]
	var extra := []
	for k in [["crit_chance", "крит"], ["attack_speed_mult", "скор. атаки"], ["lifesteal", "вампиризм"], ["move_speed_mult", "бег"]]:
		if bonus.get(k[0], 0.0) > 0:
			extra.append("%s +%d%%" % [k[1], round(bonus[k[0]] * 100)])
	if bonus.get("damage_taken_mult", 0.0) < 0:
		extra.append("защита +%d%%" % round(-bonus.damage_taken_mult * 100))
	if bonus.get("skill_cd_mult", 0.0) < 0:
		extra.append("перезарядка -%d%%" % round(-bonus.skill_cd_mult * 100))
	if bonus.get("regen", 0.0) > 0:
		extra.append("реген +%s/с" % str(snapped(bonus.regen, 0.1)))
	if extra.size() > 3:
		lines.append(", ".join(extra.slice(0, 3)))
		lines.append(", ".join(extra.slice(3)))
	elif extra.size() > 0:
		lines.append(", ".join(extra))
	_hero_info.text = "\n".join(lines)
	var sk_lines := []
	var have: Array = profile.tree_skills(cls)
	for k in TalentTree.SKILLS:
		var s: Dictionary = TalentTree.SKILLS[k]
		if s.cls == cls:
			sk_lines.append(("✔ %s — изучен" if k in have else "• %s — в дереве талантов") % s.name)
	_hero_skills.text = "\n".join(sk_lines)


func _select_item(id: String) -> void:
	_hero_sel = id
	sfx.play("click", -4.0)
	_refresh_hero()


func _toggle_equip(id: String) -> void:
	if profile.is_equipped(id):
		profile.unequip(Items.equip_key(Items.by_id(id)))
		sfx.play("unequip")
		_preview.show_hero(profile.selected_class, profile.look(profile.selected_class))
	else:
		profile.equip(id)
		sfx.play("equip")
		_preview.show_hero(profile.selected_class, profile.look(profile.selected_class), true)
	_tooltip.visible = false
	_refresh()


## Нижняя часть панели: выбранный предмет крупно, его характеристики и кнопка Надеть/Снять.
func _refresh_hero_detail() -> void:
	for c in _hero_detail.get_children():
		c.queue_free()
	var it := Items.by_id(_hero_sel)
	if it.is_empty():
		var hint := _label("Наведи на предмет, чтобы увидеть характеристики.\nНажми на предмет, чтобы выбрать его.\nДвойной клик сразу надевает или снимает.", 15, Color(0.65, 0.62, 0.75))
		hint.custom_minimum_size = Vector2(516, 110)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hero_detail.add_child(hint)
		return
	var big := ItemIcon.create(it, 110)
	big.equipped = profile.is_equipped(it.id)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_detail.add_child(big)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 1)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_detail.add_child(info)
	_fill_info(info, it, _state_text(it), 19)
	var on: bool = profile.is_equipped(it.id)
	var btn := _button("Снять" if on else "Надеть", 18, Color(0.4, 0.15, 0.1) if on else Color(0.15, 0.35, 0.15))
	btn.custom_minimum_size = Vector2(120, 52)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_toggle_equip.bind(it.id))
	_hero_detail.add_child(btn)
	big.pivot_offset = Vector2(55, 55)
	big.scale = Vector2(0.6, 0.6)
	big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- Вкладка «Таланты» ----------

func _build_talent_page() -> Control:
	var p := _page()
	var frame := PanelContainer.new()
	frame.position = Vector2(24, 96)
	frame.custom_minimum_size = Vector2(1232, 524)
	var fsb := _panel_sb()
	fsb.set_content_margin_all(4)
	fsb.bg_color = Color(0.03, 0.02, 0.05, 0.75)
	frame.add_theme_stylebox_override("panel", fsb)
	p.add_child(frame)
	_tree = TreeView.new()
	_tree.profile = profile
	_tree.custom_minimum_size = Vector2(1220, 512)
	frame.add_child(_tree)
	_tree.node_hovered.connect(_on_tree_hover)
	_tree.node_clicked.connect(_on_tree_click)
	# Инфо-плашка слева сверху
	var info := PanelContainer.new()
	info.position = Vector2(40, 110)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_stylebox_override("panel", _sb(Color(0.06, 0.04, 0.08, 0.92), GOLD.darkened(0.3), 2, 10))
	p.add_child(info)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	info.add_child(v)
	_tree_points = _label("", 22, Color(0.6, 0.9, 1.0))
	v.add_child(_tree_points)
	v.add_child(_label("Бери узлы рядом с уже взятыми.\nПеретаскивай поле, колесо — масштаб.\nРомбы — уникальные навыки класса.", 13, Color(0.75, 0.72, 0.85)))
	# Кнопки справа сверху
	var tools := VBoxContainer.new()
	tools.position = Vector2(1044, 110)
	tools.add_theme_constant_override("separation", 6)
	p.add_child(tools)
	var zrow := HBoxContainer.new()
	zrow.add_theme_constant_override("separation", 6)
	zrow.alignment = BoxContainer.ALIGNMENT_END
	tools.add_child(zrow)
	for z in [["−", 1.0 / 1.2], ["+", 1.2]]:
		var zb := _button(z[0], 22, Color(0.16, 0.11, 0.2))
		zb.custom_minimum_size = Vector2(46, 42)
		zb.pressed.connect(func(): _tree.zoom_by(z[1]))
		zrow.add_child(zb)
	var home := _button("К старту", 15, Color(0.16, 0.11, 0.2))
	home.custom_minimum_size = Vector2(104, 42)
	home.pressed.connect(func(): _tree.focus_class())
	zrow.add_child(home)
	_tree_reset = _button("Сбросить (%d золота)" % profile.TREE_RESET_PRICE, 14, Color(0.35, 0.14, 0.1))
	_tree_reset.custom_minimum_size = Vector2(208, 40)
	_tree_reset.pressed.connect(func():
		_popup_show("Сбросить все таланты класса за %d золота?\nОчки вернутся." % profile.TREE_RESET_PRICE, Color(0.9, 0.5, 0.3), func():
			if profile.reset_tree(profile.selected_class):
				sfx.play("unequip")
				_refresh()
			else:
				sfx.play("error"), "Сбросить"))
	tools.add_child(_tree_reset)
	return p


func _refresh_talents() -> void:
	var cls: String = profile.selected_class
	if _tree.cls != cls or _tree.offset == Vector2.ZERO:
		_tree.cls = cls
		_tree.focus_class()
	_tree_points.text = "%s · очков: %d" % [Classes.CLASSES[cls].name, profile.free_points(cls)]
	_tree_reset.disabled = profile.allocated(cls).size() <= 1 or profile.gold < profile.TREE_RESET_PRICE


func _on_tree_hover(id: String, on: bool) -> void:
	if not on:
		if _tooltip_owner == _tree:
			_tooltip.visible = false
		return
	var n := TalentTree.node(id)
	for c in _tooltip_box.get_children():
		c.queue_free()
	var col: Color = TalentTree.CLASS_COLOR.get(n.cls, Color(0.85, 0.8, 1.0))
	var kind_name: String = {"start": "Старт класса", "small": "Талант", "notable": "Особый талант", "keystone": "Ключевой талант", "skill": "Уникальный навык"}[n.kind]
	_tooltip_box.add_child(_label(n.name, 20, col.lightened(0.3) if n.kind != "small" else Color(1, 0.95, 0.85)))
	_tooltip_box.add_child(_label(kind_name, 13, Color(0.7, 0.67, 0.8)))
	for line in TalentTree.describe(n).split("\n"):
		_tooltip_box.add_child(_label(line, 16, Color(0.55, 0.95, 0.55) if n.kind != "skill" else Color(1, 0.88, 0.55)))
	var cls: String = profile.selected_class
	var state := ""
	if profile.is_allocated(cls, id):
		state = "Изучено"
	elif n.cls != "" and n.cls != cls:
		state = "Только для класса «%s»" % Classes.CLASSES[n.cls].name
	elif not profile.is_reachable(cls, id):
		state = "Сначала изучи соседний узел"
	elif profile.free_points(cls) <= 0:
		state = "Нет очков талантов"
	else:
		state = "Нажми, чтобы изучить"
	_tooltip_box.add_child(_label(state, 14, Color(0.95, 0.85, 0.55)))
	_show_tooltip(_tree, col)


func _on_tree_click(id: String) -> void:
	var cls: String = profile.selected_class
	if profile.allocate(cls, id):
		var n := TalentTree.node(id)
		sfx.play("talent_big" if n.kind in ["skill", "notable", "keystone"] else "talent")
		_tree.burst(id)
		_refresh()
		_on_tree_hover(id, true)
	elif not profile.is_allocated(cls, id):
		sfx.play("error", -4.0)


# ---------- Вкладка «Сундуки» ----------

func _build_chest_page() -> Control:
	var p := _page()
	_chest = ChestView.new()
	_chest.position = Vector2(60, 96)
	_chest.size = Vector2(500, 380)
	_chest.opened.connect(_on_chest_opened)
	p.add_child(_chest)
	_open_btn = _button("Открыть сундук", 22, Color(0.5, 0.27, 0.06))
	_open_btn.position = Vector2(170, 484)
	_open_btn.custom_minimum_size = Vector2(280, 60)
	_open_btn.pressed.connect(_open_chest)
	p.add_child(_open_btn)
	var buy := _button("Купить за %d золота" % profile.CHEST_PRICE, 17, Color(0.2, 0.3, 0.1))
	buy.position = Vector2(170, 554)
	buy.custom_minimum_size = Vector2(280, 50)
	buy.pressed.connect(func():
		if profile.buy_chest():
			sfx.play("buy")
			_chest.bounce()
			_refresh()
		else:
			sfx.play("error")
			_popup_show("Не хватает золота.\nСундук стоит %d." % profile.CHEST_PRICE, Color(0.9, 0.4, 0.3)))
	p.add_child(buy)
	var odds_panel := PanelContainer.new()
	odds_panel.position = Vector2(620, 100)
	odds_panel.custom_minimum_size = Vector2(600, 0)
	odds_panel.add_theme_stylebox_override("panel", _panel_sb())
	p.add_child(odds_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 6)
	odds_panel.add_child(ov)
	ov.add_child(_header("Что внутри"))
	ov.add_child(_label("Новый предмет — 70%   ·   Очки талантов — 30%", 16, Color(0.9, 0.88, 0.95)))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 16)
	ov.add_child(rr)
	for o in profile.RARITY_ODDS:
		rr.add_child(_label("%s %d%%" % [Items.RARITY_NAME[o[0]], round(o[1] * 100)], 15, Items.RARITY_COLOR[o[0]].lightened(0.2)))
	ov.add_child(_label("Повторов нет: выпадают только вещи, которых у тебя ещё нет.\nСундуки дают за мини-боссов (1) и за победу над боссом (2).", 14, Color(0.72, 0.7, 0.82)))
	_chest_result = PanelContainer.new()
	_chest_result.position = Vector2(620, 320)
	_chest_result.custom_minimum_size = Vector2(600, 190)
	_chest_result.visible = false
	p.add_child(_chest_result)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	_chest_result.add_child(hb)
	_chest_result_icon = CenterContainer.new()
	_chest_result_icon.custom_minimum_size = Vector2(140, 140)
	hb.add_child(_chest_result_icon)
	_chest_result_label = _label("", 20)
	_chest_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chest_result_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(_chest_result_label)
	return p


func _open_chest() -> void:
	if _chest.busy:
		return
	var res: Dictionary = profile.open_chest()
	if res.is_empty():
		sfx.play("error")
		_popup_show("Сундуков нет.\nКупи сундук за золото или\nпобеждай мини-боссов.", Color(0.8, 0.8, 0.8))
		return
	_pending_loot = res
	_chest_result.visible = false
	_open_btn.disabled = true
	var col := Color(0.55, 0.85, 1.0)
	if res.type == "item":
		col = Items.RARITY_COLOR[res.item.rarity]
	_chest.play_open(col)
	_refresh()


func _star_icon() -> Control:
	var fly := Control.new()
	fly.custom_minimum_size = Vector2(120, 120)
	fly.size = Vector2(120, 120)
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.draw.connect(func():
		var c := Vector2(60, 60)
		fly.draw_circle(c, 52, Color(0.3, 0.6, 0.9, 0.25))
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + PI * i / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (48.0 if i % 2 == 0 else 20.0))
		fly.draw_colored_polygon(pts, Color(0.55, 0.85, 1.0))
		fly.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.8), 2.0, true))
	return fly


## Крышка открылась: добыча вылетает из сундука и ложится в панель справа.
func _on_chest_opened() -> void:
	var res := _pending_loot
	for c in _chest_result_icon.get_children():
		c.queue_free()
	var border := Color(0.55, 0.85, 1.0)
	var text := ""
	var fly: Control
	if res.type == "item":
		var it: Dictionary = res.item
		border = Items.RARITY_COLOR[it.rarity]
		text = "%s предмет!\n%s\n%s" % [Items.RARITY_NAME[it.rarity], it.name, Items.describe(it)]
		if profile.is_equipped(it.id):
			text += "\nСразу надет"
		sfx.play("reveal_" + it.rarity, 0.0, 0.0)
		fly = ItemIcon.create(it, 120)
		fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		text = "Очки талантов: +%d\nдля класса «%s»" % [res.points, Classes.CLASSES[profile.selected_class].name]
		sfx.play("reveal_rare", 0.0, 0.0)
		fly = _star_icon()
	_chest_result_label.text = text
	_chest_result.add_theme_stylebox_override("panel", _sb(Color(0.07, 0.05, 0.1, 0.97), border, 4, 16))
	# Полёт иконки из сундука
	var page: Control = _pages["chests"]
	page.add_child(fly)
	fly.top_level = true
	var start := _chest.global_position + Vector2(_chest.size.x / 2 - 60, _chest.size.y / 2 - 110)
	fly.global_position = start
	fly.pivot_offset = Vector2(60, 60)
	fly.scale = Vector2(0.2, 0.2)
	var tw := fly.create_tween()
	tw.tween_property(fly, "scale", Vector2(1.5, 1.5), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fly, "global_position", start + Vector2(0, -50), 0.35)
	tw.tween_interval(0.4)
	var target := _chest_result.global_position + Vector2(24, 35)
	tw.tween_property(fly, "global_position", target, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(fly, "scale", Vector2.ONE, 0.4)
	tw.tween_callback(func():
		fly.queue_free()
		var icon2: Control = _icon(res.item, 120) if res.type == "item" else _star_icon()
		_chest_result_icon.add_child(icon2)
		_chest_result.visible = true
		_chest_result.pivot_offset = _chest_result.size / 2
		_chest_result.scale = Vector2(0.85, 0.85)
		_chest_result.create_tween().tween_property(_chest_result, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_open_btn.disabled = false
		get_tree().create_timer(0.8).timeout.connect(_chest.close)
		_refresh())


# ---------- Вкладка «Библиотека» ----------

func _build_library_page() -> Control:
	var p := _page()
	var lp := PanelContainer.new()
	lp.position = Vector2(24, 96)
	lp.custom_minimum_size = Vector2(826, 524)
	lp.add_theme_stylebox_override("panel", _panel_sb())
	p.add_child(lp)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(796, 494)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lp.add_child(scroll)
	_library_box = VBoxContainer.new()
	_library_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_library_box)
	var panel := PanelContainer.new()
	panel.position = Vector2(866, 96)
	panel.custom_minimum_size = Vector2(390, 524)
	panel.add_theme_stylebox_override("panel", _panel_sb())
	p.add_child(panel)
	_lib_detail = VBoxContainer.new()
	_lib_detail.add_theme_constant_override("separation", 6)
	panel.add_child(_lib_detail)
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
		["Доспехи", "armor", ""], ["Амулеты", "amulet", ""], ["Кольца", "ring", ""]]
	for g in groups:
		_library_box.add_child(_header(g[0]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_library_box.add_child(row)
		for it in Items.ITEMS:
			if it.slot != g[1] or (g[2] != "" and it.get("cls", "") != g[2]):
				continue
			var ic := _icon(it, 76)
			ic.owned = it.id in profile.owned
			ic.equipped = profile.is_equipped(it.id)
			ic.selected = it.id == _lib_sel
			ic.pressed.connect(func(_i):
				_lib_sel = it.id
				sfx.play("click", -4.0)
				_refresh_library())
			row.add_child(ic)
	_refresh_lib_detail()


func _refresh_lib_detail() -> void:
	for c in _lib_detail.get_children():
		c.queue_free()
	var it := Items.by_id(_lib_sel)
	if it.is_empty():
		_lib_detail.add_child(_header("Библиотека"))
		_lib_detail.add_child(_label("Все предметы игры.\n\nНаведи на предмет —\nпокажутся характеристики.\nНажми — откроется здесь.\n\nТусклые с замком ещё не найдены:\nих дают сундуки.", 16, Color(0.7, 0.67, 0.8)))
		return
	var center := CenterContainer.new()
	_lib_detail.add_child(center)
	var big := ItemIcon.create(it, 170)
	big.owned = it.id in profile.owned
	big.equipped = profile.is_equipped(it.id)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(big)
	big.pivot_offset = Vector2(85, 85)
	big.scale = Vector2(0.7, 0.7)
	big.create_tween().tween_property(big, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	_lib_detail.add_child(info)
	_fill_info(info, it, _state_text(it), 24)
	var look: String = {"weapon": "Внешний вид: это оружие в руках героя.", "armor": "Внешний вид: плащ этого цвета.",
		"amulet": "Внешний вид: светящийся круг под ногами.", "ring": "Кольцо не видно на герое, зато даёт сильные бонусы."}[it.slot]
	var l := _label(look, 14, Color(0.7, 0.67, 0.8))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 360
	_lib_detail.add_child(l)
