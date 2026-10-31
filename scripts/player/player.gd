extends CharacterBody3D
## Воин: ручное движение и удар мечом по одной цели (ближайший враг рядом).

const FloatingText := preload("res://scripts/ui/floating_text.gd")
const CharacterModel := preload("res://scripts/game/character_model.gd")
const KNIGHT := "res://assets/kaykit/adventurers/Knight.glb"

signal hp_changed(hp: float, max_hp: float)
signal xp_changed(xp: int, need: int, level: int)
signal leveled_up
signal died

var player_class := "warrior"
var stats := {
	"max_hp": 100.0, "damage": 30.0, "damage_mult": 1.0, "move_speed": 6.0,
	"move_speed_mult": 1.0, "attack_speed_mult": 1.0, "regen": 0.0,
	"damage_taken_mult": 1.0, "attack_range": 2.8,
	"crit_chance": 0.05, "lifesteal": 0.0,
}
var skills: Array[String] = []
var hp := 100.0
var level := 1
var xp := 0
var attack_cooldown := 0.0
var whirl_cooldown := 0.0
var facing := Vector3.FORWARD
var dead := false
var out_of_combat := 0.0   # секунд без урона; после 4 с идёт быстрое восстановление
var touch_move := Vector2.ZERO   # из виртуального стика
var touch_attack := false

var model: Node3D
var _whirl_fx: MeshInstance3D


func _ready() -> void:
	add_to_group("players")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	col.shape = cap
	col.position.y = 1.0
	add_child(col)
	model = CharacterModel.new()
	add_child(model)
	model.setup(KNIGHT, ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"])
	# Круг для навыка «Вихрь» (удар по области — только у навыка)
	_whirl_fx = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.05
	_whirl_fx.mesh = disc
	_whirl_fx.position.y = 0.15
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 0.6, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_whirl_fx.material_override = sm
	_whirl_fx.visible = false
	add_child(_whirl_fx)


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
	if v.length() > 0.1:
		model.play("Running_A", 0.8 + 0.4 * stats.move_speed_mult)
	else:
		model.play("Idle")

	out_of_combat += delta
	var regen: float = stats.regen + (stats.max_hp * 0.05 if out_of_combat > 4.0 else 0.0)
	hp = min(hp + regen * delta, stats.max_hp)
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
	var target := _find_target()
	if target:
		var to := target.global_position - global_position
		to.y = 0
		if to.length() > 0.01:
			facing = to.normalized()
			look_at(global_position + facing, Vector3.UP)
		_hit(target, 1.0)
	model.play_once("1H_Melee_Attack_Chop", min(0.5 / stats.attack_speed_mult, 0.6))


## Цель удара: ближайший враг в пределах дальности (с учётом его размера).
func _find_target() -> Node3D:
	var best := INF
	var found: Node3D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp <= 0:
			continue
		var d: float = global_position.distance_to(e.global_position) - 0.5 * e.scale.x
		if d <= stats.attack_range and d < best:
			best = d
			found = e
	return found


## Один удар по врагу: шанс крита (x2) и вампиризм.
func _hit(e: Node, mult: float) -> void:
	var crit: bool = randf() < stats.crit_chance
	var dmg: float = stats.damage * stats.damage_mult * mult * (2.0 if crit else 1.0)
	e.take_damage(dmg, crit, self)
	if stats.lifesteal > 0.0:
		heal(dmg * stats.lifesteal, false)


func heal(amount: float, show := true) -> void:
	if dead:
		return
	var before := hp
	hp = min(hp + amount, stats.max_hp)
	if show and hp - before >= 1.0:
		FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), "+%d" % int(hp - before), Color(0.3, 1, 0.4))
	hp_changed.emit(hp, stats.max_hp)


func whirlwind() -> void:
	whirl_cooldown = 4.0
	var radius: float = stats.attack_range * 1.3
	_whirl_fx.scale = Vector3(radius, 1, radius)
	_whirl_fx.visible = true
	get_tree().create_timer(0.2).timeout.connect(func(): _whirl_fx.visible = false)
	model.play_once("2H_Melee_Attack_Spin", 0.45)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= radius:
			_hit(e, 0.8)


func take_damage(amount: float) -> void:
	if dead:
		return
	out_of_combat = 0.0
	var dmg: float = amount * max(stats.damage_taken_mult, 0.2)
	hp -= dmg
	FloatingText.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), str(int(round(dmg))), Color(1, 0.3, 0.3))
	model.flash(Color(1, 0.3, 0.3))
	if hp <= 0:
		hp = 0
		dead = true
		model.play_once("Death_A", -1.0)
		model._locked_until = INF
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
