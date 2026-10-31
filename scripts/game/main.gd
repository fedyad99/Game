extends Node3D
## Соло-прототип забега: арена, волны врагов, мини-босс, босс, карточки уровней.

const PlayerScript := preload("res://scripts/player/player.gd")
const EnemyScript := preload("res://scripts/enemies/enemy.gd")
const CardPanel := preload("res://scripts/ui/card_panel.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

## Тайминги прототипа укорочены для тестов (полный забег будет ~25 минут).
const MINIBOSS_TIME := 90.0
const BOSS_TIME := 180.0
const ARENA := 30.0

var player: CharacterBody3D
var camera: Camera3D
var run_time := 0.0
var spawn_timer := 0.0
var miniboss_spawned := false
var boss_spawned := false
var finished := false
var kills := 0

var hud_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var card_panel: Control
var end_panel: PanelContainer
var end_label: Label
var pending_levelups := 0


func _ready() -> void:
	randomize()
	_build_world()
	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 0)
	add_child(player)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_build_ui()
	player.hp_changed.connect(func(hp, mx):
		hp_bar.max_value = mx
		hp_bar.value = hp)
	player.xp_changed.connect(func(xp, need, _lvl):
		xp_bar.max_value = need
		xp_bar.value = xp)
	player.leveled_up.connect(_on_level_up)
	player.died.connect(func(): _end_run(false))
	xp_bar.max_value = player.xp_needed()


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
	# Пол
	_add_box(Vector3(0, -0.5, 0), Vector3(ARENA * 2, 1, ARENA * 2), Color(0.35, 0.6, 0.3))
	# Стены по краям
	for s in [-1, 1]:
		_add_box(Vector3(s * ARENA, 1.5, 0), Vector3(1, 3, ARENA * 2), Color(0.5, 0.45, 0.4))
		_add_box(Vector3(0, 1.5, s * ARENA), Vector3(ARENA * 2, 3, 1), Color(0.5, 0.45, 0.4))
	# Колонны-препятствия (карта нарисована вручную, а не генерируется)
	for p in [Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, 10),
			Vector3(0, 0, -18), Vector3(-18, 0, 0), Vector3(18, 0, 4)]:
		_add_box(p + Vector3(0, 1.5, 0), Vector3(2.5, 3, 2.5), Color(0.6, 0.55, 0.5))


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


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 16)
	box.custom_minimum_size = Vector2(320, 0)
	ui.add_child(box)
	hud_label = Label.new()
	box.add_child(hud_label)
	hp_bar = _bar(Color(0.85, 0.2, 0.2))
	box.add_child(hp_bar)
	xp_bar = _bar(Color(0.3, 0.6, 1.0))
	box.add_child(xp_bar)
	hp_bar.max_value = 100
	hp_bar.value = 100

	var touch := TouchControls.new()
	touch.player = player
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(touch)

	card_panel = CardPanel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.visible = false
	card_panel.card_chosen.connect(_on_card_chosen)
	ui.add_child(card_panel)

	end_panel = PanelContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_CENTER)
	end_panel.visible = false
	var ev := VBoxContainer.new()
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
	ui.add_child(end_panel)


func _bar(c: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 18)
	b.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	b.add_theme_stylebox_override("fill", sb)
	return b


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.global_position = player.global_position + Vector3(0, 16, 11)
	camera.look_at(player.global_position, Vector3.UP)
	if finished:
		return
	run_time += delta
	var stage := "Волны"
	if boss_spawned:
		stage = "БОСС"
	elif miniboss_spawned:
		stage = "До босса: %d c" % int(BOSS_TIME - run_time)
	else:
		stage = "До мини-босса: %d c" % int(MINIBOSS_TIME - run_time)
	hud_label.text = "Ур. %d   Убито: %d   %s" % [player.level, kills, stage]

	if not miniboss_spawned and run_time >= MINIBOSS_TIME:
		miniboss_spawned = true
		_spawn("miniboss")
	if not boss_spawned and run_time >= BOSS_TIME:
		boss_spawned = true
		_spawn("boss")
	spawn_timer -= delta
	if spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 40:
		var difficulty := 1.0 + run_time / 180.0
		spawn_timer = max(0.6, 2.2 - run_time / 120.0)
		for i in randi_range(1, 2):
			_spawn("normal", difficulty)


func _spawn(kind: String, difficulty: float = 1.0) -> void:
	var e: CharacterBody3D = EnemyScript.new()
	e.setup(kind, difficulty)
	var ang := randf() * TAU
	var pos := player.global_position + Vector3(cos(ang), 0, sin(ang)) * randf_range(14.0, 20.0)
	pos.x = clamp(pos.x, -ARENA + 3, ARENA - 3)
	pos.z = clamp(pos.z, -ARENA + 3, ARENA - 3)
	e.position = Vector3(pos.x, 0.1, pos.z)
	e.killed.connect(_on_enemy_killed)
	add_child(e)


func _on_enemy_killed(e) -> void:
	kills += 1
	player.add_xp(e.xp_reward)
	if e.kind == "boss":
		_end_run(true)


func _on_level_up() -> void:
	pending_levelups += 1
	if not card_panel.visible:
		_show_cards()


func _show_cards() -> void:
	get_tree().paused = true
	card_panel.show_cards(Cards.roll(player.player_class))


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
		"\nВремя: %d:%02d   Уровень: %d   Убито: %d" % [int(run_time) / 60, int(run_time) % 60, player.level, kills]
	end_panel.visible = true
