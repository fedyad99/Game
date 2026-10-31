extends CharacterBody3D
## Враг. Стоит в своём лагере (home) и нападает, когда игрок подходит близко.
## Если игрок убежал далеко от лагеря, враг возвращается и восстанавливает здоровье.

signal killed(enemy)

const FloatingText := preload("res://scripts/ui/floating_text.gd")
const WorldBar := preload("res://scripts/ui/world_bar.gd")
const Projectile := preload("res://scripts/enemies/projectile.gd")
const CharacterModel := preload("res://scripts/game/character_model.gd")
const SK := "res://assets/kaykit/skeletons/"

## Базовые характеристики типов. power — множитель зоны (сложнее дальше по карте).
const TYPES := {
	"grunt": {"name": "", "hp": 45.0, "dmg": 6.0, "speed": 3.6, "xp": 2, "gold": 1, "scale": 1.0,
		"model": "Skeleton_Minion", "weapon": "Skeleton_Blade", "color": Color(0.8, 0.3, 0.25), "aggro": 9.0},
	"archer": {"name": "", "hp": 32.0, "dmg": 7.0, "speed": 3.2, "xp": 3, "gold": 2, "scale": 0.9,
		"model": "Skeleton_Rogue", "weapon": "Skeleton_Crossbow", "color": Color(0.9, 0.7, 0.2), "aggro": 12.0, "ranged": true},
	"brute": {"name": "", "hp": 140.0, "dmg": 13.0, "speed": 2.6, "xp": 5, "gold": 3, "scale": 1.35,
		"model": "Skeleton_Warrior", "weapon": "Skeleton_Axe", "color": Color(0.45, 0.3, 0.2), "aggro": 8.0},
	"miniboss": {"name": "Вожак", "hp": 650.0, "dmg": 14.0, "speed": 3.2, "xp": 20, "gold": 15, "scale": 1.8,
		"model": "Skeleton_Warrior", "weapon": "Skeleton_Blade", "offhand": "Skeleton_Shield_Small_A", "color": Color(0.65, 0.3, 0.9), "aggro": 12.0, "boss": true},
	"boss": {"name": "Король тьмы", "hp": 2400.0, "dmg": 15.0, "speed": 3.0, "xp": 60, "gold": 60, "scale": 2.6,
		"model": "Skeleton_Mage", "weapon": "Skeleton_Staff", "color": Color(0.18, 0.15, 0.22), "aggro": 16.0, "boss": true},
}

var kind := "grunt"
var display_name := ""
var max_hp := 45.0
var hp := 45.0
var speed := 3.6
var damage := 6.0
var xp_reward := 2
var gold_reward := 1
var aggro_radius := 9.0
var leash := 28.0
var ranged := false
var is_boss := false

var home := Vector3.ZERO
var state := "idle"   # idle / chase / return
var target: Node3D = null
var hit_cooldown := 0.0
var ability_cooldown := 4.0
var _casting := 0.0
var _charge_time := 0.0
var _charge_dir := Vector3.ZERO
var _charge_hit := false
var model: Node3D
var _model_info: Dictionary
var spawn_anim := false   # проиграть «вылезание из земли» (при возрождении)
var _spawn_lock := 0.0
var _color := Color.RED
var _bar: Node3D
var _telegraph: MeshInstance3D


func setup(k: String, power: float, name_override := "") -> void:
	kind = k
	var t: Dictionary = TYPES[k]
	max_hp = t.hp * power
	damage = t.dmg * power
	speed = t.speed
	xp_reward = int(round(t.xp * power))
	gold_reward = int(round(t.gold * power))
	aggro_radius = t.aggro
	ranged = t.get("ranged", false)
	is_boss = t.get("boss", false)
	display_name = name_override if name_override != "" else t.name
	_color = t.color
	_model_info = t
	scale = Vector3.ONE * t.scale
	hp = max_hp
	if k == "boss":
		leash = 45.0


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.position.y = 1.0
	add_child(col)
	model = CharacterModel.new()
	add_child(model)
	model.setup(SK + _model_info.model + ".glb", [],
		SK + _model_info.weapon + ".gltf" if _model_info.has("weapon") else "",
		SK + _model_info.offhand + ".gltf" if _model_info.has("offhand") else "")
	if is_boss:
		model.tint(_color)
	if spawn_anim:
		model.play_once("Spawn_Ground_Skeletons", 1.2)
		_spawn_lock = 1.2
	_bar = WorldBar.new()
	_bar.setup(Color(0.9, 0.15, 0.15), 1.3)
	_bar.position.y = 2.5
	add_child(_bar)
	if display_name != "":
		var lbl := Label3D.new()
		lbl.text = display_name
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 40
		lbl.pixel_size = 0.006
		lbl.outline_size = 8
		lbl.modulate = Color(1, 0.85, 0.4)
		lbl.position.y = 2.85
		add_child(lbl)
	_telegraph = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.height = 0.05
	_telegraph.mesh = disc
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(1, 0.1, 0.1, 0.35)
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph.material_override = tm
	_telegraph.visible = false
	_telegraph.top_level = true
	add_child(_telegraph)
	# Лёгкий случайный поворот, чтобы лагерь выглядел живее
	rotation.y = randf() * TAU


func _nearest_player() -> Node3D:
	var best := INF
	var found: Node3D = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best:
			best = d
			found = p
	return found


## Тревога: враг начинает преследовать игрока (вызывается и для соседей по лагерю).
func alert(p: Node3D) -> void:
	if state == "chase" or p == null:
		return
	state = "chase"
	target = p
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.state == "idle" and e.home.distance_to(home) < 8.0:
			e.alert(p)


