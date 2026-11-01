extends CharacterBody3D
## Герой. Класс (воин / лучник / маг) задаёт модель, характеристики, атаку и навык.
## Удар всегда по одной цели — ближайшему врагу в радиусе атаки. По области бьют только навыки.

const FloatingText := preload("res://scripts/ui/floating_text.gd")
const CharacterModel := preload("res://scripts/game/character_model.gd")
const Classes := preload("res://scripts/player/classes.gd")
const PlayerProjectile := preload("res://scripts/player/player_projectile.gd")
const Items := preload("res://scripts/meta/items.gd")

signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: int, need: int, level: int)
signal leveled_up
signal died

var player_class := "warrior"
var class_info: Dictionary
var stats := {
	"max_hp": 100.0, "damage": 30.0, "damage_mult": 1.0, "move_speed": 6.0,
	"move_speed_mult": 1.0, "attack_speed_mult": 1.0, "regen": 0.0,
	"damage_taken_mult": 1.0, "attack_range": 2.8, "attack_cd": 0.5,
	"crit_chance": 0.05, "lifesteal": 0.0, "skill_cd_mult": 1.0,
}
var skills: Array[String] = []
var skill_cd := {}            # навык -> сколько секунд осталось до готовности
var cards_taken: Array = []   # id взятых карточек по порядку
var hp := 100.0
var level := 1
var xp := 0
var attack_cooldown := 0.0
var facing := Vector3.FORWARD
var dead := false
var out_of_combat := 0.0   # секунд без урона; после 4 с идёт быстрое восстановление
var touch_move := Vector2.ZERO   # из виртуального стика
var touch_attack := false
var mouse_attack := true   # выключается, пока на экране карточки

var model: Node3D
var _whirl_fx: MeshInstance3D
var _sfx: Node
var buff_time := 0.0          # Боевой клич: +35% урона
var autocast := true          # false — навыки только вручную (Q / E / R или касание иконки)


var look := {}               # внешний вид от экипировки
var xp_mult := 1.0
var second_wind := false      # талант «Второе дыхание»: одна «жизнь» в запасе


## Вызывать до добавления в сцену.
## bonus — прибавки от экипировки и талантов {стат: значение}, lk — внешний вид (Profile.look).
func setup_class(cls: String, bonus: Dictionary = {}, lk: Dictionary = {}) -> void:
	player_class = cls if Classes.CLASSES.has(cls) else "warrior"
	class_info = Classes.CLASSES[player_class]
	look = lk
	for k in class_info.stats:
		stats[k] = class_info.stats[k]
	for k in bonus:
		if stats.has(k):
			stats[k] += bonus[k]
	stats.max_hp = round(stats.max_hp * (1.0 + bonus.get("max_hp_pct", 0.0)))
	xp_mult = 1.0 + bonus.get("xp_mult", 0.0)
	second_wind = bonus.get("second_wind", 0.0) > 0.0
	hp = stats.max_hp


func _ready() -> void:
	if class_info.is_empty():
		setup_class(player_class)
	_sfx = get_node_or_null("/root/Sfx")
	add_to_group("players")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	model = CharacterModel.new()
	add_child(model)
	if look.is_empty():
		look = Items.DEFAULT_LOOK[player_class]
	model.setup(class_info.model, class_info.hide, look.get("weapon", ""), look.get("offhand", ""))
	model.apply_look(look)
	# Круг для навыков по области
	_whirl_fx = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.05
	_whirl_fx.mesh = disc
	_whirl_fx.position.y = 0.15
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 0.6, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_whirl_fx.material_override = sm
	_whirl_fx.visible = false
	add_child(_whirl_fx)


func xp_needed() -> int:
	return 3 + level * 3


