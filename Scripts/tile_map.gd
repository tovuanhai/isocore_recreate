extends Node2D

@onready var layer0: TileMapLayer = $Layer0 
@onready var layer1: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

@export var chunk_size: int = 16
@export var render_distance: int = 2 

# ==========================================================
# 🌍 BỘ TỪ ĐIỂN ĐẤT NỀN (LAYER 0)
# ==========================================================
var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)], 
	"sand":  [Vector2i(7, 3), Vector2i(9, 3)],                 
	"dirt":  [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]  
}

# ==========================================================
# 🪨 CẤU HÌNH ĐỘ DÀY CỦA MỎ ĐÁ THEO CỤM
# Ngưỡng càng thấp -> Cụm đá xuất hiện càng nhiều và càng to rộng.
# Mặc định tớ để 0.42 cho bãi cỏ để ông đi vài bước là va phải mỏ đá ngay!
# ==========================================================
var rock_cluster_thresholds = {
	"grass": 0.42,  # Ngưỡng mọc cụm trên cỏ (0.42 = Cụm vừa phải, dễ gặp)
	"dirt":  0.38,  # Ngưỡng mọc cụm trên đất (0.38 = Thấp hơn cỏ -> mỏ đá to và dày hơn)
	"sand":  0.55   # Ngưỡng mọc cụm trên cát (0.55 = Rất cao -> hiếm khi có cụm đá)
}

var auto_rock_source_id: int = -1
var auto_rock_alternative_id: int = -1

var hover_effect: Polygon2D
var biome_noise: FastNoiseLite 
var rock_noise: FastNoiseLite # 🌫️ LỚP NHIỄU CHUYÊN BIỆT TẠO CỤM ĐÁ

var loaded_chunks: Dictionary = {} 
var chunk_data: Dictionary = {}    
var current_chunk: Vector2i = Vector2i(9999, 9999)
var is_generating: bool = false

func _ready() -> void:
	y_sort_enabled = true
	layer0.y_sort_enabled = true
	layer1.y_sort_enabled = true
	
	layer0.y_sort_origin = 4
	layer1.y_sort_origin = 4
	
	# 1. Cấu hình lớp nhiễu cho Quần xã (Biomes)
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.01 
	
	# 2. Cấu hình lớp nhiễu cho Đá Cụm (Rock Clusters)
	rock_noise = FastNoiseLite.new()
	rock_noise.seed = randi() + 1234 # Khác seed với biome để bãi đá mọc ngẫu nhiên tự do
	rock_noise.frequency = 0.08      # Tần số cao giúp tạo ra các mạch mỏ đá nhỏ gom lại một vùng độc lập
	
	auto_detect_rock_ids()
	backup_editor_objects()
	
	layer0.clear()
	layer1.clear()
	setup_hover_polygon()
	
	if player:
		handle_world_generation()

func auto_detect_rock_ids() -> void:
	var tileset = layer1.tile_set
	if not tileset: return
	for i in tileset.get_source_count():
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source is TileSetScenesCollectionSource:
			if source.get_scene_tiles_count() > 0:
				auto_rock_source_id = source_id
				auto_rock_alternative_id = source.get_scene_tile_id(0)
				print("✅ [HỆ THỐNG]: Máy cụm đã khóa mục tiêu Đá! ID: ", auto_rock_source_id)
				return

func backup_editor_objects() -> void:
	for cell in layer1.get_used_cells():
		var cx = floor(float(cell.x) / chunk_size)
		var cy = floor(float(cell.y) / chunk_size)
		var chunk_pos = Vector2i(cx, cy)
		if not chunk_data.has(chunk_pos):
			chunk_data[chunk_pos] = {}
		chunk_data[chunk_pos][cell] = {
			"id": layer1.get_cell_source_id(cell),
			"coords": layer1.get_cell_atlas_coords(cell),
			"alt": layer1.get_cell_alternative_tile(cell)
		}

func _process(_delta: float) -> void:
	handle_world_generation()
	handle_hover_effect()

func handle_world_generation() -> void:
	if not player or is_generating: return
	var player_cell = layer0.local_to_map(layer0.to_local(player.global_position))
	var player_chunk = Vector2i(
		floor(float(player_cell.x) / chunk_size),
		floor(float(player_cell.y) / chunk_size)
	)
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks_async(current_chunk)

