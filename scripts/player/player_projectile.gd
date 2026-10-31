extends Node3D
## Снаряд героя: стрела или огненный шар. Летит прямо и бьёт первого врага на пути.
## Если задан aoe_radius — при попадании взрывается и бьёт всех рядом (для навыка «Метеор»).

const FloatingText := preload("res://scripts/ui/floating_text.gd")

var velocity := Vector3.ZERO
var owner_player: Node
var mult := 1.0
var kind := "arrow"
var life := 1.2
var aoe_radius := 0.0
var _hit_done := false


func _ready() -> void:
	if kind == "arrow":
		var arrow: Node3D = load("res://assets/kaykit/adventurers/arrow.gltf").instantiate()
		arrow.scale = Vector3.ONE * 1.4
		arrow.rotation.x = -PI / 2   # модель стрелы смотрит вверх, разворачиваем по полёту
		add_child(arrow)
	else:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.3 if aoe_radius <= 0.0 else 0.7
		s.height = s.radius * 2
		mi.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.5, 0.1)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.35, 0.0)
		m.emission_energy_multiplier = 2.0
		mi.material_override = m
		add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = Color(1, 0.5, 0.1)
		light.omni_range = 4.0
		add_child(light)
	if velocity.length() > 0.01:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		if aoe_radius > 0.0:
			_explode(null)   # метеор взрывается, даже если цель ушла
		else:
			queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position + Vector3(0, 1.0, 0) - global_position
		if Vector2(to.x, to.z).length() < 0.6 + 0.4 * e.scale.x and absf(to.y) < 2.0 * e.scale.y:
			_explode(e)
			return


func _explode(first: Node) -> void:
	if _hit_done:
		return
	_hit_done = true
	if is_instance_valid(owner_player):
		if aoe_radius > 0.0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.global_position.distance_to(global_position) <= aoe_radius:
					owner_player.hit_enemy(e, mult)
			_boom()
		else:
			owner_player.hit_enemy(first, mult)
	queue_free()


## Вспышка взрыва (визуально).
func _boom() -> void:
	var fx := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = aoe_radius
	s.height = aoe_radius * 0.6
	fx.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.45, 0.05, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx.material_override = m
	get_parent().add_child(fx)
	fx.global_position = Vector3(global_position.x, 0.2, global_position.z)
	var tw := fx.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(fx.queue_free)
