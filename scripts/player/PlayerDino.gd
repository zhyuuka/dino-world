class_name PlayerDino
extends CharacterBody3D
## 玩家恐龙：第三人称操控（走/跑/跳/咬）+ 跟随摄像机 + 饥饿系统 + 5 段进化
## 物理层 layer 2 (Player)，collision_mask = layer 1 (World) + layer 3 (AI)
## 信号通知 Main 处理血量/饥饿/进化/死亡/咬击
## 死亡后通过静态变量 saved_evolution_level 跨场景保留进化等级

# --- 信号 ---
signal health_changed(current_hp: int, max_hp: int)
signal hunger_changed(current_hunger: int, max_hunger: int)
signal died
signal bite_hit(target: Node3D)
signal evolved(level: int, level_name: String)
signal food_eaten(count: int, required: int)

# --- 进化系统 ---
# 5 段进化名称：幼龙 / 少年 / 亚成体 / 成体 / 霸主
const EVOLUTION_NAMES: Array[String] = ["幼龙", "少年", "亚成体", "成体", "霸主"]
const MAX_EVOLUTION: int = 4  # 索引最大值（霸主）
const FOOD_PER_EVOLUTION: int = 5
const EVOLVE_GLOW_DURATION: float = 1.0
const EVOLVE_SCALE_FACTOR: float = 1.15  # 每级体型倍率
const EVOLVE_HP_BONUS: int = 20           # 每级血量上限增量
const EVOLVE_HUNGER_BONUS: int = 10       # 每级饥饿上限增量
const EVOLVE_BITE_BONUS: int = 2          # 每级咬击伤害增量
const EVOLVE_SPEED_MULT: float = 0.05     # 每级速度增量

# 静态变量：跨场景保留进化等级（玩家死亡重开后恢复）
static var saved_evolution_level: int = 0

# --- 移动参数（基础值，会被进化等级修改） ---
@export_group("Movement")
@export var base_walk_speed: float = 4.5
@export var base_run_speed: float = 8.0
@export var acceleration: float = 18.0
@export var rotation_speed: float = 12.0
@export var jump_velocity: float = 7.5

# --- 生命 ---
@export_group("Health")
@export var base_max_health: int = 10

# --- 饥饿 ---
@export_group("Hunger")
@export var base_max_hunger: int = 100
@export var hunger_decay_interval: float = 60.0  # 每 60 秒消耗 1 点
@export var starvation_interval: float = 5.0    # 饥饿为 0 时每 5 秒
@export var starvation_damage: int = 5           # 掉 5 血

# --- 咬击 ---
@export_group("Bite")
@export var bite_cooldown: float = 0.3
@export var base_bite_damage: int = 5
@export var bite_anim_duration: float = 0.3

# --- 摄像机 ---
@export_group("Camera")
@export var camera_yaw_speed: float = 2.2
@export var camera_pitch: float = -0.35
@export var camera_height_offset: float = 1.6
@export var camera_spring_length: float = 5.5

# --- 内部状态 ---
var current_health: int = 10
var max_health: int = 10
var current_hunger: int = 100
var max_hunger: int = 100
var evolution_level: int = 0
var food_eaten_count: int = 0
var is_dead: bool = false
var bite_cooldown_timer: float = 0.0
var is_biting: bool = false
var bite_anim_timer: float = 0.0
var camera_yaw: float = 0.0
var touch_move_input: Vector2 = Vector2.ZERO
var hunger_timer: float = 0.0
var starvation_timer: float = 0.0

# 当前实际移动速度（受进化等级影响）
var walk_speed: float = 4.5
var run_speed: float = 8.0
var bite_damage: int = 5
# 视觉缩放基准（受进化等级影响，受击反馈基于此）
var visual_base_scale: Vector3 = Vector3.ONE

# --- 节点引用 ---
@onready var dino_visual: Node3D = $DinoVisual
@onready var head_pivot: Node3D = $DinoVisual/HeadPivot
@onready var bite_area: Area3D = $BiteArea
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

# 主材质（用于进化发光特效）
var body_material: StandardMaterial3D = null

const GRAVITY: float = 19.6
const BODY_PART_NAMES: Array[String] = ["Body", "Head", "Tail"]


func _ready() -> void:
	# 从静态变量恢复进化等级，重置食物计数
	evolution_level = saved_evolution_level
	food_eaten_count = 0
	# 准备统一主材质（duplicate 后应用到所有 CSG）
	_prepare_material()
	# 应用进化等级影响的所有属性
	_apply_evolution_stats()
	current_health = max_health
	current_hunger = max_hunger
	health_changed.emit(current_health, max_health)
	hunger_changed.emit(current_hunger, max_hunger)
	food_eaten.emit(food_eaten_count, FOOD_PER_EVOLUTION)
	# SpringArm3D 设为 top_level，使其不继承玩家旋转
	spring_arm.top_level = true
	spring_arm.spring_length = camera_spring_length
	spring_arm.rotation = Vector3(camera_pitch, 0.0, 0.0)
	spring_arm.add_excluded_object(get_rid())


