extends Node3D
## 主场景控制器：负责生成玩家、AI、HUD、触屏控制，并管理游戏循环
## - 监听玩家咬击 → 对 AI 造成伤害
## - 监听 AI 死亡 → 累计击杀、检测胜利
## - 监听玩家死亡 → 显示游戏结束并 3 秒后重开
## - 监听所有 AI 死亡 → 显示胜利并 3 秒后重开

const PlayerScene: PackedScene = preload("res://scenes/PlayerDino.tscn")
const AIScene: PackedScene = preload("res://scenes/AIDino.tscn")
const HUDScene: PackedScene = preload("res://scenes/HUD.tscn")
const TouchControlsScene: PackedScene = preload("res://scenes/TouchControls.tscn")

# AI 生成配置
const AI_COUNT: int = 4
const AI_SPAWN_RADIUS: float = 14.0
const PLAYER_SPAWN_Y: float = 1.5
const RESTART_DELAY: float = 3.0

var player: PlayerDino
var ai_dinos: Array[AIDino] = []
var hud: HUD
var touch_controls: TouchControls
var kill_count: int = 0
var is_game_over: bool = false
var restart_timer: float = 0.0


func _ready() -> void:
	randomize()
	_spawn_player()
	_spawn_ai()
	_spawn_hud()
	_spawn_touch_controls()


## 生成玩家恐龙
func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, PLAYER_SPAWN_Y, 0.0)
	player.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	player.bite_hit.connect(_on_player_bite_hit)


## 生成 AI 恐龙群
func _spawn_ai() -> void:
	for i in AI_COUNT:
		var ai: AIDino = AIScene.instantiate()
		add_child(ai)
		# 在玩家周围环形分布
		var angle: float = (float(i) / float(AI_COUNT)) * TAU + randf() * 0.3
		var pos: Vector3 = Vector3(
			sin(angle) * AI_SPAWN_RADIUS,
			PLAYER_SPAWN_Y,
			cos(angle) * AI_SPAWN_RADIUS
		)
		ai.global_position = pos
		ai.set_player(player)
		ai.died.connect(_on_ai_died)
		ai_dinos.append(ai)


## 生成 HUD
func _spawn_hud() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)
	hud.set_player_health(player.current_health, player.max_health)
	hud.set_kill_count(0)
	hud.show_hint("咬击 AI 恐龙获得分数")


## 生成触屏控制
func _spawn_touch_controls() -> void:
	touch_controls = TouchControlsScene.instantiate()
	add_child(touch_controls)
	touch_controls.move_input_changed.connect(player.set_move_input)
	touch_controls.bite_pressed.connect(player.try_bite)
	touch_controls.jump_pressed.connect(player.try_jump)


func _process(delta: float) -> void:
	if is_game_over:
		restart_timer -= delta
		if restart_timer <= 0.0:
			get_tree().reload_current_scene()
		return
	# 检查胜利：所有 AI 死亡
	if ai_dinos.is_empty() and not is_game_over:
		_trigger_end(true)


## 触发游戏结束
func _trigger_end(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	restart_timer = RESTART_DELAY
	if victory:
		hud.show_victory()
	else:
		hud.show_game_over()


func _on_player_health_changed(current: int, maximum: int) -> void:
	hud.set_player_health(current, maximum)


func _on_player_died() -> void:
	_trigger_end(false)


func _on_player_bite_hit(target: Node3D) -> void:
	if target is AIDino:
		(target as AIDino).take_damage(player.bite_damage)


func _on_ai_died(ai: AIDino) -> void:
	ai_dinos.erase(ai)
	kill_count += 1
	hud.set_kill_count(kill_count)
