extends SceneTree
## Скриншоты меню (лагеря): xvfb-run godot --rendering-method gl_compatibility --path . -s tests/menu_shots.gd -- <папка>
var menu: Node
var frames := 0
var out := "user://"
var prof


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	prof = root.get_node("Profile")
	prof.autosave = false
	root.get_node("Sfx").sfx_on = false
	root.get_node("Sfx").music_on = false
	# Демо-профиль: немного добра, чтобы было что показать
	prof.gold = 340
	prof.chests = 3
	prof.class_chosen = false
	prof.points = {"warrior": 5}
	prof.trees = {"warrior": ["warrior_start", "warrior_a1", "warrior_a2", "warrior_a3", "warrior_i1", "warrior_i2", "ring0_1"]}
	prof.owned = ["w_greatsword", "w_battle_axe", "w_knight_sword", "w_executioner", "ar_guard", "am_dragon", "ar_leather",
		"ar_chain", "am_fang", "am_bloodstone", "m_staff", "a_heavy", "rg_vampire", "rg_copper", "rg_crown"]
	prof.equipped = {"weapon_warrior": "w_greatsword", "armor": "ar_guard", "amulet": "am_dragon", "ring": "rg_crown"}
	prof.selected_class = "warrior"
	menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)


func _shot(name_: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name_])


func _process(_d: float) -> bool:
	frames += 1
	match frames:
		70: _shot("menu_class_select")
		71: menu._choose_first_class("warrior")
		100:
			menu._select_item("w_executioner")
		102:
			var ic: Control = menu._bag_grid.get_child(1)
			root.warp_mouse(ic.get_global_rect().get_center())
			menu._on_icon_hover(ic, true)
		110: _shot("menu_hero")
		111: menu._show_page("talents")
		125:
			menu._on_tree_hover("warrior_a4", true)
		135: _shot("menu_talents")
		136: menu._show_page("chests")
		150:
			menu._open_chest()
		185: _shot("menu_chest_opening")
		250: _shot("menu_chests")
		251:
			menu._lib_sel = "rg_crown"
			menu._show_page("library")
		270: _shot("menu_library")
	return frames > 270
