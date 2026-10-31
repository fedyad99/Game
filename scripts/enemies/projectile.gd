extends Node3D
## Снаряд врага-стрелка (или босса). Летит прямо, бьёт первого игрока, в которого попал.

var velocity := Vector3.ZERO
var damage := 6.0
var life := 2.5
var radius := 0.7


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.25
	s.height = 0.5
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.1)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.0)
	mi.material_override = m
	add_child(mi)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0:
		queue_free()
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		var to: Vector3 = p.global_position + Vector3(0, 1, 0) - global_position
		if to.length() < radius:
			p.take_damage(damage)
			queue_free()
			return