func update_chunks_async(center: Vector2i) -> void:
	is_generating = true
	var chunks_needed: Dictionary = {}
	for x in range(-render_distance, render_distance + 1):
		for y in range(-render_distance, render_distance + 1):
			chunks_needed[center + Vector2i(x, y)] = true
	var chunks_to_remove: Array = []
	for loaded_pos in loaded_chunks.keys():
		if not chunks_needed.has(loaded_pos):
			unload_chunk(loaded_pos)
			chunks_to_remove.append(loaded_pos)
			await get_tree().process_frame 
	for pos in chunks_to_remove: loaded_chunks.erase(pos)
	for chunk_pos in chunks_needed.keys():
		if not loaded_chunks.has(chunk_pos):
			generate_chunk(chunk_pos)
			await get_tree().process_frame 
	MovementUtils.update_grid(layer0, layer1)
	is_generating = false

# ==========================================================
# 🧠 THUẬT TOÁN TẠO CỤM ĐÁ MẢNH (CLUSTER GENERATION)
# ==========================================================
func generate_chunk(chunk_pos: Vector2i) -> void:
	loaded_chunks[chunk_pos] = true 
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	var chunk_cells_saved = chunk_data.get(chunk_pos, {})

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var cell = Vector2i(global_x, global_y)
			
			# 1. SINH BIOME NỀN
			var b_val = biome_noise.get_noise_2d(global_x, global_y)
			var biome_name = "grass"
			if b_val < -0.15: biome_name = "sand"
			elif b_val < 0.15: biome_name = "dirt"
			else: biome_name = "grass"
				
			var tile_options = biomes[biome_name]
			var dot_product = (global_x * 12.9898) + (global_y * 78.233) + biome_noise.seed
			var pseudo_rand = abs(sin(dot_product) * 43758.5453)
			var fraction = pseudo_rand - floor(pseudo_rand)
			
			layer0.set_cell(cell, 0, tile_options[int(fraction * tile_options.size())])
			
			# 2. BỘ LỌC ĐÁ THEO MẠCH CỤM
			if chunk_cells_saved.has(cell):
				var data = chunk_cells_saved[cell]
				if data["id"] != -1:
					layer1.set_cell(cell, data["id"], data["coords"], data["alt"])
			else:
				if auto_rock_source_id != -1:
					# Lấy giá trị nhiễu cụm tại ô gạch này (-1.0 đến 1.0)
					var r_noise_val = rock_noise.get_noise_2d(global_x, global_y)
					var threshold = rock_cluster_thresholds.get(biome_name, 0.5)
					
					# Nếu vượt ngưỡng -> Ô này nằm trong "Mạch khoáng"
					if r_noise_val > threshold:
						# Thêm một bước băm nhiễu rìa (Edge Noise) để mỏ đá có ô trống xen kẽ tự nhiên
						var edge_dot = (global_x * 45.13) + (global_y * 91.27) + rock_noise.seed
						var edge_rand = abs(sin(edge_dot) * 43758.5453) - floor(abs(sin(edge_dot) * 43758.5453))
						
						# Tỷ lệ giữ lại đá trong cụm là 85%, tạo ra vài khoảng hở nhỏ đi lại giữa mỏ đá
						if edge_rand < 0.85:
							layer1.set_cell(cell, auto_rock_source_id, Vector2i(0, 0), auto_rock_alternative_id)

func unload_chunk(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	var current_layer1_data = chunk_data.get(chunk_pos, {})
	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var cell = Vector2i(global_x, global_y)
			current_layer1_data[cell] = {
				"id": layer1.get_cell_source_id(cell),
				"coords": layer1.get_cell_atlas_coords(cell),
				"alt": layer1.get_cell_alternative_tile(cell)
			}
			layer0.set_cell(cell, -1)
			layer1.set_cell(cell, -1)
	chunk_data[chunk_pos] = current_layer1_data

# ==========================================================
# HỆ THỐNG HOVER CHUỘT
# ==========================================================
func setup_hover_polygon() -> void:
	hover_effect = Polygon2D.new()
	hover_effect.polygon = PackedVector2Array([Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-8, 0)])
	hover_effect.color = Color(1, 1, 1, 0.4)
	hover_effect.top_level = true       
	hover_effect.z_index = 100          
	add_child(hover_effect)

func get_hovered_tile() -> Vector2i:
	return layer0.local_to_map(get_local_mouse_position())

func handle_hover_effect() -> void:
	var tile_pos = get_hovered_tile()
	hover_effect.global_position = layer0.to_global(layer0.map_to_local(tile_pos))
	if layer1.get_cell_source_id(tile_pos) != -1: hover_effect.color = Color(1, 0, 0, 0.6) 
	else: hover_effect.color = Color(1, 1, 1, 0.4)
