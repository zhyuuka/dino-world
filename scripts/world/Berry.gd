class_name Berry
extends Area3D
## 果子：浮动 + 旋转动画，玩家/食草 AI 接近自动被吃
## 物理层 layer 4 (Trigger)，collision_mask = layer 2 (Player) + layer 3 (AI)
## 由 FoodSpawner 统一生成与回收

const FLOAT_SPEED: float = 3.0
const ROTATE_SPEED: float = 2.0
const FLOAT_AMPLITUDE: float = 0.12
const BASE_HEIGHT: float = 0.55

@onready var visual: CSGSphere3D = $Visual


func _process(delta: float) -> void:
	# 上下浮动
	visual.position.y = BASE_HEIGHT + sin(Time.get_ticks_msec() * 0.001 * FLOAT_SPEED) * FLOAT_AMPLITUDE
	# 持续旋转
	visual.rotation.y += ROTATE_SPEED * delta
