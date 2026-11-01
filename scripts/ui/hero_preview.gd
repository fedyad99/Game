extends SubViewportContainer
## 3D-превью героя: модель класса с экипировкой на подставке, медленно вращается.

const Classes := preload("res://scripts/player/classes.gd")
const CharacterModel := preload("res://scripts/game/character_model.gd")

var spin := 0.4
var _root: Node3D
var _model: Node3D
var _cam: Camera3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_root = Node3D.new()
	vp.add_child(_root)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.3, 5.4)
	_cam.rotation_degrees.x = -8
	_cam.fov = 40
	_root.add_child(_cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.3
	_root.add_child(light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2, 2.5, -2)
	rim.light_color = Color(1.0, 0.6, 0.3)
	rim.light_energy = 2.0
	rim.omni_range = 6.0
	_root.add_child(rim)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.65, 0.85)
	_root.add_child(env)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.25
	cyl.height = 0.25
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.32, 0.28, 0.36)
	base.material_override = bm
	base.position.y = -0.125
	_root.add_child(base)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.15
	tor.outer_radius = 1.3
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.95, 0.75, 0.3)
	rm.emission_enabled = true
	rm.emission = Color(0.9, 0.6, 0.2)
	ring.material_override = rm
	ring.scale = Vector3(1, 0.3, 1)
	_root.add_child(ring)


func show_hero(cls: String, lk: Dictionary, cheer := false) -> void:
	if _model:
		_model.queue_free()
	var info: Dictionary = Classes.CLASSES[cls]
	_model = CharacterModel.new()
	_root.add_child(_model)
	_model.setup(info.model, info.hide, lk.get("weapon", ""), lk.get("offhand", ""))
	_model.apply_look(lk)
	_model.rotation.y = PI
	_model.play("Idle")
	if cheer:
		_model.play_once("Cheer", 1.4)


## Повернуть героя лицом к камере (с небольшим разворотом).
func face(angle: float) -> void:
	if _model:
		_model.rotation.y = PI + angle


func set_distance(z: float, y := 1.3) -> void:
	_cam.position = Vector3(0, y, z)


func _process(delta: float) -> void:
	if _model and is_visible_in_tree():
		_model.rotation.y += delta * spin