func _physics_process(delta: float) -> void:
	hit_cooldown -= delta
	ability_cooldown -= delta
	if hp <= 0:
		return
	if _spawn_lock > 0.0:
		_spawn_lock -= delta
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	match state:
		"idle":
			var p := _nearest_player()
			if p and p.global_position.distance_to(global_position) < aggro_radius:
				alert(p)
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
			model.play("Idle")
		"return":
			var to := home - global_position
			to.y = 0
			if to.length() < 0.8:
				state = "idle"
				hp = max_hp
				_bar.set_ratio(1.0)
			else:
				_move_dir(to.normalized(), speed * 1.5)
		"chase":
			_chase(delta)


func _move_dir(dir: Vector3, spd: float) -> void:
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if dir.length() > 0.1:
		look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
		model.play("Running_A" if spd > 3.4 else "Walking_D_Skeletons", spd / 3.5)
	else:
		model.play("Idle_Combat")
	move_and_slide()


func _chase(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		target = _nearest_player()
		if target == null:
			state = "return"
			return
	if global_position.distance_to(home) > leash:
		state = "return"
		target = null
		return
	if _casting > 0.0:
		_casting -= delta
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		if _casting <= 0.0:
			_finish_ability()
		return
	if _charge_time > 0.0:
		_charge_time -= delta
		_move_dir(_charge_dir, speed * 4.0)
		if not _charge_hit and target.global_position.distance_to(global_position) < 1.6 * scale.x:
			_charge_hit = true
			target.take_damage(damage * 1.8)
		return

	var to := target.global_position - global_position
	to.y = 0
	var dist := to.length()
	if is_boss and ability_cooldown <= 0.0 and dist < 14.0:
		_start_ability()
		return
	if ranged:
		if dist > 10.0:
			_move_dir(to.normalized(), speed)
		elif dist < 5.0:
			_move_dir(-to.normalized(), speed)
		else:
			_move_dir(Vector3.ZERO, 0)
			look_at(global_position + to, Vector3.UP)
		if hit_cooldown <= 0.0 and dist < 13.0:
			hit_cooldown = 1.8
			_shoot(to.normalized())
			model.play_once("1H_Ranged_Shoot", 0.6)
		return
	var reach := 1.0 + 0.6 * scale.x
	if dist > reach:
		_move_dir(to.normalized(), speed)
	else:
		_move_dir(Vector3.ZERO, 0)
		look_at(global_position + to, Vector3.UP)
		if hit_cooldown <= 0.0:
			hit_cooldown = 1.7 if is_boss else 1.2
			target.take_damage(damage)
			model.play_once("2H_Melee_Attack_Chop" if kind == "brute" else "1H_Melee_Attack_Chop", 0.6)


func _shoot(dir: Vector3, spd := 12.0, dmg := -1.0) -> void:
	var pr := Projectile.new()
	pr.velocity = dir * spd
	pr.damage = damage if dmg < 0 else dmg
	get_parent().add_child(pr)
	pr.global_position = global_position + Vector3(0, 1.0 * scale.y, 0) + dir * 0.8


## Умения боссов: мини-босс делает рывок, босс бьёт по площади (и стреляет кольцом на 2-й фазе).
func _start_ability() -> void:
	if kind == "miniboss":
		ability_cooldown = 6.0
		_casting = 0.7
		_telegraph.mesh.top_radius = 1.2
		_telegraph.mesh.bottom_radius = 1.2
		_telegraph.global_position = global_position + Vector3(0, 0.1, 0)
		model.play_once("Taunt", _casting)
	else:
		ability_cooldown = 5.0
		_casting = 1.1
		_telegraph.mesh.top_radius = 5.5
		_telegraph.mesh.bottom_radius = 5.5
		_telegraph.global_position = global_position + Vector3(0, 0.1, 0)
		model.play_once("Spellcast_Raise", _casting)
	_telegraph.visible = true


func _finish_ability() -> void:
	_telegraph.visible = false
	if kind == "miniboss":
		var to := target.global_position - global_position
		to.y = 0
		_charge_dir = to.normalized()
		_charge_time = 0.55
		_charge_hit = false
		model.play_once("2H_Melee_Attack_Spinning", 0.55)
	else:
		model.play_once("Spellcast_Shoot", 0.5)
		for p in get_tree().get_nodes_in_group("players"):
			if not p.dead and p.global_position.distance_to(global_position) < 5.5:
				p.take_damage(damage * 1.6)
		if hp < max_hp * 0.5:
			for i in 12:
				var a := TAU * i / 12.0
				_shoot(Vector3(cos(a), 0, sin(a)), 9.0, damage * 0.6)


func take_damage(amount: float, crit := false, from: Node3D = null) -> void:
	if hp <= 0:
		return
	hp -= amount
	FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.2 * scale.y, 0),
		str(int(round(amount))) + ("!" if crit else ""),
		Color(1, 0.85, 0.2) if crit else Color.WHITE, crit)
	_bar.set_ratio(hp / max_hp)
	if state != "chase":
		alert(from if from else _nearest_player())
	model.flash()
	if hp <= 0:
		_die()


func _die() -> void:
	_telegraph.visible = false
	_bar.visible = false
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	killed.emit(self)
	model.play_once("Death_A", 1.0)
	model._locked_until = INF
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(self, "position:y", position.y - 1.5, 0.8)
	tw.tween_callback(queue_free)
