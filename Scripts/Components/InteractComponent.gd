class_name InteractComponent
extends Node

@export var interact_distance: float = 30.0
signal interacted  # Phát tín hiệu ra ngoài khi được gọi

func _ready() -> void:
	# 🎯 ĐĂNG KÝ VÀO GROUP ĐỂ PLAYER TÌM THẤY
	add_to_group("interactable_components")

# (Đã xóa hoàn toàn hàm _unhandled_input cũ ở đây)
