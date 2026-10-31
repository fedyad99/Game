extends Node3D
## Полоска здоровья над врагом. Всегда повёрнута к камере.

var width := 1.4
var height := 0.16
var _fill: MeshInstance3D


func setup(fill_color: Color, w := 1.4) -> void:
	width = w
	var bg := _quad(Color(0, 0, 0, 0.7), Vector2(width + 0.06, height + 0.06), 0)
	add_child(bg)
	_fill = _quad(fill_color, Vector2(width, height), 1)
	add_child(_fill)
	visible = false


func _quad(c: Color, size: Vector2, prio: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 5 + prio
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func set_ratio(r: float) -> void:
	r = clamp(r, 0.0, 1.0)
	visible = r < 1.0 and r > 0.0
	_fill.scale.x = max(r, 0.001)
	_fill.position.x = -(1.0 - r) * width * 0.5


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and visible:
		global_basis = cam.global_basis.orthonormalized()
