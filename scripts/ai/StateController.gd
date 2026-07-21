class_name StateController
extends Node
## AI 状态机控制器
## 维护 AI 恐龙的当前状态、停留时间，并发出状态切换信号
## 状态枚举：WANDER（游荡）/ CHASE（追击）/ FLEE（逃跑）/ DEAD（死亡）

enum State { WANDER, CHASE, FLEE, DEAD }

signal state_changed(old_state: State, new_state: State)

@export var initial_state: State = State.WANDER

var current_state: State = State.WANDER
var previous_state: State = State.WANDER
var state_time: float = 0.0


func _ready() -> void:
	current_state = initial_state
	previous_state = initial_state
	state_time = 0.0


func _physics_process(delta: float) -> void:
	state_time += delta


## 切换到新状态；若与当前状态相同则忽略
func transition_to(new_state: State) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	state_time = 0.0
	state_changed.emit(previous_state, current_state)
