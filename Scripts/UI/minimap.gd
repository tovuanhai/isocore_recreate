extends ColorRect

@export var tile_map: Node2D 
@export var player: CharacterBody2D

# Cấu hình minimap
@export var map_scale: float = 3.0 
@export var vision_radius: int = 8 # Bán kính khám phá xung quanh người chơi

# Bảng màu (Đã thêm Tuyết)
var biome_colors = {
	"grass": Color("#62c54f"),
	"snow":  Color("#ffffff"), # Thêm màu trắng của tuyết
	"dirt":  Color("#634832"),
	"sand": Color("#f6d7b0")
}

# Màu riêng cho nước
var water_color = Color("35c4ba") 

# Lưu trữ các ô đã đi qua
var discovered_cells: Dictionary = {}

func _process(_delta: float) -> void:
	if not player or not tile_map: return
	
	# Mở khóa các ô xung quanh player
	var player_pos = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(player.global_position))
	for x in range(-vision_radius, vision_radius):
		for y in range(-vision_radius, vision_radius):
			var cell = player_pos + Vector2i(x, y)
			discovered_cells[cell] = true
			
	# Yêu cầu vẽ lại mỗi khung hình
	queue_redraw()

func _draw() -> void:
	if not player or not tile_map: return
	
	var center = size / 2.0
	var player_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(player.global_position))
	
	# 1. Vẽ lớp nền đen (Sương mù)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1a1a1a")) 
	
	# 2. Vẽ các ô đã khám phá
	# Quét một vùng hiển thị lớn hơn một chút so với bán kính nhìn
	for x in range(-20, 20):
		for y in range(-20, 20):
			var cell = player_cell + Vector2i(x, y)
			
			# Chỉ vẽ nếu đã khám phá và ô đó tồn tại trong map
			if discovered_cells.has(cell) and tile_map.world_data.has(cell):
				var data = tile_map.world_data[cell]
				var elev = data["z"]
				
				# 🌊 LUẬT MỚI: Check xem có phải là nước không
				var is_water = data.get("is_water", false)
				var base_color: Color
				
				if is_water:
					base_color = water_color
				else:
					base_color = biome_colors.get(data["biome"], Color(0.2, 0.2, 0.2))
				
				# Lấy màu gốc và điều chỉnh độ sáng theo độ cao (Đáy biển càng sâu -> càng tối)
				var brightness = 0.5 + (float(elev) / float(tile_map.max_elevation)) * 0.5
				var final_color = base_color
				final_color.v *= brightness
				
				# Tính vị trí vẽ
				var draw_pos = center + Vector2(x, y) * map_scale
				var rect_size = Vector2(map_scale, map_scale)
				
				# Vẽ ô
				draw_rect(Rect2(draw_pos - rect_size/2, rect_size), final_color)
	
	# 3. Vẽ chấm đại diện cho Player (Luôn hiện)
	draw_circle(center, 4.0, Color.YELLOW)
