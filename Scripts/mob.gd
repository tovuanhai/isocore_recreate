class_name Mob
extends Vessel

@export var speed: float = 50.0

# Các hàm dùng chung cho sinh vật di chuyển
func apply_movement(direction: Vector2, delta: float) -> void:
	velocity = direction * speed
	move_and_slide()
