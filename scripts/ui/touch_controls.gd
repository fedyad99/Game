extends Control
## Сенсорное управление: левая половина экрана — виртуальный стик, правая — кнопка атаки.

const STICK_RADIUS := 90.0

var player: Node
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _attack_fingers := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if event is InputEventScreenTouch:
		var left: bool = event.position.x < get_viewport_rect().size.x * 0.5
		if event.pressed:
			if left and _stick_finger == -1:
				_stick_finger = event.index
				_stick_origin = event.position
				_stick_pos = event.position
			elif not left:
				_attack_fingers[event.index] = true
		else:
			if event.index == _stick_finger:
				_stick_finger = -1
				player.touch_move = Vector2.ZERO
			_attack_fingers.erase(event.index)
		player.touch_attack = not _attack_fingers.is_empty()
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		var off: Vector2 = (event.position - _stick_origin).limit_length(STICK_RADIUS)
		_stick_pos = _stick_origin + off
		player.touch_move = off / STICK_RADIUS
		queue_redraw()


func _draw() -> void:
	if _stick_finger != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.15))
		draw_circle(_stick_pos, 40, Color(1, 1, 1, 0.4))
