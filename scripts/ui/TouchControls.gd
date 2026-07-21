class_name TouchControls
extends CanvasLayer
## 触屏操控层：左下虚拟摇杆 + 右下咬击/跳跃按钮
## 信号桥接到玩家：move_input_changed / bite_pressed / jump_pressed

signal move_input_changed(vec: Vector2)
signal bite_pressed
signal jump_pressed

@onready var joystick: VirtualJoystick = $Control/Joystick
@onready var bite_button: Button = $Control/BiteButton
@onready var jump_button: Button = $Control/JumpButton


func _ready() -> void:
	joystick.input_changed.connect(_on_joystick_input)
	bite_button.pressed.connect(_on_bite_pressed)
	jump_button.pressed.connect(_on_jump_pressed)


func _on_joystick_input(vec: Vector2) -> void:
	move_input_changed.emit(vec)


func _on_bite_pressed() -> void:
	bite_pressed.emit()


func _on_jump_pressed() -> void:
	jump_pressed.emit()
