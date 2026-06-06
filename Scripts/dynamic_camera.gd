extends Camera2D

@export var player: CharacterBody2D
@export var dead_zone_radius: float = 50.0 # Vùng chết: Camera đứng yên trong bán kính này
@export var follow_speed: float = 3.0      # Độ mượt khi camera đuổi theo

func _physics_process(delta: float) -> void:
	if not player: return
	
	var camera_pos = global_position
	var player_pos = player.global_position
	
	# Tính khoảng cách giữa Camera và Player
	var distance = camera_pos.distance_to(player_pos)
	
	# Nếu khoảng cách > dead_zone_radius, bắt đầu di chuyển camera
	if distance > dead_zone_radius:
		# Tính hướng di chuyển cần thiết
		var direction = (player_pos - camera_pos).normalized()
		
		# Tính khoảng cách thừa ra ngoài vùng chết
		var displacement = distance - dead_zone_radius
		
		# Di chuyển camera về phía player với tốc độ follow_speed
		global_position += direction * displacement * follow_speed * delta

func _draw() -> void:
	# Debug: Vẽ vùng chết lên màn hình (chỉ hiện trong editor)
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, dead_zone_radius, 0, TAU, 32, Color.YELLOW, 2.0)
