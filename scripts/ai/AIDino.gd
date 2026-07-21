class_name AIDino
extends CharacterBody3D
## AI 恐龙：状态机驱动的游荡/追击/逃跑
## 物理层 layer 3 (AI)，collision_mask = layer 1 (World) + layer 2 (Player)
## 被玩家咬到掉血；血量过低转 FLEE；接触玩家造成伤害（带冷却）
## 死亡时发出信号通知 Main，并播放 1 秒淡出后销毁

signal died(node: AIDino)

@export_group("Movement")
@export var walk_speed: float = 2.6
@export var run_speed: float = 5.6
@export var acceleration: float = 10.0
@export var rotation_speed: float = 6.0

@export_group("Health")
@export var max_health: int = 10

@export_group("AI")
@export var detect_radius: float = 15.0
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.0
@export var flee_health_ratio: float = 0.3
@export var wander_change_interval: float = 3.0
@export var wander_min_pause: float = 1.0

# --- 内部状态 ---
var current_health: int = 10
var is_dead: bool = false
var player: Node3D = null
var wander_dir: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var attack_timer: float = 0.0
var dino_materials: Array[StandardMaterial3D] = []

# --- 节点引用 ---
@onready var state_controller: StateController = $StateController
@onready var dino_visual: Node3D = $DinoVisual
@onready var contact_area: Area3D = $ContactArea

const GRAVITY: float = 19.6


func _ready() -> void:
	current_health = max_health
	# 收集视觉部分的材质副本，用于死亡淡出
	for child in dino_visual.get_children():
		if child is CSGBox3D:
			var csg: CSGBox3D = child as CSGBox3D
			if csg.material is StandardMaterial3D:
				var mat: StandardMaterial3D = (csg.material as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				csg.material = mat
				dino_materials.append(mat)
	state_controller.transition_to(StateController.State.WANDER)


func set_player(p: Node3D) -> void:
	player = p


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 重力
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 状态切换（每帧根据血量与距离决策）
	_update_state()

	# 状态行为
	match state_controller.current_state:
		StateController.State.WANDER:
			_wander_behavior(delta)
		StateController.State.CHASE:
			_chase_behavior(delta)
		StateController.State.FLEE:
			_flee_behavior(delta)

	# 攻击冷却
	if attack_timer > 0.0:
		attack_timer -= delta

	# 接触玩家造成伤害
	if player and attack_timer <= 0.0:
		for body in contact_area.get_overlapping_bodies():
			if body is PlayerDino:
				(body as PlayerDino).take_damage(attack_damage)
				attack_timer = attack_cooldown
				break

	move_and_slide()


## 根据血量与玩家距离决策当前状态
func _update_state() -> void:
	if not is_instance_valid(player):
		state_controller.transition_to(StateController.State.WANDER)
		return
	var dist: float = global_position.distance_to(player.global_position)
	var hp_ratio: float = float(current_health) / float(max_health)
	if hp_ratio < flee_health_ratio:
		state_controller.transition_to(StateController.State.FLEE)
	elif dist < detect_radius:
		state_controller.transition_to(StateController.State.CHASE)
	else:
		state_controller.transition_to(StateController.State.WANDER)


## 游荡：每隔几秒切换随机方向
func _wander_behavior(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		# 一定概率停下，否则换新方向
		if randf() < 0.3:
			wander_dir = Vector3.ZERO
			wander_timer = wander_min_pause + randf() * 1.0
		else:
			var angle: float = randf() * TAU
			wander_dir = Vector3(sin(angle), 0.0, cos(angle))
			wander_timer = wander_change_interval + randf() * 1.5
	_apply_movement(wander_dir, walk_speed, delta)


## 追击：朝玩家方向移动
func _chase_behavior(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		wander_dir = to_player.normalized()
	_apply_movement(wander_dir, run_speed, delta)


## 逃跑：远离玩家
func _flee_behavior(delta: float) -> void:
	if not is_instance_valid(player):
		_wander_behavior(delta)
		return
	var away: Vector3 = global_position - player.global_position
	away.y = 0.0
	if away.length() > 0.01:
		wander_dir = away.normalized()
	_apply_movement(wander_dir, run_speed, delta)


## 朝当前方向施加加速度并旋转模型
func _apply_movement(dir: Vector3, speed: float, delta: float) -> void:
	var target_vel: Vector3 = dir * speed
	var accel: float = acceleration * delta
	velocity.x = move_toward(velocity.x, target_vel.x, accel)
	velocity.z = move_toward(velocity.z, target_vel.z, accel)
	if dir.length() > 0.1:
		var target_yaw: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)


## 受到伤害（由玩家咬击调用）
func take_damage(amount: int) -> void:
	if is_dead:
		return
	current_health = max(0, current_health - amount)
	# 受击反馈
	var tween: Tween = create_tween()
	tween.tween_property(dino_visual, "scale", Vector3(1.1, 1.1, 1.1), 0.05)
	tween.tween_property(dino_visual, "scale", Vector3.ONE, 0.12)
	if current_health <= 0:
		_die()


## 死亡：发出信号、淡出 1 秒后销毁
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state_controller.transition_to(StateController.State.DEAD)
	died.emit(self)
	# 淡出动画：材质 alpha 渐变 + 下沉
	var tween: Tween = create_tween().set_parallel(true)
	for mat in dino_materials:
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tween.tween_property(self, "global_position:y", global_position.y - 0.5, 1.0)
	# 1 秒后销毁节点
	tween.chain().tween_callback(queue_free)
