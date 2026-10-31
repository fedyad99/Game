extends RefCounted
## Строит 3D-мир карты из данных (forest_map.gd) и моделей KayKit Halloween Bits (CC0).

const H := "res://assets/kaykit/halloween/"
const TREES := ["tree_pine_orange_large", "tree_dead_large", "tree_pine_yellow_large", "tree_dead_medium"]
const CAMP_DECOR := ["gravestone", "grave_A", "grave_B", "gravemarker_A", "bone_A", "bone_B", "skull",
	"pumpkin_orange", "pumpkin_yellow_small", "lantern_standing", "ribcage", "candle_triple"]
const FIELD_DECOR := ["pumpkin_orange_small", "pumpkin_yellow", "bone_C", "gravemarker_B", "post_skull",
	"tree_pine_orange_small", "tree_dead_small", "candle_melted"]

var root: Node3D
var map
var _cache := {}


func _init(root_node: Node3D, map_data) -> void:
	root = root_node
	map = map_data


func build() -> void:
	_environment()
	for z in map.ZONES:
		_box(z[0], z[1], z[2], true)
	for w in map.WALLS:
		_collider_box(w[0], w[1])
		_fence_line(w[0], w[1])
	_gates()
	for r in map.ROCKS:
		_tree(r)
	_decorate()


func _environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.13, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.58, 0.72)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.3, 0.25, 0.42)
	e.fog_density = 0.008
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)


func _model(name_: String) -> PackedScene:
	if not _cache.has(name_):
		_cache[name_] = load(H + name_ + ".gltf")
	return _cache[name_]


func prop(name_: String, pos: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	var n: Node3D = _model(name_).instantiate()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	root.add_child(n)
	return n


func _box(pos: Vector3, size: Vector3, color: Color, collide: bool) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		body.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mesh.material_override = m
	body.add_child(mesh)
	root.add_child(body)


func _collider_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	root.add_child(body)


## Забор вдоль стены: секции по 4 метра и столбы между ними.
func _fence_line(center: Vector3, size: Vector3) -> void:
	var along_x := size.x > size.z
	var length: float = size.x if along_x else size.z
	var count := int(round(length / 4.0))
	var start := -length / 2.0 + 2.0
	for i in count:
		var off := start + i * 4.0
		var p := Vector3(center.x + (off if along_x else 0.0), 0, center.z + (0.0 if along_x else off))
		var broken := (i * 7 + int(center.z)) % 9 == 0
		prop("fence_broken" if broken else "fence", p, 0.0 if along_x else PI / 2)
		var pp := p + (Vector3(-2, 0, 0) if along_x else Vector3(0, 0, -2))
		prop("fence_pillar", pp)


## Арки над проходами между зонами.
func _gates() -> void:
	for z in [-62.0, -126.0]:
		prop("arch", Vector3(0, 0, z), 0.0, 1.9)
		prop("pillar", Vector3(-4.3, 0, z))
		prop("pillar", Vector3(4.3, 0, z))
		prop("lantern_standing", Vector3(-5.5, 0, z + 1.5))
		prop("lantern_standing", Vector3(5.5, 0, z + 1.5))


func _tree(pos: Vector3) -> void:
	var idx := int(abs(pos.x * 3 + pos.z)) % TREES.size()
	prop(TREES[idx], pos, pos.x * 0.37, 0.75 + 0.1 * (idx % 2))
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, 1.5, 0)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.9
	cyl.height = 3.0
	col.shape = cyl
	body.add_child(col)
	root.add_child(body)


## Декорации без столкновений: могилы и кости у лагерей, тыквы и мелочь по полю, склеп у босса.
func _decorate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # фиксированное зерно: карта всегда одинаковая
	for camp in map.CAMPS:
		var c: Vector3 = camp[0]
		for i in 4:
			var a := rng.randf() * TAU
			var d := rng.randf_range(4.0, 6.5)
			prop(CAMP_DECOR[rng.randi() % CAMP_DECOR.size()], Vector3(c.x + cos(a) * d, 0, c.z + sin(a) * d), rng.randf() * TAU)
	for i in 70:
		var p := Vector3(rng.randf_range(-21, 21), 0, rng.randf_range(-185, 4))
		if abs(p.z + 62) < 3 or abs(p.z + 126) < 3:
			continue
		prop(FIELD_DECOR[rng.randi() % FIELD_DECOR.size()], p, rng.randf() * TAU)
	# Арена босса
	prop("crypt", Vector3(0, 0, -184), 0.0, 1.2)
	for x in [-8.0, 8.0]:
		prop("shrine_candles", Vector3(x, 0, -178), 0.0)
		prop("post_lantern", Vector3(x * 1.6, 0, -140))
		prop("post_lantern", Vector3(x * 1.6, 0, -165))
	for i in 10:
		var a := TAU * i / 10.0
		prop("candle_triple", Vector3(cos(a) * 9.0, 0, -165 + sin(a) * 9.0))
	# Старт
	prop("shrine", Vector3(0, 0, 5), PI)
	prop("lantern_standing", Vector3(-3, 0, 3))
	prop("lantern_standing", Vector3(3, 0, 3))
