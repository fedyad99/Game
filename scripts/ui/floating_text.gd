extends Label3D
## Всплывающие цифры урона/лечения над головой.


static func spawn(parent: Node, pos: Vector3, text_value: String, color: Color, big := false) -> void:
	var l := new()
	l.text = text_value
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 10
	l.font_size = 72 if big else 48
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.2, 0.2))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", l.global_position + Vector3(0, 1.6, 0), 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
