extends CharacterBody3D
## Воин: ручное движение и удар мечом по дуге перед собой.

signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: int, need: int, level: int)
signal leveled_up
signal died

var player_class := "warrior"
var stats := {
	"max_hp": 100.0, "damage": 30.0, "damage_mult": 1.0, "move_speed": 6.0,
	"move_speed_mult": 1.0, "attack_speed_mult": 1.0, "regen": 0.0,
	"damage_taken_mult": 1.0, "attack_range": 2.8,
}
var skills: Array[String] = []
var hp := 100.0
var level := 1
var xp := 0
var attack_cooldown := 0.0
var whirl_cooldown := 0.0
var facing := Vector3.FORWARD
var dead := false
var touch_move := Vector2.ZERO   # из виртуального стика
var touch_attack := false

var _swing: MeshInstance3D


func _ready() -> void:
	add_to_group("players")
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.position.y = 1.0
	add_child(col)
	var body := MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.position.y = 1.0
	body.material_override = _mat(Color(0.25, 0.5, 1.0))
	add_child(body)
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.6)
	nose.mesh = box
	nose.position = Vector3(0, 1.4, -0.5)
	nose.material_override = _mat(Color(0.9, 0.9, 0.9))
	add_child(nose)
	_swing = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = stats.attack_range
	disc.bottom_radius = stats.attack_range
	disc.height = 0.05
	_swing.mesh = disc
	_swing.position.y = 0.3
	var sm := _mat(Color(1, 1, 0.5, 0.35))
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swing.material_override = sm
	_swing.visible = false
	add_child(_swing)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


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

	hp = min(hp + stats.regen * delta, stats.max_hp)
	attack_cooldown -= delta
	whirl_cooldown -= delta
	var want_attack := Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or touch_attack
	if want_attack and attack_cooldown <= 0.0:
		attack()
	if "whirlwind" in skills and whirl_cooldown <= 0.0:
		whirlwind()
	hp_changed.emit(hp, stats.max_hp)


func attack() -> void:
	attack_cooldown = 0.5 / stats.attack_speed_mult
	_auto_aim()
	_flash_swing()
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0
		if to.length() <= stats.attack_range * e.scale.x and facing.dot(to.normalized()) > 0.0:
			e.take_damage(stats.damage * stats.damage_mult)


## Автонаведение: удар разворачивает героя к ближайшему врагу рядом (удобно на телефоне).
func _auto_aim() -> void:
	var best: float = stats.attack_range * 1.6
	var target: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position) - 0.5 * e.scale.x
		if d < best:
			best = d
			target = e
	if target:
		var to := target.global_position - global_position
		to.y = 0
		if to.length() > 0.01:
			facing = to.normalized()
			look_at(global_position + facing, Vector3.UP)


func whirlwind() -> void:
	whirl_cooldown = 4.0
	_flash_swing()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= stats.attack_range * 1.3:
			e.take_damage(stats.damage * stats.damage_mult * 0.8)


func _flash_swing() -> void:
	_swing.visible = true
	get_tree().create_timer(0.12).timeout.connect(func(): _swing.visible = false)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount * max(stats.damage_taken_mult, 0.2)
	if hp <= 0:
		hp = 0
		dead = true
		died.emit()
	hp_changed.emit(hp, stats.max_hp)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit()
	xp_changed.emit(xp, xp_needed(), level)


func apply_card(card: Dictionary) -> void:
	if card.has("skill"):
		skills.append(card.skill)
	elif card.has("stat"):
		stats[card.stat] += card.value
		if card.stat == "max_hp":
			hp += card.value
	hp_changed.emit(hp, stats.max_hp)
