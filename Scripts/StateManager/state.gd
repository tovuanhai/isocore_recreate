class_name State
extends Node

# Emit tín hiệu này để báo cho máy trạng thái biết tôi muốn chuyển sang State khác
signal transition_requested(new_state_name: String)

# Chạy 1 lần duy nhất khi VỪA BƯỚC VÀO trạng thái này
func enter() -> void:
	pass

# Chạy 1 lần duy nhất khi VỪA THOÁT KHỎI trạng thái này
func exit() -> void:
	pass

# Thay thế cho _process()
func update(_delta: float) -> void:
	pass

# Thay thế cho _physics_process()
func physics_update(_delta: float) -> void:
	pass
