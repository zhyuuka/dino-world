class_name HUD
extends CanvasLayer
## HUD 层：左上血量/饥饿/进化等级 / 右上击杀数/进化进度 / 居中进化横幅 / 底部提示 / 居中结束文案

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthBar/HealthLabel
@onready var hunger_bar: ProgressBar = $Control/HungerBar
@onready var hunger_label: Label = $Control/HungerBar/HungerLabel
@onready var evolution_label: Label = $Control/EvolutionLabel
@onready var kill_label: Label = $Control/KillLabel
@onready var evolution_progress_bar: ProgressBar = $Control/EvolutionProgressBar
@onready var evolution_progress_label: Label = $Control/EvolutionProgressBar/EvolutionProgressLabel
@onready var evolution_banner: Label = $Control/EvolutionBanner
@onready var hint_label: Label = $Control/HintLabel
@onready var game_over_label: Label = $Control/GameOverLabel
@onready var victory_label: Label = $Control/VictoryLabel


func _ready() -> void:
	game_over_label.visible = false
	victory_label.visible = false
	evolution_banner.visible = false
	hint_label.modulate.a = 1.0
	# 3 秒后淡出提示
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


## 设置玩家血量条
func set_player_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]


## 设置玩家饥饿条
func set_player_hunger(current: int, maximum: int) -> void:
	hunger_bar.max_value = maximum
	hunger_bar.value = current
	hunger_label.text = "%d / %d" % [current, maximum]


## 设置进化等级（display_level: 1-based, name: 中文名）
func set_evolution(display_level: int, level_name: String) -> void:
	evolution_label.text = "%s Lv.%d" % [level_name, display_level]


## 设置击杀数
func set_kill_count(count: int) -> void:
	kill_label.text = "击杀: %d" % count


## 设置进化进度条（当前食物数 / 进化所需数）
func set_food_progress(count: int, required: int) -> void:
	evolution_progress_bar.max_value = required
	evolution_progress_bar.value = count
	evolution_progress_label.text = "进化进度 %d/%d" % [count, required]


## 显示提示文字（3 秒后淡出）
func show_hint(text: String) -> void:
	hint_label.text = text
	hint_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


## 显示进化横幅：屏幕中央显示"进化为【XX】！"2 秒后淡出
func show_evolution(level_name: String) -> void:
	evolution_banner.text = "进化为【%s】！" % level_name
	evolution_banner.modulate.a = 1.0
	evolution_banner.visible = true
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(evolution_banner, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): evolution_banner.visible = false)


## 显示游戏结束
func show_game_over() -> void:
	game_over_label.visible = true


## 显示胜利
func show_victory() -> void:
	victory_label.visible = true