func _physics_process(delta: float) -> void:
	if dead:
		return
	var dir := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if dir == Vector2.ZERO:
		dir = touch_move
	var v := Vector3(dir.x, 0, dir.y).limit_length(1.0)
	var speed: float = stats.move_speed * stats.move_speed_mult
	velocity.x = v.x * speed
	velocity.z = v.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	if v.length() > 0.1:
		facing = v.normalized()
		look_at(global_position + facing, Vector3.UP)
	move_and_slide()
	if v.length() > 0.1:
		model.play("Running_A", 0.8 + 0.4 * stats.move_speed_mult)
	else:
		model.play("Idle")

	out_of_combat += delta
	var regen: float = stats.regen + (stats.max_hp * 0.05 if out_of_combat > 4.0 else 0.0)
	hp = min(hp + regen * delta, stats.max_hp)
	attack_cooldown -= delta
	buff_time -= delta
	var want_attack := Input.is_physical_key_pressed(KEY_SPACE) \
		or (mouse_attack and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or touch_attack
	if want_attack and attack_cooldown <= 0.0:
		attack()
	for sk in skills:
		skill_cd[sk] = skill_cd.get(sk, 0.0) - delta
		if autocast and skill_cd[sk] <= 0.0 and _use_skill(sk):
			skill_cd[sk] = skill_cooldown(sk)
	hp_changed.emit(hp, stats.max_hp)


## Ручное применение навыка по номеру слота. false — ещё перезаряжается или не по кому бить.
func cast_skill(i: int) -> bool:
	if dead or i < 0 or i >= skills.size():
		return false
	var sk: String = skills[i]
	if skill_cd.get(sk, 0.0) > 0.0:
		return false
	if _use_skill(sk):
		skill_cd[sk] = skill_cooldown(sk)
		return true
	FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.6, 0), "Нет цели", Color(0.8, 0.8, 0.8))
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := [KEY_Q, KEY_E, KEY_R].find(event.physical_keycode)
		if idx >= 0:
			cast_skill(idx)


func skill_cooldown(sk: String) -> float:
	return Classes.SKILLS[sk].cd * max(stats.skill_cd_mult, 0.4)


func _play(name_: String, db := 0.0) -> void:
	if _sfx:
		_sfx.play(name_, db)


func attack() -> void:
	attack_cooldown = stats.attack_cd / stats.attack_speed_mult
	var target := _find_target()
	if target:
		_face(target.global_position)
		if class_info.ranged:
			_fire(target.global_position + Vector3(0, 1.0 * target.scale.y, 0), class_info.projectile, 1.0)
			_play("arrow" if class_info.projectile == "arrow" else "fireball", -4.0)
		else:
			hit_enemy(target, 1.0)
			_play("swing", -5.0)
	elif class_info.ranged:
		return   # стрелки не тратят выстрел впустую
	model.play_once(class_info.attack_anim, min(stats.attack_cd / stats.attack_speed_mult, 0.6))


func _face(pos: Vector3) -> void:
	var to := pos - global_position
	to.y = 0
	if to.length() > 0.01:
		facing = to.normalized()
		look_at(global_position + facing, Vector3.UP)


## Выстрел снарядом в точку.
func _fire(at: Vector3, kind: String, mult: float, aoe := 0.0, pierce := false) -> PlayerProjectile:
	var pr := PlayerProjectile.new()
	pr.kind = kind
	pr.pierce = pierce
	pr.owner_player = self
	pr.mult = mult
	pr.aoe_radius = aoe
	var from := global_position + Vector3(0, 1.2, 0) + facing * 0.6
	var spd := 26.0 if kind == "arrow" else 18.0
	pr.velocity = (at - from).normalized() * spd
	pr.life = stats.attack_range / spd + 0.25
	get_parent().add_child(pr)
	pr.global_position = from
	return pr


## Цель удара: ближайший враг в пределах дальности (с учётом его размера).
func _find_target() -> Node3D:
	var best := INF
	var found: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp <= 0:
			continue
		var d: float = global_position.distance_to(e.global_position) - 0.5 * e.scale.x
		if d <= stats.attack_range and d < best:
			best = d
			found = e
	return found


## Один удар по врагу: шанс крита (x2) и вампиризм. Используется и снарядами.
func hit_enemy(e: Node, mult: float) -> void:
	if not is_instance_valid(e) or e.hp <= 0:
		return
	var crit: bool = randf() < stats.crit_chance
	var dmg: float = stats.damage * stats.damage_mult * mult * (2.0 if crit else 1.0) * (1.35 if buff_time > 0.0 else 1.0)
	e.take_damage(dmg, crit, self)
	if stats.lifesteal > 0.0:
		heal(dmg * stats.lifesteal, false)


