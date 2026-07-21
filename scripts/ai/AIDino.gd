class_name AIDino
extends CharacterBody3D
## AI 恐龙：状态机驱动的游荡/追击/逃跑/寻食
## 物理层 layer 3 (AI)，collision_mask = layer 1 (World) + layer 2 (Player)
## 分两类食性：
##   - CARNIVORE（肉食）：主动追玩家，咬玩家造成伤害，血量 8
##   - HERBIVORE（食草）：见玩家就跑，平时找果子吃，血量 5
## 死亡时发出信号，由 Main 生成尸体替换

signal died(node: AIDino)

## 食性分类
enum Diet { CARNIVORE, HERBIVORE }

@export_group("Diet")
@export var diet: Diet = Diet.HERBIVORE

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
@export var food_seek_radius: float = 18.0  # 食草 AI 寻找果子的感知半径

# --- 内部状态 ---
var current_health: int = 10
var is_dead: bool = false
var player: Node3D = null
var food_spawner: FoodSpawner = null
var wander_dir: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var attack_timer: float = 0.0
var dino_materials: Array[StandardMaterial3D] = []

# --- 节点引用 ---
@onready var state_controller: StateController = $StateController
@onready var dino_visual: Node3D = $DinoVisual
@onready var contact_area: Area3D = $ContactArea

const GRAVITY: float = 19.6
# 视觉部分名称常量，用于材质替换
const BODY_PART_NAMES: Array[String] = ["Body", "Head", "Tail"]


func _ready() -> void:
	current_health = max_health
	_apply_diet_appearance()
	state_controller.transition_to(StateController.State.WANDER)


## 根据食性应用不同颜色：肉食红橙，食草绿棕
func _apply_diet_appearance() -> void:
	var body_color: Color
	var dark_color: Color
	if diet == Diet.CARNIVORE:
		# 肉食：红橙色
		body_color = Color(0.85, 0.35, 0.2)
		dark_color = Color(0.55, 0.2, 0.1)
	else:
		# 食草：绿棕色
		body_color = Color(0.45, 0.65, 0.25)
		dark_color = Color(0.3, 0.45, 0.15)
	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.roughness = 0.8
	var dark_mat: StandardMaterial3D = StandardMaterial3D.new()
	dark_mat.albedo_color = dark_color
	dark_mat.roughness = 0.8
	# 启用透明以备死亡淡出
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dino_materials = [body_mat, dark_mat]
	# 遍历所有 CSG，根据节点名分配材质
	for csg in dino_visual.find_children("*", "CSGBox3D", true, true):
		if csg.name in BODY_PART_NAMES:
			csg.material = body_mat
		else:
			csg.material = dark_mat


func set_player(p: Node3D) -> void:
	player = p


func set_food_spawner(fs: FoodSpawner) -> void:
	food_spawner = fs


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 重力
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 状态切换
	_update_state()

	# 状态行为
	match state_controller.current_state:
		StateController.State.WANDER:
			_wander_behavior(delta)
		StateController.State.CHASE:
			_chase_behavior(delta)
		StateController.State.FLEE:
			_flee_behavior(delta)
		StateController.State.SEEK_FOOD:
			_seek_food_behavior(delta)

	# 攻击冷却
	if attack_timer > 0.0:
		attack_timer -= delta

	# 接触玩家造成伤害（仅肉食 AI）
	if diet == Diet.CARNIVORE and attack_damage > 0 and attack_timer <= 0.0 and player:
		for body in contact_area.get_overlapping_bodies():
			if body is PlayerDino:
				(body as PlayerDino).take_damage(attack_damage)
				attack_timer = attack_cooldown
				break

	move_and_slide()


## 根据食性/血量/玩家距离/果子位置决策当前状态
func _update_state() -> void:
	if not is_instance_valid(player):
		state_controller.transition_to(StateController.State.WANDER)
		return
	var dist: float = global_position.distance_to(player.global_position)
	var hp_ratio: float = float(current_health) / float(max_health)

	if diet == Diet.CARNIVORE:
		# 肉食 AI：血量过低逃跑，否则永远追玩家
		if hp_ratio < flee_health_ratio:
			state_controller.transition_to(StateController.State.FLEE)
		else:
			state_controller.transition_to(StateController.State.CHASE)
	else:
		# 食草 AI：看到玩家逃跑，否则找附近果子或游荡
		if dist < detect_radius:
			state_controller.transition_to(StateController.State.FLEE)
		elif _find_nearby_berry() != null:
			state_controller.transition_to(StateController.State.SEEK_FOOD)
		else:
			state_controller.transition_to(StateController.State.WANDER)


## 查找感知范围内的最近果子
func _find_nearby_berry() -> Berry:
	if food_spawner == null:
		return null
	var berry: Berry = food_spawner.find_nearest_berry(global_position)
	if berry == null:
		return null
	if global_position.distance_to(berry.global_position) <= food_seek_radius:
		return berry
	return null


## 游荡：每隔几秒切换随机方向
func _wander_behavior(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
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


## 寻找果子：走向最近的果子
func _seek_food_behavior(delta: float) -> void:
	var berry: Berry = _find_nearby_berry()
	if berry == null:
		_wander_behavior(delta)
		return
	var to_berry: Vector3 = berry.global_position - global_position
	to_berry.y = 0.0
	if to_berry.length() > 0.01:
		wander_dir = to_berry.normalized()
	_apply_movement(wander_dir, walk_speed, delta)


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
	var original_scale: Vector3 = dino_visual.scale
	var tween: Tween = create_tween()
	tween.tween_property(dino_visual, "scale", original_scale * 1.1, 0.05)
	tween.tween_property(dino_visual, "scale", original_scale, 0.12)
	if current_health <= 0:
		_die()


## 死亡：发出信号，立即销毁（由 Main 生成尸体替换）
func _die() -> void:
	if is_dead:
		return
	is_dead = true
	state_controller.transition_to(StateController.State.DEAD)
	died.emit(self)
	queue_free()


## 食草 AI 吃到果子时回血（由 FoodSpawner 调用）
func on_ate_berry() -> void:
	if is_dead:
		return
	current_health = mini(current_health + 3, max_health)
