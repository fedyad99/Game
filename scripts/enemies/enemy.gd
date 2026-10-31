extends CharacterBody3D
## Враг: идёт к ближайшему игроку и бьёт при касании. kind: normal / miniboss / boss.

signal killed(enemy)

var kind := "normal"
var max_hp := 40.0
var hp := 40.0
var speed := 3.2
var damage := 8.0
var xp_reward := 1
var hit_cooldown := 0.0
var _mesh: MeshInstance3D
var _color := Color(0.8, 0.25, 0.25)


func setup(k: String, difficulty: float) -> void:
	kind = k
	match k:
		"miniboss":
			max_hp = 600.0
			speed = 3.0
			damage = 18.0
			xp_reward = 15
			_color = Color(0.7, 0.3, 0.9)
			scale = Vector3.ONE * 1.8
		"boss":
			max_hp = 2500.0
			speed = 2.8
			damage = 30.0
			xp_reward = 50
			_color = Color(0.15, 0.15, 0.15)
			scale = Vector3.ONE * 2.8
		_:
			max_hp = 30.0 * difficulty
			damage = 5.0 * difficulty
	hp = max_hp


func _ready() -> void:
	add_to_group("enemies")
	var col := CollisionShape3D.new()
	col.shape = CapsuleShape3D.new()
	col.position.y = 1.0
	add_child(col)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = CapsuleMesh.new()
	_mesh.position.y = 1.0
	var m := StandardMaterial3D.new()
	m.albedo_color = _color
	_mesh.material_override = m
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	var target: Node3D = null
	var best := INF
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best:
			best = d
			target = p
	hit_cooldown -= delta
	if target == null:
		return
	var to := target.global_position - global_position
	to.y = 0
	var reach := 1.4 * scale.x
	if to.length() > reach:
		var dir := to.normalized()
		velocity = Vector3(dir.x * speed, 0, dir.z * speed)
		move_and_slide()
	elif hit_cooldown <= 0.0:
		hit_cooldown = 1.2
		target.take_damage(damage)


func take_damage(amount: float) -> void:
	if hp <= 0:
		return
	hp -= amount
	var m: StandardMaterial3D = _mesh.material_override
	m.albedo_color = Color.WHITE
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			m.albedo_color = _color)
	if hp <= 0:
		killed.emit(self)
		queue_free()
