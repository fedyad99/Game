extends SceneTree
## Дымовой тест забега: godot --headless --path . -s tests/smoke_test.gd

var main: Node
var frames := 0
var picked := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frames += 1
	var p = main.player
	if p == null:
		print("RESULT main failed to start")
		return true
	p.touch_attack = true
	p.touch_move = Vector2.ZERO  # бот стоит и бьёт (проверка боя, а не уворотов)
	if main.card_panel.visible and not main.finished:
		var cards: Array = root.get_node("Cards").roll(p.player_class)
		main._on_card_chosen(cards[0])
		picked += 1
	if frames == 1800:
		main.run_time = main.MINIBOSS_TIME - 1
	if frames == 3600:
		main.run_time = main.BOSS_TIME - 1
	if main.finished or frames > 9000:
		var enemies := get_nodes_in_group("enemies")
		var kinds := {}
		for e in enemies:
			kinds[e.kind] = true
		print("RESULT frames=%d finished=%s dead=%s level=%d kills=%d cards=%d hp=%.0f enemies=%d kinds=%s" % [
			frames, main.finished, p.dead, p.level, main.kills, picked, p.hp, enemies.size(), kinds.keys()])
		return true
	return false
