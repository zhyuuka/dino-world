extends Node3D
## 主场景控制器：负责生成玩家、AI、尸体、果子、HUD、触屏控制，并管理游戏循环
## - 监听玩家咬击 → 对 AI 造成伤害 / 吃尸体
## - 监听 AI 死亡 → 生成尸体替换、累计击杀、检测胜利
## - 监听果子被吃 → 玩家回饥饿 / 食草 AI 回血
## - 监听玩家饥饿/进化 → 更新 HUD
## - 监听玩家死亡 → 显示游戏结束并 3 秒后重开（保留进化等级）

const PlayerScene: PackedScene = preload("res://scenes/PlayerDino.tscn")
const AIScene: PackedScene = preload("res://scenes/AIDino.tscn")
const CorpseScene: PackedScene = preload("res://scenes/AICorpse.tscn")
const FoodSpawnerScene: PackedScene = preload("res://scenes/FoodSpawner.tscn")
const HUDScene: PackedScene = preload("res://scenes/HUD.tscn")
const TouchControlsScene: PackedScene = preload("res://scenes/TouchControls.tscn")

# AI 生成配置：2 肉食 + 3 食草
const CARNIVORE_COUNT: int = 2
const HERBIVORE_COUNT: int = 3
const AI_SPAWN_RADIUS: float = 14.0
const PLAYER_SPAWN_Y: float = 1.5
const RESTART_DELAY: float = 3.0

# 尸体食物回复量
const CORPSE_HUNGER_AMOUNT: int = 30
const CORPSE_HEAL_AMOUNT: int = 10
# 果子食物回复量（玩家）
const BERRY_HUNGER_AMOUNT: int = 5

var player: PlayerDino
var ai_dinos: Array[AIDino] = []
var corpses: Array[AICorpse] = []
var food_spawner: FoodSpawner
var hud: HUD
var touch_controls: TouchControls
var kill_count: int = 0
var is_game_over: bool = false
var restart_timer: float = 0.0


func _ready() -> void:
	randomize()
	_spawn_food_spawner()
	_spawn_player()
	_spawn_ai()
	_spawn_hud()
	_spawn_touch_controls()


## 生成果子生成器
func _spawn_food_spawner() -> void:
	food_spawner = FoodSpawnerScene.instantiate() as FoodSpawner
	add_child(food_spawner)


## 生成玩家恐龙
func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector3(0.0, PLAYER_SPAWN_Y, 0.0)
	player.health_changed.connect(_on_player_health_changed)
	player.hunger_changed.connect(_on_player_hunger_changed)
	player.died.connect(_on_player_died)
	player.bite_hit.connect(_on_player_bite_hit)
	player.evolved.connect(_on_player_evolved)
	player.food_eaten.connect(_on_player_food_eaten)


## 生成 AI 恐龙群：2 肉食 + 3 食草
func _spawn_ai() -> void:
	var total: int = CARNIVORE_COUNT + HERBIVORE_COUNT
	for i in total:
		var ai: AIDino = AIScene.instantiate() as AIDino
		# 在 add_child 之前设置 diet，_ready 才能正确应用外观
		if i < CARNIVORE_COUNT:
			ai.diet = AIDino.Diet.CARNIVORE
			ai.max_health = 8
			ai.attack_damage = 3
		else:
			ai.diet = AIDino.Diet.HERBIVORE
			ai.max_health = 5
			ai.attack_damage = 0
		add_child(ai)
		# 在玩家周围环形分布
		var angle: float = (float(i) / float(total)) * TAU + randf() * 0.3
		var pos: Vector3 = Vector3(
			sin(angle) * AI_SPAWN_RADIUS,
			PLAYER_SPAWN_Y,
			cos(angle) * AI_SPAWN_RADIUS
		)
		ai.global_position = pos
		ai.set_player(player)
		ai.set_food_spawner(food_spawner)
		ai.died.connect(_on_ai_died)
		ai_dinos.append(ai)


## 生成 HUD
func _spawn_hud() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)
	hud.set_player_health(player.current_health, player.max_health)
	hud.set_player_hunger(player.current_hunger, player.max_hunger)
	hud.set_evolution(player.get_evolution_display_level(), player.get_evolution_name())
	hud.set_food_progress(0, PlayerDino.FOOD_PER_EVOLUTION)
	hud.set_kill_count(0)
	hud.show_hint("咬死恐龙吃尸体回饥饿，吃果子也能少量回饥饿")


## 生成触屏控制
func _spawn_touch_controls() -> void:
	touch_controls = TouchControlsScene.instantiate()
	add_child(touch_controls)
	touch_controls.move_input_changed.connect(player.set_move_input)
	touch_controls.bite_pressed.connect(player.try_bite)
	touch_controls.jump_pressed.connect(player.try_jump)

	# 果子被吃信号连接
	food_spawner.berry_eaten_by_player.connect(_on_berry_eaten_by_player)
	food_spawner.berry_eaten_by_ai.connect(_on_berry_eaten_by_ai)


func _process(delta: float) -> void:
	if is_game_over:
		restart_timer -= delta
		if restart_timer <= 0.0:
			get_tree().reload_current_scene()
		return
	# 检查胜利：所有 AI 死亡（不考虑尸体是否吃完）
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


func _on_player_hunger_changed(current: int, maximum: int) -> void:
	hud.set_player_hunger(current, maximum)


func _on_player_died() -> void:
	_trigger_end(false)


## 玩家咬击命中：AI 恐龙造成伤害 / 尸体则吃尸体
func _on_player_bite_hit(target: Node3D) -> void:
	if target is AIDino:
		(target as AIDino).take_damage(player.bite_damage)
	elif target is AICorpse:
		var corpse: AICorpse = target as AICorpse
		if corpse.try_eat():
			player.eat_food(CORPSE_HUNGER_AMOUNT, CORPSE_HEAL_AMOUNT)


## AI 死亡：累计击杀、生成尸体、从列表移除
func _on_ai_died(ai: AIDino) -> void:
	ai_dinos.erase(ai)
	kill_count += 1
	hud.set_kill_count(kill_count)
	# 在原位生成尸体
	var corpse: AICorpse = CorpseScene.instantiate() as AICorpse
	add_child(corpse)
	corpse.global_position = ai.global_position


## 玩家吃到果子：回 5 饥饿（0 血量）
func _on_berry_eaten_by_player(p: PlayerDino) -> void:
	p.eat_food(BERRY_HUNGER_AMOUNT, 0)


## 食草 AI 吃到果子：回血（不影响玩家）
func _on_berry_eaten_by_ai(ai: AIDino) -> void:
	ai.on_ate_berry()


## 玩家进化：更新 HUD 等级显示 + 显示横幅
func _on_player_evolved(level: int, level_name: String) -> void:
	hud.set_evolution(level + 1, level_name)
	hud.show_evolution(level_name)


## 玩家食物计数变化：更新 HUD 进度条
func _on_player_food_eaten(count: int, required: int) -> void:
	hud.set_food_progress(count, required)