func heal(amount: float, show := true) -> void:
	if dead:
		return
	var before := hp
	hp = min(hp + amount, stats.max_hp)
	if show and hp - before >= 1.0:
		FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), "+%d" % int(hp - before), Color(0.3, 1, 0.4))
	hp_changed.emit(hp, stats.max_hp)


## Навыки. Возвращает false, если применять не по кому (тогда навык ждёт цель).
func _use_skill(sk: String) -> bool:
	match sk:
		"whirlwind":
			var radius: float = stats.attack_range * 1.3
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) <= radius:
					hit_enemy(e, 0.8)
					any = true
			if not any:
				return false
			_ring_fx(radius)
			_play("whirlwind")
			model.play_once("2H_Melee_Attack_Spin", 0.45)
		"volley":
			if _find_target() == null:
				return false
			for i in 10:
				var a := TAU * i / 10.0
				_fire(global_position + Vector3(cos(a), 0.1, sin(a)) * 10.0 + Vector3(0, 1.0, 0), "arrow", 0.9)
			_play("volley")
			model.play_once("2H_Ranged_Shooting", 0.5)
		"meteor":
			var t := _find_target()
			if t == null:
				return false
			var pr := PlayerProjectile.new()
			pr.kind = "fireball"
			pr.owner_player = self
			pr.mult = 2.2
			pr.aoe_radius = 3.5
			pr.velocity = Vector3(0, -22, 0)
			pr.life = 0.5
			get_parent().add_child(pr)
			pr.global_position = t.global_position + Vector3(0, 11, 0)
			_play("fireball")
			model.play_once("Spellcast_Raise", 0.5)
		"charge":
			# Рывок к самому дальнему врагу в пределах 9 м
			var far: Node3D = null
			var fd := 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				var d: float = global_position.distance_to(e.global_position)
				if d > 3.5 and d < 9.0 and d > fd:
					fd = d
					far = e
			if far == null:
				return false
			var dest: Vector3 = far.global_position - (far.global_position - global_position).normalized() * 1.2
			dest.y = global_position.y
			_face(far.global_position)
			_play("dash")
			var tw := create_tween()
			tw.tween_property(self, "global_position", dest, 0.18)
			tw.tween_callback(func():
				for e in get_tree().get_nodes_in_group("enemies"):
					if e.global_position.distance_to(global_position) <= 3.0:
						hit_enemy(e, 1.5)
				_ring_fx(3.0)
				_play("hit", 2.0))
			model.play_once("1H_Melee_Attack_Stab", 0.35)
		"warcry":
			if _find_target() == null:
				return false
			buff_time = 5.0
			heal(stats.max_hp * 0.12)
			_ring_fx(4.0)
			_play("warcry")
			FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.8, 0), "Боевой клич!", Color(1, 0.6, 0.3), true)
			model.play_once("Cheer", 0.5)
		"trap":
			var tt := _find_target()
			if tt == null:
				return false
			_spawn_trap(tt.global_position)
			_play("trap")
		"pierce":
			var tp := _find_target()
			if tp == null:
				return false
			_face(tp.global_position)
			var pr := _fire(tp.global_position + Vector3(0, 1.0, 0), "arrow", 1.6, 0.0, true)
			pr.life *= 1.6
			_play("arrow", 2.0)
			model.play_once("2H_Ranged_Shoot", 0.4)
		"frost_nova":
			var r := 5.0
			var hit_any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) <= r:
					hit_enemy(e, 0.9)
					if is_instance_valid(e) and e.hp > 0:
						e.slow(3.0)
					hit_any = true
			if not hit_any:
				return false
			_nova_fx(r)
			_play("frost")
			model.play_once("Spellcast_Raise", 0.4)
		"chain_lightning":
			var first := _find_target()
			if first == null:
				return false
			var hit_list: Array = [first]
			var cur: Node3D = first
			for i in 4:
				var nxt: Node3D = null
				var bd := 6.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if e in hit_list:
						continue
					var d: float = e.global_position.distance_to(cur.global_position)
					if d < bd:
						bd = d
						nxt = e
				if nxt == null:
					break
				hit_list.append(nxt)
				cur = nxt
			var prev := global_position + Vector3(0, 1.3, 0)
			for e in hit_list:
				var p2: Vector3 = e.global_position + Vector3(0, 1.0 * e.scale.y, 0)
				_bolt_fx(prev, p2)
				prev = p2
				hit_enemy(e, 1.1)
			_play("blink")
			model.play_once("Spellcast_Shoot", 0.35)
	return true


