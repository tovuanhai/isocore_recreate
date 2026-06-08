extends Camera2D

@export var player: CharacterBody2D
@export var dead_zone_radius: float = 25.0 # Vùng chết: Camera đứng yên trong bán kính này
@export var follow_speed: float = 3.0      # Độ mượt khi camera đuổi theo

# --- CẤU HÌNH ZOOM SỐ NGUYÊN (INTEGER ZOOM) ---
@export var zoom_speed: int = 1
@export var min_zoom: int = 1
@export var max_zoom: int = 10
@export var default_zoom: int = 5

# Biến nội bộ lưu trữ mức zoom hiện tại dưới dạng số nguyên
var current_zoom_level: int = default_zoom

func _ready() -> void:
	# Đặt mức zoom mặc định = 5 ngay khi vào game
	set_zoom_level(default_zoom)

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

# --- XỬ LÝ LĂN CHUỘT ZOOM KHI ĐÈ CTRL ---
func _unhandled_input(event: InputEvent) -> void:
	# Kiểm tra xem người chơi có đang ĐÈ PHÍM CTRL hay không
	if Input.is_key_pressed(KEY_CTRL):
		if event is InputEventMouseButton and event.is_pressed():
			# Lăn chuột LÊN -> Phóng to (Zoom In)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				change_zoom(zoom_speed)
			# Lăn chuột XUỐNG -> Thu nhỏ (Zoom Out)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-zoom_speed)

# Hàm tính toán và giới hạn mức zoom bằng số nguyên (clampi)
func change_zoom(amount: int) -> void:
	current_zoom_level = clampi(current_zoom_level + amount, min_zoom, max_zoom)
	set_zoom_level(current_zoom_level)

# Hàm ép Camera nhận Vector2 nguyên vẹn, giữ sắc nét cho pixel art
func set_zoom_level(level: int) -> void:
	zoom = Vector2(level, level)

func _draw() -> void:
	# Debug: Vẽ vùng chết lên màn hình (chỉ hiện trong editor)
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, dead_zone_radius, 0, TAU, 32, Color.YELLOW, 2.0)
