extends ColorRect

@onready var tile_map: Node2D = $"/root/Root/TileMap"
@onready var player: CharacterBody2D = $"/root/Root/Player"

@export var map_scale: float = 2.0 # Giữ nguyên scale mượt hôm trước ông chỉnh

# ==========================================================
# 🌫️ HỆ THỐNG SƯƠNG MÙ BẢN ĐỒ (FOG OF WAR)
# ==========================================================
var discovered_cells: Dictionary = {} # Nơi lưu những ô gạch Player đã mở khóa
@export var vision_radius: int = 7    # Bán kính soi sáng của Player (ví dụ: tầm nhìn đuốc là 7 ô)

var tile_colors = {
	"grass": Color("#d1a66e"),  # Màu cỏ úa
	"sand":  Color("#a9c1ce"),  # Màu cát xám
	"dirt":  Color("#7b473c"),  # Màu đất nâu đỏ
	"stone": Color("#cc1111"),  # Màu đỏ vật cản
	"unknown": Color(0, 0, 0, 0)
}

func _ready() -> void:
	# Ép nền ColorRect thành màu đen đặc bí ẩn của Core Keeper
	color = Color("#0c0c0c") 
	queue_redraw()

func _process(_delta: float) -> void:
	if not player or not tile_map: return
	
	# 1. THUẬT TOÁN MỞ KHÓA SƯƠNG MÙ
	var player_cell = tile_map.layer0.local_to_map(tile_map.layer0.to_local(player.global_position))
	
	# Quét một vùng hình vuông (hoặc tròn) xung quanh chân con mèo để kích hoạt "đã khám phá"
	for x in range(-vision_radius, vision_radius + 1):
		for y in range(-vision_radius, vision_radius + 1):
			var target_cell = player_cell + Vector2i(x, y)
			
			# Nếu ô này chưa có trong danh sách đã đi qua -> Ghi nhớ lại ngay!
			if not discovered_cells.has(target_cell):
				discovered_cells[target_cell] = true
				
	# 2. CẬP NHẬT VẼ LẠI UI LÊN MÀN HÌNH
	queue_redraw()

func _draw() -> void:
	if not player or not tile_map: return
	
	var player_cell = tile_map.base_ground.local_to_map(tile_map.baseground.to_local(player.global_position))
	var center_offset = size / 2.0
	
	# Tính toán số ô gạch nằm vừa khít trong khung UI của ông
	var max_cells_x = int((size.x / map_scale) / 2) + 1
	var max_cells_y = int((size.y / map_scale) / 2) + 1
	
	for x in range(-max_cells_x, max_cells_x):
		for y in range(-max_cells_y, max_cells_y):
			var current_cell = player_cell + Vector2i(x, y)
			
			# KHÓA CHÍ CHÚ: Chỉ vẽ ô gạch lên Minimap nếu ô đó NẰM TRONG vùng đã khám phá!
			if discovered_cells.has(current_cell):
				var color_to_draw = get_tile_color_at(current_cell)
				if color_to_draw.a == 0: continue
				
				var pixel_pos = center_offset + Vector2(x, y) * map_scale
				draw_rect(Rect2(pixel_pos, Vector2(map_scale, map_scale)), color_to_draw)
			# Nếu chưa đi qua -> Bỏ trống hoàn toàn để lộ ra cái nền đen đặc của ColorRect

func get_tile_color_at(cell: Vector2i) -> Color:
	if tile_map.layer1.get_cell_source_id(cell) != -1:
		return tile_colors["stone"]
		
	var source_id = tile_map.layer0.get_cell_source_id(cell)
	if source_id == -1:
		return tile_colors["unknown"]
		
	var atlas_coords = tile_map.layer0.get_cell_atlas_coords(cell)
	
	for biome_name in tile_map.biomes.keys():
		if atlas_coords in tile_map.biomes[biome_name]:
			return tile_colors[biome_name]
			
	return tile_colors["unknown"]
