class_name PlayerDino
extends CharacterBody3D
## 玩家恐龙：第三人称操控（走/跑/跳/咬）+ 跟随摄像机
## 物理层 layer 2 (Player)，collision_mask = layer 1 (World) + layer 3 (AI)
## 信号通知 Main 处理血量变化、死亡、咬击命中

# --- 信号 ---
signal health_changed(current_hp: int, max_hp: int)
signal died
signal bite_hit(target: Node3D)

# --- 移动参数 ---
@export_group("Movement")
@export var walk_speed: float = 4.5
@export var run_speed: float = 8.0
@export var acceleration: float = 18.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 7.5

# --- 生命 ---
@export_group("Health")
@export var max_health: int = 10

# --- 咬击 ---
@export_group("Bite")
@export var bite_cooldown: float = 0.3
@export var bite_damage: int = 5
@export var bite_anim_duration: float = 0.3

# --- 摄像机 ---
@export_group("Camera")
@export var camera_yaw_speed: float = 2.2
@export var camera_pitch: float = -0.35
@export var camera_height_offset: float = 1.6
@export var camera_spring_length: float = 5.5

# --- 内部状态 ---
var current_health: int = 10
var is_dead: bool = false
var bite_cooldown_timer: float = 0.0
var is_biting: bool = false
var bite_anim_timer: float = 0.0
var camera_yaw: float = 0.0
var touch_move_input: Vector2 = Vector2.ZERO

# --- 节点引用 ---
@onready var dino_visual: Node3D = $DinoVisual
@onready var head_pivot: Node3D = $DinoVisual/HeadPivot
@onready var bite_area: Area3D = $BiteArea
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

const GRAVITY: float = 19.6


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	# SpringArm3D 设为 top_level，使其不继承玩家旋转
	spring_arm.top_level = true
	spring_arm.spring_length = camera_spring_length
	spring_arm.rotation = Vector3(camera_pitch, 0.0, 0.0)
	spring_arm.add_excluded_object(get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	# 仅处理未被 UI 消费的输入（键盘/鼠标点击空白处）
	if event.is_action_pressed("bite"):
		try_bite()
	elif event.is_action_pressed("jump"):
		try_jump()


func _physics_process(delta: float) -> void:
	if is_dead:
		# 死亡后仍维持摄像机位置
		_update_camera_position()
		return

	# 重力
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 输入：键盘方向 + 触屏摇杆叠加
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	input_dir += touch_move_input
	input_dir = input_dir.limit_length(1.0)

	# 摄像机相对方向计算移动
	var cam_basis: Basis = camera.global_basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()
	# 注意 Input.get_vector 的 y 正向是"后退"，因此前向分量 = -input.y
	var move_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x)
	if move_dir.length() > 0.01:
		move_dir = move_dir.normalized()

	# 速度（Shift 加速）
	var speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		speed = run_speed

	# 加速到目标速度
	var target_vel: Vector3 = move_dir * speed
	var accel: float = acceleration * delta
	velocity.x = move_toward(velocity.x, target_vel.x, accel)
	velocity.z = move_toward(velocity.z, target_vel.z, accel)

	# 朝向移动方向（平滑插值）
	if move_dir.length() > 0.1:
		var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)

	# 咬击冷却与动画计时
	if bite_cooldown_timer > 0.0:
		bite_cooldown_timer -= delta
	if is_biting:
		bite_anim_timer -= delta
		if bite_anim_timer <= 0.0:
			is_biting = false

	# 摄像机左右旋转（Q/E）
	var yaw_input: float = 0.0
	if Input.is_action_pressed("cam_left"):
		yaw_input += 1.0
	if Input.is_action_pressed("cam_right"):
		yaw_input -= 1.0
	camera_yaw += yaw_input * camera_yaw_speed * delta

	_update_camera_position()
	move_and_slide()


## 更新摄像机位置（始终跟随玩家）
func _update_camera_position() -> void:
	spring_arm.global_position = global_position + Vector3(0.0, camera_height_offset, 0.0)
	spring_arm.rotation = Vector3(camera_pitch, camera_yaw, 0.0)


## 触发咬击（外部按钮或键盘 J/鼠标左键调用）
func try_bite() -> void:
	if is_dead or bite_cooldown_timer > 0.0:
		return
	bite_cooldown_timer = bite_cooldown
	is_biting = true
	bite_anim_timer = bite_anim_duration
	# 咬击动画：头部下沉再回位
	var tween: Tween = create_tween()
	tween.tween_property(head_pivot, "rotation:x", -0.7, 0.08)
	tween.tween_property(head_pivot, "rotation:x", 0.0, 0.22)
	# 命中检测：遍历咬击范围内所有 AI 恐龙
	var bodies: Array[Node3D] = bite_area.get_overlapping_bodies()
	for body in bodies:
		bite_hit.emit(body)


## 触发跳跃
func try_jump() -> void:
	if is_dead:
		return
	if is_on_floor():
		velocity.y = jump_velocity


## 接收触屏摇杆输入
func set_move_input(vec: Vector2) -> void:
	touch_move_input = vec


## 受到伤害
func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	# 受击反馈：轻微缩放
	var tween: Tween = create_tween()
	tween.tween_property(dino_visual, "scale", Vector3(1.12, 1.12, 1.12), 0.05)
	tween.tween_property(dino_visual, "scale", Vector3.ONE, 0.12)
	if current_health <= 0:
		is_dead = true
		died.emit()
		# 死亡动画：缩小下沉
		var death_tween: Tween = create_tween()
		death_tween.tween_property(dino_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		death_tween.parallel().tween_property(self, "global_position:y", global_position.y - 0.4, 0.5)
