class_name VirtualJoystick
extends Control
## 虚拟摇杆：触摸/鼠标拖动输出归一化向量（x 右正 / y 上负）
## 屏幕坐标 y 向下为正，输出 y 上负以匹配 Input.get_vector 行为
## 死区内输出归零，避免漂移

signal input_changed(vec: Vector2)

@export var max_radius: float = 80.0
@export var dead_zone: float = 0.15

var touch_index: int = -1
var stick_offset: Vector2 = Vector2.ZERO


func _draw() -> void:
	var center: Vector2 = size / 2.0
	# 底盘（半透明圆）
	draw_circle(center, max_radius, Color(0.15, 0.15, 0.15, 0.45))
	draw_arc(center, max_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
	# 摇杆手柄
	draw_circle(center + stick_offset, max_radius * 0.45, Color(1, 1, 1, 0.85))


func _gui_input(event: InputEvent) -> void:
	var center: Vector2 = size / 2.0
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event as InputEventScreenTouch
		if t.pressed and touch_index == -1:
			touch_index = t.index
			stick_offset = t.position - center
			if stick_offset.length() > max_radius:
				stick_offset = stick_offset.normalized() * max_radius
			_emit_input()
			queue_redraw()
			accept_event()
		elif not t.pressed and t.index == touch_index:
			touch_index = -1
			stick_offset = Vector2.ZERO
			_emit_input()
			queue_redraw()
			accept_event()
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event as InputEventScreenDrag
		if d.index == touch_index:
			stick_offset = d.position - center
			if stick_offset.length() > max_radius:
				stick_offset = stick_offset.normalized() * max_radius
			_emit_input()
			queue_redraw()
			accept_event()


## 计算并发出归一化输入向量
func _emit_input() -> void:
	var output: Vector2 = stick_offset / max_radius
	if output.length() < dead_zone:
		output = Vector2.ZERO
	elif output.length() > 1.0:
		output = output.normalized()
	input_changed.emit(output)
