extends Node3D
## Соло-забег по карте: лагеря монстров, мини-боссы, босс, карточки уровней.

const PlayerScript := preload("res://scripts/player/player.gd")
const EnemyScript := preload("res://scripts/enemies/enemy.gd")
const CardPanel := preload("res://scripts/ui/card_panel.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const MapData := preload("res://scripts/maps/forest_map.gd")

const RESPAWN_TIME := 60.0        # обычные монстры возрождаются через минуту
const RESPAWN_MIN_DIST := 18.0    # ...но не на глазах у игрока
const HEAL_ORB_CHANCE := 0.15

var player: CharacterBody3D
var camera: Camera3D
var run_time := 0.0
var finished := false
var kills := 0
var gold := 0
var respawns: Array = []   # [{kind, power, home, t}]

var hud_label: Label
var hp_bar: ProgressBar
var hp_text: Label
var xp_bar: ProgressBar
var xp_text: Label
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var card_panel: Control
var end_panel: PanelContainer
var end_label: Label
var pending_levelups := 0


func _ready() -> void:
	randomize()
	_build_world()
	player = PlayerScript.new()
	player.position = MapData.START
	add_child(player)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_build_ui()
	player.hp_changed.connect(_on_hp_changed)
	player.xp_changed.connect(_on_xp_changed)
	player.leveled_up.connect(_on_level_up)
	player.died.connect(func(): _end_run(false))
	_on_hp_changed(player.hp, player.stats.max_hp)
	_on_xp_changed(0, player.xp_needed(), 1)
	_place_enemies()


# ---------- Мир ----------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.65, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	for z in MapData.ZONES:
		_add_box(z[0], z[1], z[2])
	for w in MapData.WALLS:
		_add_box(w[0], w[1], Color(0.5, 0.45, 0.4))
	for r in MapData.ROCKS:
		_add_box(r + Vector3(0, 1.2, 0), Vector3(2.4, 2.4, 2.4), Color(0.6, 0.58, 0.55))


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mesh.material_override = m
	body.add_child(mesh)
	add_child(body)


func _place_enemies() -> void:
	for camp in MapData.CAMPS:
		var center: Vector3 = camp[0]
		var types: Array = camp[2]
		for i in types.size():
			var a := TAU * i / types.size()
			_spawn(types[i], camp[1], center + Vector3(cos(a), 0, sin(a)) * 2.5)
	for b in MapData.BOSSES:
		_spawn(b[1], b[2], b[0], b[3])


func _spawn(kind: String, power: float, pos: Vector3, name_override := "") -> void:
	var e: CharacterBody3D = EnemyScript.new()
	e.setup(kind, power, name_override)
	e.position = pos
	e.killed.connect(_on_enemy_killed.bind(power))
	add_child(e)


# ---------- Интерфейс ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.add_theme_constant_override("separation", 6)
	ui.add_child(box)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 20)
	hud_label.add_theme_constant_override("outline_size", 6)
	box.add_child(hud_label)
	var hp := _bar_with_text(Color(0.85, 0.2, 0.2), Vector2(340, 28))
	hp_bar = hp[0]
	hp_text = hp[1]
	box.add_child(hp_bar)
	var xp := _bar_with_text(Color(0.3, 0.6, 1.0), Vector2(340, 22))
	xp_bar = xp[0]
	xp_text = xp[1]
	box.add_child(xp_bar)

	# Полоска босса сверху по центру — появляется, когда босс в бою
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-260, 16)
	boss_box.custom_minimum_size = Vector2(520, 0)
	boss_box.visible = false
	ui.add_child(boss_box)
	boss_name = Label.new()
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_font_size_override("font_size", 22)
	boss_name.add_theme_constant_override("outline_size", 6)
	boss_box.add_child(boss_name)
	boss_bar = _bar_with_text(Color(0.6, 0.15, 0.7), Vector2(520, 20))[0]
	boss_box.add_child(boss_bar)

	var touch := TouchControls.new()
	touch.player = player
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(touch)

	card_panel = CardPanel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.visible = false
	card_panel.card_chosen.connect(_on_card_chosen)
	ui.add_child(card_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	end_panel = PanelContainer.new()
	end_panel.visible = false
	center.add_child(end_panel)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 16)
	end_panel.add_child(ev)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 28)
	ev.add_child(end_label)
	var again := Button.new()
	again.text = "Начать заново"
	again.custom_minimum_size = Vector2(260, 64)
	again.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	ev.add_child(again)


