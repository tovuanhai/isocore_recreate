extends Label

# Bắt cầu trực tiếp ra ngoài Scene gốc để lấy dữ liệu từ 2 hệ thống cốt lõi
@onready var player = $"../../Player"
@onready var tile_map = $"../../TileMap"

func _process(_delta: float) -> void:
	# 1. Hiển thị FPS
	var debug_text = "FPS: %d\n" % Engine.get_frames_per_second()
	debug_text += "------------------------\n"
	
	if player and tile_map and tile_map.get("base_ground"):
		# 2. LẤY THÔNG TIN PLAYER
		var p_pos = player.global_position
		var base_layer = tile_map.base_ground
		# Ép tọa độ thực về tọa độ ô vuông trên mặt phẳng Tầng 0
		var p_cell = base_layer.local_to_map(base_layer.to_local(p_pos))
		var p_elev = player.current_elevation
		
		debug_text += "PLAYER:\n"
		debug_text += "- Tọa độ thực: (%.1f, %.1f)\n" % [p_pos.x, p_pos.y]
		debug_text += "- Vị trí ô lưới: [X: %d | Y: %d | Z: %d]\n" % [p_cell.x, p_cell.y, p_elev]
		# 🎯 DÒNG MỚI: Truy xuất trực tiếp z_index của con mèo
		debug_text += "- Z-Index: %d\n" % player.z_index 
		debug_text += "------------------------\n"
		
		# 3. LẤY THÔNG TIN Ô GẠCH ĐANG HOVER
		var hover_cell = tile_map.get_hovered_tile()
		
		debug_text += "HOVER TILE:\n"
		if hover_cell != Vector2i(-9999, -9999):
			# Nếu chuột đang chỉ trúng một khối đất
			var hover_z = tile_map.get_cell_elevation(hover_cell)
			debug_text += "- Tọa độ Voxel: [X: %d | Y: %d | Z: %d]\n" % [hover_cell.x, hover_cell.y, hover_z]
			
			# 🎯 DÒNG MỚI: Truy xuất z_index của chính Layer đang được Hover
			var layer_z_index = 0
			# Kiểm tra an toàn để tránh crash nếu layer chưa kịp khởi tạo
			if hover_z >= 0 and hover_z < tile_map.ground_layers.size():
				layer_z_index = tile_map.ground_layers[hover_z].z_index
				
			debug_text += "- Z-Index Layer: %d" % layer_z_index
		else:
			# Nếu chuột chỉ ra ngoài khoảng không vũ trụ
			debug_text += "- Đang chỉ vào: Hư vô (Void)"
			
	# Gắn toàn bộ cụm text này lên màn hình
	text = debug_text	
