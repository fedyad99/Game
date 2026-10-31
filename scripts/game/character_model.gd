extends Node3D
## 3D-модель персонажа (KayKit, CC0) с анимациями.
## Скрывает лишние предметы, вешает оружие в руку и проигрывает анимации по имени.

const LOOPED := ["Idle", "Idle_Combat", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_D_Skeletons",
	"2H_Melee_Idle", "Spellcasting", "Unarmed_Idle"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _current := ""
var _locked_until := 0.0   # время, до которого играет разовая анимация (атака, удар)
var _tint_mats: Array[StandardMaterial3D] = []


## path — модель .glb, hide_meshes — имена мешей, которые надо спрятать,
## weapon — путь к модели оружия (или ""), height — желаемый рост.
func setup(path: String, hide_meshes: Array, weapon := "", offhand := "", height := 2.0) -> void:
	var inst: Node3D = load(path).instantiate()
	add_child(inst)
	inst.rotation.y = PI   # модели KayKit смотрят по +Z, а наш «вперёд» — это -Z
	scale = Vector3.ONE * (height / 2.2)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name in hide_meshes:
			mi.visible = false
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	if skels.size() > 0:
		skeleton = skels[0]
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		anim = aps[0]
		for n in LOOPED:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if weapon != "":
		_attach(weapon, "handslot.r")
	if offhand != "":
		_attach(offhand, "handslot.l")
	play("Idle")


func _attach(path: String, bone: String) -> void:
	if skeleton == null or skeleton.find_bone(bone) == -1:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	ba.add_child(load(path).instantiate())


## Зацикленная анимация (стоять, бежать). Не перебивает разовую.
func play(name_: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	if Time.get_ticks_msec() / 1000.0 < _locked_until:
		return
	if _current != name_:
		_current = name_
		anim.play(name_, 0.15, speed)
	else:
		anim.speed_scale = speed


## Разовая анимация (атака, получение урона, смерть). duration — сколько секунд она должна длиться.
func play_once(name_: String, duration := -1.0, lock := true) -> void:
	if anim == null or not anim.has_animation(name_):
		return
	var length := anim.get_animation(name_).length
	var spd := 1.0 if duration <= 0.0 else length / duration
	_current = name_
	anim.stop()
	anim.play(name_, 0.08, spd)
	if lock:
		_locked_until = Time.get_ticks_msec() / 1000.0 + length / spd * 0.95


## Вспышка цветом при получении урона.
func flash(color := Color(1, 1, 1)) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi.visible:
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(color, 0.6)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_overlay = m
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self):
			for mi in find_children("*", "MeshInstance3D", true, false):
				mi.material_overlay = null)


## Внешний вид от экипировки: оружие и вторая рука уже переданы в setup,
## здесь — цвет плаща (доспех) и светящийся круг под ногами (амулет).
func apply_look(lk: Dictionary) -> void:
	if lk.has("cape"):
		for mi in find_children("*Cape*", "MeshInstance3D", true, false):
			var src: Material = mi.get_active_material(0)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_color = lk.cape
				mi.material_override = m
	if lk.has("aura"):
		var c: Color = lk.aura
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.75
		tor.outer_radius = 0.95
		ring.mesh = tor
		ring.position.y = 0.08
		ring.scale = Vector3(1, 0.15, 1) / scale
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c, 0.7)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 2.5
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		ring.name = "Aura"
		add_child(ring)
		var light := OmniLight3D.new()
		light.light_color = c
		light.light_energy = 0.8
		light.omni_range = 2.5
		light.position.y = 0.6
		add_child(light)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(m, "albedo_color:a", 0.3, 0.8)
		tw.tween_property(m, "albedo_color:a", 0.7, 0.8)


## Окраска модели (для боссов: отличить от обычных врагов).
func tint(color: Color) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var src: Material = mi.get_active_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = src.duplicate()
			m.albedo_color = color
			mi.material_override = m