## Полоска с числом поверх: возвращает [ProgressBar, Label].
func _bar_with_text(c: Color, size: Vector2) -> Array:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = c
	fill.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size.y * 0.65))
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_child(l)
	return [b, l]


func _on_hp_changed(hp: float, mx: float) -> void:
	hp_bar.max_value = mx
	hp_bar.value = hp
	hp_text.text = "%d / %d" % [ceil(hp), mx]


func _on_xp_changed(xp: int, need: int, lvl: int) -> void:
	xp_bar.max_value = need
	xp_bar.value = xp
	xp_text.text = "Уровень %d   —   %d / %d опыта" % [lvl, xp, need]


# ---------- Игровой цикл ----------

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.global_position = player.global_position + Vector3(0, 16, 11)
	camera.look_at(player.global_position, Vector3.UP)
	if finished:
		return
	run_time += delta
	hud_label.text = "Время %d:%02d     Убито: %d     Золото: %d" % [int(run_time) / 60, int(run_time) % 60, kills, gold]
	_update_boss_bar()
	_update_respawns(delta)


func _update_boss_bar() -> void:
	var shown := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss and e.state == "chase":
			boss_name.text = e.display_name
			boss_bar.max_value = e.max_hp
			boss_bar.value = e.hp
			shown = true
			break
	boss_box.visible = shown


func _update_respawns(delta: float) -> void:
	for r in respawns.duplicate():
		r.t -= delta
		if r.t <= 0.0 and player.global_position.distance_to(r.home) > RESPAWN_MIN_DIST:
			respawns.erase(r)
			_spawn(r.kind, r.power, r.home)


func _on_enemy_killed(e, power: float) -> void:
	kills += 1
	gold += e.gold_reward
	player.add_xp(e.xp_reward)
	if not e.is_boss:
		respawns.append({"kind": e.kind, "power": power, "home": e.home, "t": RESPAWN_TIME})
		if randf() < HEAL_ORB_CHANCE:
			_drop_heal_orb(e.global_position)
	if e.kind == "boss":
		_end_run(true)


func _drop_heal_orb(pos: Vector3) -> void:
	var orb := Area3D.new()
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	col.shape = sh
	orb.add_child(col)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1, 0.4)
	m.emission_enabled = true
	m.emission = Color(0.1, 0.8, 0.2)
	mi.material_override = m
	orb.add_child(mi)
	orb.position = Vector3(pos.x, 0.6, pos.z)
	orb.body_entered.connect(func(b):
		if b.is_in_group("players") and not b.dead:
			b.heal(20.0)
			orb.queue_free())
	add_child(orb)


func _on_level_up() -> void:
	pending_levelups += 1
	if not card_panel.visible:
		_show_cards()


func _show_cards() -> void:
	get_tree().paused = true
	card_panel.show_cards(Cards.roll(player.player_class, player.skills))


func _on_card_chosen(card: Dictionary) -> void:
	player.apply_card(card)
	pending_levelups -= 1
	if pending_levelups > 0 and not finished:
		_show_cards()
	else:
		card_panel.visible = false
		get_tree().paused = finished


func _end_run(victory: bool) -> void:
	if finished:
		return
	finished = true
	get_tree().paused = true
	card_panel.visible = false
	end_label.text = ("ПОБЕДА!" if victory else "Ты погиб") + \
		"\nВремя: %d:%02d   Уровень: %d\nУбито: %d   Золото: %d" % [
			int(run_time) / 60, int(run_time) % 60, player.level, kills, gold]
	end_panel.visible = true
