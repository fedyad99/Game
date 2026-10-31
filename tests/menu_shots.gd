extends SceneTree
## Скриншоты меню (лагеря): xvfb-run godot --rendering-method gl_compatibility --path . -s tests/menu_shots.gd -- <папка>
var menu: Node
var frames := 0
var out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var prof = root.get_node("Profile")
	prof.autosave = false
	# Демо-профиль: немного добра, чтобы было что показать
	prof.gold = 340
	prof.chests = 3
	prof.talent_points = 4
	prof.talents = {"vitality": 2, "might": 1, "second_wind": 1}
	prof.owned = ["w_greatsword", "w_battle_axe", "w_knight_sword", "w_executioner", "ar_guard", "am_dragon", "ar_leather",
		"ar_chain", "am_fang", "am_bloodstone", "m_staff", "a_heavy"]
	prof.equipped = {"weapon_warrior": "w_greatsword", "armor": "ar_guard", "amulet": "am_dragon"}
	prof.selected_class = "warrior"
	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)


func _shot(name_: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])


func _process(_d: float) -> bool:
	frames += 1
	match frames:
		50:
			menu._select_item("w_executioner")
		52:
			var ic: Control = menu._bag_grid.get_child(1)
			root.warp_mouse(ic.get_global_rect().get_center())
			menu._on_icon_hover(ic, true)
		60: _shot("menu_hero")
		61: menu._show_page("talents")
		70: _shot("menu_talents")
		71:
			menu._show_page("chests")
			menu._open_chest()
		100: _shot("menu_chests")
		101:
			menu._lib_sel = "a_siege"
			menu._show_page("library")
		110: _shot("menu_library")
		111:
			menu._show_page("hero")
			menu._select_class("mage")
		170: _shot("menu_mage")
	return frames > 170
