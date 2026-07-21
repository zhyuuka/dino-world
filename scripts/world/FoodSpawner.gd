class_name FoodSpawner
extends Node3D
## 果子生成器：在地图随机分布果子，玩家/食草 AI 自动捡食
## - 初始生成 8~12 个果子
## - 玩家走近自动捡（回 5 饥饿）
## - 食草 AI 走近自动吃（回血，不影响玩家）
## - 每隔 30 秒在随机位置重新生成一个被吃掉的果子

const BerryScene: PackedScene = preload("res://scenes/Berry.tscn")

const MIN_BERRIES: int = 8
const MAX_BERRIES: int = 12
const SPAWN_RADIUS: float = 22.0
const RESPAWN_INTERVAL: float = 30.0

# 信号：玩家吃到果子 / 食草 AI 吃到果子
signal berry_eaten_by_player(player: PlayerDino)
signal berry_eaten_by_ai(ai: AIDino)

var berries: Array[Berry] = []
var respawn_timers: Array[float] = []


func _ready() -> void:
	var count: int = randi_range(MIN_BERRIES, MAX_BERRIES)
	for i in count:
		_spawn_berry(_random_position())


func _process(delta: float) -> void:
	# 检查每个果子是否被玩家或食草 AI 接触
	var to_remove: Array[int] = []
	for i in range(berries.size()):
		var berry: Berry = berries[i]
		if not is_instance_valid(berry):
			to_remove.append(i)
			continue
		for body in berry.get_overlapping_bodies():
			if body is PlayerDino:
				berry.queue_free()
				berry_eaten_by_player.emit(body as PlayerDino)
				to_remove.append(i)
				break
			elif body is AIDino:
				var ai: AIDino = body as AIDino
				if ai.diet == AIDino.Diet.HERBIVORE and not ai.is_dead:
					berry.queue_free()
					berry_eaten_by_ai.emit(ai)
					to_remove.append(i)
					break
	# 反向移除已被吃的，加入重生计时
	to_remove.reverse()
	for i in to_remove:
		berries.remove_at(i)
		respawn_timers.append(RESPAWN_INTERVAL)
	# 处理重生计时
	var respawn_done: Array[int] = []
	for i in range(respawn_timers.size()):
		respawn_timers[i] -= delta
		if respawn_timers[i] <= 0.0:
			_spawn_berry(_random_position())
			respawn_done.append(i)
	respawn_done.reverse()
	for i in respawn_done:
		respawn_timers.remove_at(i)


## 找到距离 origin 最近的果子（用于食草 AI 寻路）
func find_nearest_berry(origin: Vector3) -> Berry:
	var nearest: Berry = null
	var nearest_dist: float = 1e18
	for berry in berries:
		if not is_instance_valid(berry):
			continue
		var d: float = berry.global_position.distance_squared_to(origin)
		if d < nearest_dist:
			nearest_dist = d
			nearest = berry
	return nearest


func _spawn_berry(pos: Vector3) -> void:
	var berry: Berry = BerryScene.instantiate() as Berry
	add_child(berry)
	berry.global_position = pos
	berries.append(berry)


func _random_position() -> Vector3:
	var angle: float = randf() * TAU
	var dist: float = randf() * SPAWN_RADIUS
	return Vector3(sin(angle) * dist, 0.0, cos(angle) * dist)
