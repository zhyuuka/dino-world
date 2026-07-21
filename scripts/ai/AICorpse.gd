class_name AICorpse
extends StaticBody3D
## AI 恐龙尸体：玩家走到附近按咬键可吃
## - 15 秒后自动消失
## - 可吃 2 口，每口回 30 饥饿 + 10 血量
## - 吃完 2 口立即消失
## - 视觉：变暗 + 躺倒（绕 X 轴旋转 90 度）
## 物理层 layer 3 (AI)，被玩家 BiteArea 检测

const LIFETIME: float = 15.0
const MAX_BITES: int = 2
const FADE_DURATION: float = 0.4

@onready var dino_visual: Node3D = $DinoVisual

var bites_remaining: int = MAX_BITES
var lifetime_timer: float = LIFETIME
var is_being_destroyed: bool = false


func _ready() -> void:
	# 躺倒：绕 X 轴旋转 90 度（侧躺）
	dino_visual.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	# 材质变暗
	for csg in dino_visual.find_children("*", "CSGBox3D", true, true):
		if csg.material is StandardMaterial3D:
			var mat: StandardMaterial3D = (csg.material as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = mat.albedo_color.darkened(0.55)
			csg.material = mat


func _process(delta: float) -> void:
	if is_being_destroyed:
		return
	lifetime_timer -= delta
	if lifetime_timer <= 0.0:
		_fade_out_and_free()


## 玩家尝试吃尸体。返回 true 表示吃成功，false 表示尸体已无剩余
func try_eat() -> bool:
	if is_being_destroyed or bites_remaining <= 0:
		return false
	bites_remaining -= 1
	# 受吃反馈：轻微缩放后回位
	var original_scale: Vector3 = dino_visual.scale
	var tween: Tween = create_tween()
	tween.tween_property(dino_visual, "scale", original_scale * 1.1, 0.05)
	tween.tween_property(dino_visual, "scale", original_scale, 0.12)
	if bites_remaining <= 0:
		# 最后一口吃完，淡出消失
		_fade_out_and_free()
	return true


## 淡出并销毁
func _fade_out_and_free() -> void:
	if is_being_destroyed:
		return
	is_being_destroyed = true
	var tween: Tween = create_tween()
	for csg in dino_visual.find_children("*", "CSGBox3D", true, true):
		if csg.material is StandardMaterial3D:
			var mat: StandardMaterial3D = csg.material as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			tween.parallel().tween_property(mat, "albedo_color:a", 0.0, FADE_DURATION)
	tween.chain().tween_callback(queue_free)
