class_name StateMachine
extends Node

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	# BƯỚC 1: Quét và kết nạp tất cả các State con
	for child in get_children():
		# Nếu Godot ngáo không nhận class_name State, ta check bằng tên node luôn cho chắc!
		if child.has_method("enter") and child.has_method("exit"):
			states[child.name.to_lower()] = child
			child.transition_requested.connect(_on_transition_requested)
			
	# BƯỚC 2: Tự động gắp Node Idle làm trạng thái mặc định nếu ông quên kéo thả
	if initial_state == null:
		initial_state = get_node_or_null("Idle")
		
	# BƯỚC 3: Khởi động cỗ máy
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

# Hàm đổi trạng thái
func _on_transition_requested(new_state_name: String) -> void:
	var new_state = states.get(new_state_name.to_lower())
	if not new_state or new_state == current_state:
		return
		
	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state
