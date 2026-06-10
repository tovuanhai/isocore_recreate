extends Camera2D

@export var player: Node2D

# --- CẤU HÌNH VÙNG CHẾT HÌNH CHỮ NHẬT ---
# Định hình một cái hộp ảo ở giữa màn hình. Mèo đi trong này cam sẽ im lặng.
@export var dead_zone_size: Vector2 = Vector2(80.0, 60.0) 
@export var follow_speed: float = 6.0      # Tốc độ kéo mượt khi Mèo đi vượt vách hộp

# --- CẤU HÌNH ZOOM SỐ NGUYÊN ---
@export var zoom_speed: int = 1
@export var min_zoom: int = 1
@export var max_zoom: int = 10
@export var default_zoom: int = 5

var current_zoom_level: int = default_zoom

func _ready() -> void:
	# 🔒 KHÓA KHỬ LỆCH TÂM: Ép Camera lấy tâm màn hình làm gốc (Tránh lỗi Fixed Top-Left)
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	set_zoom_level(default_zoom)

func _physics_process(delta: float) -> void:
	if not player: return
	
	var camera_pos = global_position
	var player_pos = player.global_position
	
	# =========================================================================
	# 🎯 LỚP PHÒNG THỦ 1: CHỐNG LỆCH DO SPAWNER TỰ ĐỘNG
	# Nếu khoảng cách giữa Cam và Mèo bỗng dưng > 300 pixel (do Spawner dịch chuyển Mèo),
	# ép Camera phải "Tốc biến" bay thẳng tới ôm lấy Mèo ngay lập tức và xóa bộ nhớ đệm.
	# =========================================================================
	if camera_pos.distance_to(player_pos) > 300.0:
		global_position = player_pos
		reset_smoothing() # Xóa sạch độ trễ ghìm ảnh của Godot
		return
	# =========================================================================

	# --- LỚP PHÒNG THỦ 2: LOGIC KÉO CAMERA QUA VÙNG CHẾT CHỮ NHẬT ---
	var half_w = dead_zone_size.x / 2.0
	var half_h = dead_zone_size.y / 2.0
	
	var delta_x = player_pos.x - camera_pos.x
	var delta_y = player_pos.y - camera_pos.y
	
	# Vị trí mục tiêu mặc định là giữ nguyên Camera
	var target_pos = camera_pos
	
	# Nếu Mèo bước qua vách trái/phải của hộp chữ nhật, tính toán vị trí Cam cần tới
	if abs(delta_x) > half_w:
		target_pos.x = player_pos.x - (sign(delta_x) * half_w)
		
	# Nếu Mèo bước qua vách trên/dưới của hộp chữ nhật
	if abs(delta_y) > half_h:
		target_pos.y = player_pos.y - (sign(delta_y) * half_h)
	
	# Thực hiện kéo Camera đi một cách mượt mà tiến về phía mép hộp
	global_position = global_position.lerp(target_pos, follow_speed * delta)

# --- XỬ LÝ LĂN CHUỘT ZOOM KHI ĐÈ CTRL ---
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				change_zoom(zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-zoom_speed)

func change_zoom(amount: int) -> void:
	current_zoom_level = clampi(current_zoom_level + amount, min_zoom, max_zoom)
	set_zoom_level(current_zoom_level)

func set_zoom_level(level: int) -> void:
	zoom = Vector2(level, level)
	queue_redraw()

func _draw() -> void:
	# Chỉ vẽ khung chữ nhật vàng để trực quan hóa trong màn hình Editor của ông
	if Engine.is_editor_hint():
		var half_w = dead_zone_size.x / 2.0
		var half_h = dead_zone_size.y / 2.0
		var rect = Rect2(-half_w, -half_h, dead_zone_size.x, dead_zone_size.y)
		draw_rect(rect, Color.YELLOW, false, 1.0 / current_zoom_level)
