extends SceneTree
## Рисует иконки оружия из 3D-моделей в assets/icons/items/<id>.png.
## Запуск (нужен экран, например xvfb-run):
##   godot --rendering-method gl_compatibility --path . -s tests/render_icons.gd
## Доспехи и амулеты рисуются кодом (scripts/ui/item_icon.gd), им картинка не нужна.

const Items := preload("res://scripts/meta/items.gd")
const SIZE := 256
const OUT := "res://assets/icons/items/"

var _vp: SubViewport
var _holder: Node3D
var _queue: Array = []
var _wait := 0
var _current := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2
	cam.position = Vector3(0, 0, 5)
	_vp.add_child(cam)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, 30, 0)
	l.light_energy = 1.4
	_vp.add_child(l)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.9
	_vp.add_child(env)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	for it in Items.ITEMS:
		if it.slot == "weapon":
			_queue.append(it)


func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := _vp.get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path(OUT + _current + ".png"))
			print("icon ", _current)
		return false
	if _queue.is_empty():
		return true
	for c in _holder.get_children():
		c.free()
	var it: Dictionary = _queue.pop_front()
	_current = it.id
	var main := _place(it.look.weapon, 1.0)
	main.rotation_degrees.z = -40.0
	if it.look.has("offhand"):
		var off := _place(it.look.offhand, 0.55)
		off.position = Vector3(-0.55, -0.5, 0.6)
		off.rotation_degrees = Vector3(0, -25, 10)
		main.position.x = 0.15
	_fit(main, 1.9 if not it.look.has("offhand") else 1.7)
	_wait = 4
	return false


## Модель в обёртке, центрированная по своему объёму.
func _place(path: String, rel: float) -> Node3D:
	var pivot := Node3D.new()
	_holder.add_child(pivot)
	var inst: Node3D = load(path).instantiate()
	pivot.add_child(inst)
	var box := _aabb(inst)
	var longest: float = max(box.size.x, max(box.size.y, box.size.z))
	var s: float = rel / max(longest, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = -box.get_center() * s
	# Длинной стороной — вверх (лезвие/древко вертикально перед поворотом)
	if box.size.x > box.size.y and box.size.x >= box.size.z:
		pivot.set_meta("flat", true)
		inst.rotate_z(PI / 2)
		inst.position = inst.position.rotated(Vector3.FORWARD, -PI / 2)
	elif box.size.z > box.size.y:
		inst.rotate_x(PI / 2)
		inst.position = inst.position.rotated(Vector3.RIGHT, PI / 2)
	return pivot


func _fit(main: Node3D, target: float) -> void:
	main.scale = Vector3.ONE * target


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = Transform3D.IDENTITY
		var p: Node = mi
		while p != n and p != null:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b: AABB = t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
