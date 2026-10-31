extends SceneTree
## Дымовой тест забега: бот идёт к ближайшему врагу и бьёт его, пока не умрёт или не убьёт босса.
## Запуск: godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd

var main: Node
var frames := 0
var picked := 0
var max_frames := 60 * 60 * 12   # 12 игровых минут


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frames += 1
	var p = main.player
	if p == null:
		print("RESULT main failed to start")
		return true
	var enemies := get_nodes_in_group("enemies")
	var best = null
	var bd := INF
	for e in enemies:
		var d: float = e.global_position.distance_to(p.global_position)
		# Бот не идёт к боссам, пока не наберёт нужный уровень
		var need := 0
		if e.kind == "miniboss":
			need = 5 if e.home.z > -60 else 9
		elif e.kind == "boss":
			need = 12
		if p.level < need:
			d += 1000.0
		if d < bd:
			bd = d
			best = e
	p.touch_attack = true
	var in_fight := false
	for e in enemies:
		if e.state == "chase":
			in_fight = true
	# Бот отдыхает, если ранен и никто не нападает
	if not in_fight and p.hp < p.stats.max_hp * 0.9:
		best = null
	if best and bd > 2.0:
		var goal: Vector3 = best.global_position
		# Проход через ворота между зонами (у бота нет навигации)
		for gate_z in [-62.0, -126.0]:
			if (goal.z < gate_z) != (p.global_position.z < gate_z):
				var gx: float = 0.0
				goal = Vector3(gx, 0, gate_z + (-3.0 if goal.z < gate_z else 3.0)) if abs(p.global_position.x) > 2.5 else Vector3(0, 0, goal.z)
				break
		var to: Vector3 = goal - p.global_position
		p.touch_move = Vector2(to.x, to.z).normalized()
	else:
		p.touch_move = Vector2.ZERO
	if main.card_panel.visible and not main.finished:
		var cards: Array = root.get_node("Cards").roll(p.player_class, p.skills)
		main._on_card_chosen(cards[0])
		picked += 1
	if frames % 3600 == 0:
		print("sec=%d level=%d hp=%.0f kills=%d gold=%d enemies=%d pos=%s" % [
			frames / 60, p.level, p.hp, main.kills, main.gold, enemies.size(), p.global_position.round()])
	if main.finished or frames > max_frames:
		var bosses := []
		for e in enemies:
			if e.is_boss:
				bosses.append(e.display_name)
		for e in enemies:
			if e.state == "chase":
				print("  chasing: ", e.kind, " hp=", int(e.hp), " dist=", snapped(e.global_position.distance_to(p.global_position), 0.1))
		print("RESULT frames=%d finished=%s dead=%s level=%d kills=%d gold=%d cards=%d hp=%.0f bosses_left=%s" % [
			frames, main.finished, p.dead, p.level, main.kills, main.gold, picked, p.hp, bosses])
		return true
	return false
