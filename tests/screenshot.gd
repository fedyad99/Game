extends SceneTree
## Скриншоты для проверки картинки: xvfb-run godot --rendering-method gl_compatibility --path . -s tests/screenshot.gd -- out_dir
var main: Node
var frames := 0
var out := "user://"
const SHOTS := {60: Vector3(0, 0.1, -14), 150: Vector3(-6, 0.1, -50), 240: Vector3(0, 0.1, -150), 330: Vector3(0, 0.1, -60)}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frames += 1
	for f in SHOTS:
		if frames == f - 40:
			main.player.global_position = SHOTS[f]
		if frames == f:
			root.get_viewport().get_texture().get_image().save_png("%s/shot_%d.png" % [out, f])
	if frames == 100:
		main.player.touch_attack = true
	return frames > 340
