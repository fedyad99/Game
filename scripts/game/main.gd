extends Node3D
## Соло-забег по карте: лагеря монстров, мини-боссы, босс, карточки уровней.

const PlayerScript := preload("res://scripts/player/player.gd")
const EnemyScript := preload("res://scripts/enemies/enemy.gd")
const CardPanel := preload("res://scripts/ui/card_panel.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const DeckPanel := preload("res://scripts/ui/deck_panel.gd")
const MapData := preload("res://scripts/maps/forest_map.gd")
const WorldBuilder := preload("res://scripts/maps/world_builder.gd")

const RESPAWN_TIME := 60.0        # обычные монстры возрождаются через минуту
const RESPAWN_MIN_DIST := 18.0    # ...но не на глазах у игрока
const HEAL_ORB_CHANCE := 0.15

var player: CharacterBody3D
var camera_offset := Vector3(0, 12, 8.5)
var camera: Camera3D
var run_time := 0.0
var finished := false
var kills := 0
var gold := 0
var respawns: Array = []   # [{kind, power, home, t}]

var hud: Control
var deck_panel: Control
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
	WorldBuilder.new(self, MapData).build()


func _place_enemies() -> void:
	for camp in MapData.CAMPS:
		var center: Vector3 = camp[0]
		var types: Array = camp[2]
		for i in types.size():
			var a := TAU * i / types.size()
			_spawn(types[i], camp[1], center + Vector3(cos(a), 0, sin(a)) * 2.5)
	for b in MapData.BOSSES:
		_spawn(b[1], b[2], b[0], b[3])


func _spawn(kind: String, power: float, pos: Vector3, name_override := "", respawned := false) -> void:
	var e: CharacterBody3D = EnemyScript.new()
	e.setup(kind, power, name_override)
	e.spawn_anim = respawned
	e.position = pos
	e.killed.connect(_on_enemy_killed.bind(power))
	add_child(e)


# ---------- Интерфейс ----------

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	hud = Hud.new()
	hud.deck_pressed.connect(_toggle_deck)
	ui.add_child(hud)

	var touch := TouchControls.new()
	touch.player = player
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(touch)

	card_panel = CardPanel.new()
	card_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_panel.visible = false
	card_panel.card_chosen.connect(_on_card_chosen)
	ui.add_child(card_panel)

	deck_panel = DeckPanel.new()
	deck_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(deck_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	end_panel = PanelContainer.new()
	end_panel.visible = false
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	eb.border_color = Color(0.95, 0.75, 0.3)
	eb.set_border_width_all(3)
	eb.set_corner_radius_all(16)
	eb.set_content_margin_all(28)
	end_panel.add_theme_stylebox_override("panel", eb)
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
	again.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.45, 0.12, 0.1) if st == "normal" else Color(0.6, 0.18, 0.12)
		bs.border_color = Color(0.95, 0.75, 0.3)
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(10)
		again.add_theme_stylebox_override(st, bs)
	again.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	ev.add_child(again)


func _on_hp_changed(hp: float, mx: float) -> void:
	hud.hp = hp
	hud.max_hp = mx


func _on_xp_changed(xp: int, need: int, lvl: int) -> void:
	hud.xp = xp
	hud.xp_need = need
	hud.set_level(lvl)


func _toggle_deck() -> void:
	if deck_panel.visible:
		deck_panel.hide_deck()
	elif not card_panel.visible and not finished:
		deck_panel.show_deck(player.cards_taken, player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_toggle_deck()


# ---------- Игровой цикл ----------

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.global_position = player.global_position + camera_offset
	camera.look_at(player.global_position, Vector3.UP)
	if finished:
		return
	run_time += delta
	hud.time_s = run_time
	hud.kills = kills
	hud.gold = gold
	hud.skill_ratio = clamp(player.whirl_cooldown / 4.0, 0.0, 1.0) if "whirlwind" in player.skills else -1.0
	_update_boss_bar()
	_update_respawns(delta)


func _update_boss_bar() -> void:
	hud.boss_name = ""
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_boss and e.state == "chase":
			hud.boss_name = e.display_name
			hud.boss_max = e.max_hp
			hud.boss_hp = e.hp
			break


func _update_respawns(delta: float) -> void:
	for r in respawns.duplicate():
		r.t -= delta
		if r.t <= 0.0 and player.global_position.distance_to(r.home) > RESPAWN_MIN_DIST:
			respawns.erase(r)
			_spawn(r.kind, r.power, r.home, "", true)


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
	card_panel.show_cards(Cards.roll(player.player_class, player.skills), player.level - pending_levelups + 1)


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