func _spawn_trap(pos: Vector3) -> void:
	var trap := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.5
	tor.outer_radius = 0.8
	trap.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.75, 0.8)
	m.metallic = 0.8
	trap.material_override = m
	get_parent().add_child(trap)
	trap.global_position = Vector3(pos.x, 0.15, pos.z)
	trap.scale = Vector3(1, 0.4, 1)
	var tw := trap.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		if not is_instance_valid(self):
			return
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(trap.global_position) <= 3.0:
				hit_enemy(e, 2.0)
		if _sfx:
			_sfx.play("explosion", -4.0)
		m.albedo_color = Color(1, 0.6, 0.2)
		m.emission_enabled = true
		m.emission = Color(1, 0.5, 0.1))
	tw.tween_property(trap, "scale", Vector3(4, 0.2, 4), 0.15)
	tw.tween_callback(trap.queue_free)


func _nova_fx(r: float) -> void:
	var fx := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	fx.mesh = tor
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.9, 1.0, 0.8)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.8, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx.material_override = m
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector3(0, 0.3, 0)
	fx.scale = Vector3(0.5, 0.5, 0.5)
	var tw := fx.create_tween().set_parallel()
	tw.tween_property(fx, "scale", Vector3(r, 0.6, r), 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(fx.queue_free)


## Молния между двумя точками: зигзаг из тонких светящихся отрезков.
func _bolt_fx(a: Vector3, b: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.8, 1.0)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 6
	var pts := [a]
	for i in range(1, steps):
		pts.append(a.lerp(b, float(i) / steps) + Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35)))
	pts.append(b)
	for i in steps:
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var side := (p2 - p1).cross(Vector3.UP).normalized() * 0.07
		var up := Vector3(0, 0.07, 0)
		for off in [side, up]:
			im.surface_add_vertex(p1 - off)
			im.surface_add_vertex(p1 + off)
			im.surface_add_vertex(p2 + off)
			im.surface_add_vertex(p1 - off)
			im.surface_add_vertex(p2 + off)
			im.surface_add_vertex(p2 - off)
	im.surface_end()
	get_parent().add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _ring_fx(radius: float) -> void:
	_whirl_fx.scale = Vector3(radius, 1, radius)
	_whirl_fx.visible = true
	get_tree().create_timer(0.2).timeout.connect(func(): _whirl_fx.visible = false)


func take_damage(amount: float) -> void:
	if dead:
		return
	out_of_combat = 0.0
	var dmg: float = amount * max(stats.damage_taken_mult, 0.2)
	hp -= dmg
	FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), str(int(round(dmg))), Color(1, 0.3, 0.3))
	model.flash(Color(1, 0.3, 0.3))
	_play("hurt", -6.0)
	if hp <= 0 and second_wind:
		second_wind = false
		hp = stats.max_hp * 0.4
		FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.8, 0), "Второе дыхание!", Color(1, 0.9, 0.4), true)
		model.play_once("Cheer", 0.6)
		_play("heal", 2.0)
	elif hp <= 0:
		hp = 0
		dead = true
		model.play_once("Death_A", -1.0)
		model._locked_until = INF
		died.emit()
	hp_changed.emit(hp, stats.max_hp)


func add_xp(amount: int) -> void:
	xp += int(round(amount * xp_mult))
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		_play("level_up")
		leveled_up.emit()
	xp_changed.emit(xp, xp_needed(), level)


func apply_card(card: Dictionary) -> void:
	cards_taken.append(card.id)
	if card.has("skill"):
		skills.append(card.skill)
	elif card.has("stat"):
		stats[card.stat] += card.value
		if card.stat == "max_hp":
			hp += card.value
	hp_changed.emit(hp, stats.max_hp)
