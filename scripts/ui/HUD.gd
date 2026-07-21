class_name HUD
extends CanvasLayer
## HUD 层：左上血量条 / 右上击杀数 / 底部提示 / 居中结束文案

@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthBar/HealthLabel
@onready var kill_label: Label = $Control/KillLabel
@onready var hint_label: Label = $Control/HintLabel
@onready var game_over_label: Label = $Control/GameOverLabel
@onready var victory_label: Label = $Control/VictoryLabel


func _ready() -> void:
	game_over_label.visible = false
	victory_label.visible = false
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


## 设置击杀数
func set_kill_count(count: int) -> void:
	kill_label.text = "击杀: %d" % count


## 显示提示文字（3 秒后淡出）
func show_hint(text: String) -> void:
	hint_label.text = text
	hint_label.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


## 显示游戏结束
func show_game_over() -> void:
	game_over_label.visible = true


## 显示胜利
func show_victory() -> void:
	victory_label.visible = true
