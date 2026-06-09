class_name VirtualJoystick
extends Control
## Minimal on-screen joystick for touch devices. Works with mouse too
## (the project enables emulate_touch_from_mouse).

const KNOB_RADIUS := 26.0

var output: Vector2 = Vector2.ZERO

var _active_pointer: int = -1


func _radius() -> float:
	return minf(size.x, size.y) * 0.5 - KNOB_RADIUS


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_pointer == -1:
			_active_pointer = event.index
			_update_output(event.position)
		elif not event.pressed and event.index == _active_pointer:
			_release()
	elif event is InputEventScreenDrag and event.index == _active_pointer:
		_update_output(event.position)


func _update_output(pos: Vector2) -> void:
	output = ((pos - size * 0.5) / _radius()).limit_length(1.0)
	queue_redraw()


func _release() -> void:
	_active_pointer = -1
	output = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := _radius()
	draw_circle(center, radius + KNOB_RADIUS, Color(1, 1, 1, 0.06))
	draw_arc(center, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
	draw_circle(center + output * radius, KNOB_RADIUS, Color(1, 1, 1, 0.3))
