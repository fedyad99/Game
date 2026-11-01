extends SceneTree
const TalentTreeData := preload("res://scripts/meta/talent_tree.gd")
## Проверка босса: герой 12 уровня со случайными карточками у арены босса.
## Запуск: godot --headless --fixed-fps 60 --path . -s tests/boss_test.gd

var main: Node
var frames := 0


func _initialize() -> void:
	# Класс можно передать аргументом: ... -s tests/xxx.gd -- archer
	var args := OS.get_cmdline_user_args()
	root.get_node("Profile").autosave = false
	main = load("res://scenes/main.tscn").instantiate()
	main.forced_class = args[0] if args.size() > 0 else "warrior"
	if "geared" in args:
		# Средняя прокачка: эпическое оружие, хороший доспех и ~20 очков дерева
		main.forced_bonus = {"damage": 8.0, "max_hp": 38.0, "max_hp_pct": 0.12, "damage_mult": 0.2, "crit_chance": 0.08,
			"damage_taken_mult": -0.1, "lifesteal": 0.03, "attack_speed_mult": 0.08, "regen": 1.0}
	if args.size() > 1 and args[1] == "skills":
		for k in TalentTreeData.SKILLS:
			if TalentTreeData.SKILLS[k].cls == main.forced_class:
				main.extra_skills.append(k)
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var p = main.player
	if frames == 2:
		for i in 11:
			p.apply_card(root.get_node("Cards").roll(p.player_class, p.skills)[0])
		p.level = 12
		p.hp = p.stats.max_hp
		p.global_position = Vector3(0, 0.1, -150)
	var boss = null
	for e in get_nodes_in_group("enemies"):
		if e.kind == "boss":
			boss = e
	p.touch_attack = true
	if boss and boss._casting > 0.0:
		# Уворот от удара по площади, как сделал бы игрок
		var away: Vector3 = p.global_position - boss.global_position
		p.touch_move = Vector2(away.x, away.z).normalized()
	elif boss and p.global_position.distance_to(boss.global_position) > 3.0:
		var to: Vector3 = boss.global_position - p.global_position
		p.touch_move = Vector2(to.x, to.z).normalized()
	else:
		p.touch_move = Vector2.ZERO
	if main.finished or frames > 60 * 180:
		print("RESULT[%s] " % main.player.player_class, " boss victory=%s dead=%s time=%.0fs hp=%.0f/%.0f boss_hp=%s stats=%s skills=%s" % [
			main.finished and not p.dead, p.dead, frames / 60.0, p.hp, p.stats.max_hp,
			(int(boss.hp) if boss else 0), p.stats, p.skills])
		return true
	return false
