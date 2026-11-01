extends SceneTree
const TalentTreeData := preload("res://scripts/meta/talent_tree.gd")
## Скриншоты для проверки картинки:
## xvfb-run godot --rendering-method gl_compatibility --path . -s tests/screenshot.gd -- <папка>
var main: Node
var frames := 0
var out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	root.get_node("Profile").autosave = false
	main = load("res://scenes/main.tscn").instantiate()
	main.forced_class = args[1] if args.size() > 1 else "warrior"
	if args.size() > 2 and args[2] == "skills":
		for k in TalentTreeData.SKILLS:
			if TalentTreeData.SKILLS[k].cls == main.forced_class:
				main.extra_skills.append(k)
	root.add_child(main)
	manual = "manual" in args


func _shot(name_: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])


var manual := false


func _process(_d: float) -> bool:
	if manual and main.player:
		main.player.autocast = false
		main.hud.autocast = false
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
