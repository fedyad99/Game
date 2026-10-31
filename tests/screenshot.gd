extends SceneTree
## Скриншоты для проверки картинки:
## xvfb-run godot --rendering-method gl_compatibility --path . -s tests/screenshot.gd -- <папка>
var main: Node
var frames := 0
var out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name_: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])


func _process(_d: float) -> bool:
	frames += 1
	var p = main.player
	match frames:
		5:
			p.global_position = Vector3(6, 0.1, -19)
		60:
			_shot("game")
		61:
			p.add_xp(6)   # новый уровень → выбор карточек
		100:
			_shot("cards")
		101:
			var cards = root.get_node("Cards")
			for id in ["dmg_up", "dmg_up", "whirlwind", "crit", "lifesteal", "hp_up", "armor"]:
				p.apply_card(cards.by_id(id))
			main.card_panel.visible = false
			main.pending_levelups = 0
			paused = false
			main.deck_panel.show_deck(p.cards_taken, p)
		130:
			_shot("deck")
		131:
			main.deck_panel.hide_deck()
			p.global_position = Vector3(0, 0.1, -48)
		200:
			_shot("boss")
	return frames > 200