## 准备统一主材质：duplicate 原 body/dark 材质并重新应用到所有 CSG
## 这样后续可通过修改 body_material 控制发光等效果
func _prepare_material() -> void:
	var body_mat: StandardMaterial3D = null
	var dark_mat: StandardMaterial3D = null
	for csg in dino_visual.find_children("*", "CSGBox3D", true, true):
		if not (csg.material is StandardMaterial3D):
			continue
		var orig: StandardMaterial3D = csg.material as StandardMaterial3D
		if csg.name in BODY_PART_NAMES:
			if body_mat == null:
				body_mat = orig.duplicate() as StandardMaterial3D
				body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			csg.material = body_mat
		else:
			if dark_mat == null:
				dark_mat = orig.duplicate() as StandardMaterial3D
				dark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			csg.material = dark_mat
	body_material = body_mat


## 根据当前进化等级重算属性：体型/血量/饥饿/咬击/速度
func _apply_evolution_stats() -> void:
	var scale_factor: float = pow(EVOLVE_SCALE_FACTOR, evolution_level)
	visual_base_scale = Vector3(scale_factor, scale_factor, scale_factor)
	dino_visual.scale = visual_base_scale
	max_health = base_max_health + evolution_level * EVOLVE_HP_BONUS
	max_hunger = base_max_hunger + evolution_level * EVOLVE_HUNGER_BONUS
	bite_damage = base_bite_damage + evolution_level * EVOLVE_BITE_BONUS
	var speed_mult: float = 1.0 + EVOLVE_SPEED_MULT * float(evolution_level)
	walk_speed = base_walk_speed * speed_mult
	run_speed = base_run_speed * speed_mult


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event.is_action_pressed("bite"):
		try_bite()
	elif event.is_action_pressed("jump"):
		try_jump()


func _physics_process(delta: float) -> void:
	if is_dead:
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
	var move_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x)
	if move_dir.length() > 0.01:
		move_dir = move_dir.normalized()

	# 速度（Shift 加速）
	var speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		speed = run_speed

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

	# 饥饿系统更新
	_update_hunger(delta)

	move_and_slide()


## 饥饿系统：每 60 秒消耗 1 点；饥饿为 0 时每 5 秒掉 5 血
func _update_hunger(delta: float) -> void:
	hunger_timer += delta
	if hunger_timer >= hunger_decay_interval:
		hunger_timer -= hunger_decay_interval
		current_hunger = maxi(0, current_hunger - 1)
		hunger_changed.emit(current_hunger, max_hunger)
	# 饥饿为 0 时持续掉血
	if current_hunger <= 0:
		starvation_timer += delta
		if starvation_timer >= starvation_interval:
			starvation_timer -= starvation_interval
			take_damage(starvation_damage)


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
	# 命中检测：遍历咬击范围内所有物体（AI 恐龙 / 尸体）
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
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	# 受击反馈：基于当前进化体型缩放
	var tween: Tween = create_tween()
	tween.tween_property(dino_visual, "scale", visual_base_scale * 1.12, 0.05)
	tween.tween_property(dino_visual, "scale", visual_base_scale, 0.12)
	if current_health <= 0:
		_die()


## 死亡：保留进化等级到静态变量，发出信号
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# 进化等级已通过 saved_evolution_level 保留，重开时恢复
	died.emit()
	# 死亡动画：缩小下沉
	var death_tween: Tween = create_tween()
	death_tween.tween_property(dino_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	death_tween.parallel().tween_property(self, "global_position:y", global_position.y - 0.4, 0.5)


## 加饥饿值
func add_hunger(amount: int) -> void:
	current_hunger = clampi(current_hunger + amount, 0, max_hunger)
	hunger_changed.emit(current_hunger, max_hunger)


## 加血量
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = mini(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


## 吃食物（统一入口）：增加饥饿、血量、进化计数
## hunger_amount: 饥饿回复量 / heal_amount: 血量回复量
func eat_food(hunger_amount: int, heal_amount: int) -> void:
	if is_dead:
		return
	add_hunger(hunger_amount)
	heal(heal_amount)
	food_eaten_count += 1
	food_eaten.emit(food_eaten_count, FOOD_PER_EVOLUTION)
	if food_eaten_count >= FOOD_PER_EVOLUTION:
		food_eaten_count = 0
		if evolution_level < MAX_EVOLUTION:
			_evolve()


## 进化：等级 +1，刷新属性，回满血，发光特效
func _evolve() -> void:
	evolution_level += 1
	saved_evolution_level = evolution_level
	_apply_evolution_stats()
	# 进化回满血
	current_health = max_health
	health_changed.emit(current_health, max_health)
	hunger_changed.emit(current_hunger, max_hunger)
	var level_name: String = EVOLUTION_NAMES[evolution_level]
	evolved.emit(evolution_level, level_name)
	_play_evolve_glow()


## 进化发光特效：金色 emission 渐隐
func _play_evolve_glow() -> void:
	if body_material == null:
		return
	body_material.emission_enabled = true
	body_material.emission = Color(1.0, 0.85, 0.2)
	body_material.emission_energy_multiplier = 2.5
	var tween: Tween = create_tween()
	tween.tween_property(body_material, "emission_energy_multiplier", 0.0, EVOLVE_GLOW_DURATION)


## 获取当前进化等级名称（供 HUD 使用）
func get_evolution_name() -> String:
	return EVOLUTION_NAMES[evolution_level]


## 获取当前进化等级（1-based，供 HUD 显示 Lv.X）
func get_evolution_display_level() -> int:
	return evolution_level + 1
