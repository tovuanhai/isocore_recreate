extends Label

## Bắt cầu trực tiếp ra ngoài Scene gốc để lấy dữ liệu từ 2 hệ thống cốt lõi
@onready var player = $"../../Player"
@onready var tile_map = $"../../TileMap"

func _ready():
	visible = true

func _input(event):
	if event.is_action_pressed("debug"):
		visible = !visible

func _process(_delta: float) -> void:
	if visible:
		DebugMenu.style = DebugMenu.Style.VISIBLE_DETAILED
	else:
		DebugMenu.style = DebugMenu.Style.HIDDEN
		
	# 1. Hiển thị FPS
	var debug_text = "FPS: %d\n" % Engine.get_frames_per_second()
	debug_text += "------------------------\n"
	
	if player and tile_map and tile_map.get("base_ground"):
		var world_data = tile_map.get("world_data") 
		
		# ==========================================
		# 2. LẤY THÔNG TIN PLAYER
		# ==========================================
		var p_pos = player.global_position
		var base_layer = tile_map.base_ground
		var p_cell = base_layer.local_to_map(base_layer.to_local(p_pos))
		var p_elev = player.current_elevation
		
		# 🎯 ĐÃ SỬA: Check Nước trước khi check Biome
		var p_biome_display = "N/A"
		if world_data != null and world_data.has(p_cell):
			var data = world_data[p_cell]
			if data.get("is_water", false):
				p_biome_display = "Lake (Hồ)" if data.get("is_lake_zone", false) else "Ocean (Biển)"
			else:
				p_biome_display = str(data.get("biome", "N/A")).capitalize()
		
		debug_text += "PLAYER:\n"
		debug_text += "- Vị trí ô lưới: [X: %d | Y: %d | Z: %d]\n" % [p_cell.x, p_cell.y, p_elev]
		debug_text += "- Biome: %s\n" % p_biome_display
		debug_text += "------------------------\n"
		
		# ==========================================
		# 3. LẤY THÔNG TIN Ô GẠCH ĐANG HOVER
		# ==========================================
		var hover_cell = tile_map.get_hovered_tile()
		
		debug_text += "HOVER TILE:\n"
		if hover_cell != Vector2i(-9999, -9999):
			
			# 🎯 ĐÃ SỬA: Check Nước cho vùng chuột chỉ
			var h_biome_display = "N/A"
			if world_data != null and world_data.has(hover_cell):
				var data = world_data[hover_cell]
				if data.get("is_water", false):
					h_biome_display = "Lake (Hồ)" if data.get("is_lake_zone", false) else "Ocean (Biển)"
				else:
					h_biome_display = str(data.get("biome", "N/A")).capitalize()
				
			debug_text += "- Biome: %s\n" % h_biome_display
			
		else:
			debug_text += "- Đang chỉ vào: Hư vô (Void)\n"
			
	# Gắn toàn bộ cụm text này lên màn hình
	text = debug_text
