extends Node2D

@onready var layer0: TileMapLayer = $Layer0 
@onready var layer1: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

@export var chunk_size: int = 16
@export var render_distance: int = 2 

# ==========================================================
# 🌍 BỘ TỪ ĐIỂN BIOME (GIỮ NGUYÊN VARIATION CỦA ÔNG)
# ==========================================================
var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)], 
	"sand":  [Vector2i(7, 3), Vector2i(9, 3)],                 
	"dirt":  [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]  
}

var hover_effect: Polygon2D
var biome_noise: FastNoiseLite 

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
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	# Mẹo: Giảm frequency xuống một chút (0.01) để các mảng Biome rộng lớn và rõ ràng hơn
	biome_noise.frequency = 0.025 
	
	backup_editor_objects()
	
	layer0.clear()
	layer1.clear()
	setup_hover_polygon()
	
	if player:
		handle_world_generation()

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

# ==========================================================
# BỘ MÁY OPEN WORLD CHUNK SYSTEM (ASYNC)
# ==========================================================
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

	for pos in chunks_to_remove:
		loaded_chunks.erase(pos)

	for chunk_pos in chunks_needed.keys():
		if not loaded_chunks.has(chunk_pos):
			generate_chunk(chunk_pos)
			await get_tree().process_frame 

	MovementUtils.update_grid(layer0, layer1)
	is_generating = false

# ==========================================================
# 🧠 THUẬT TOÁN SINH BIOME CHUYỂN TIẾP TUYẾN TÍNH
# ==========================================================
func generate_chunk(chunk_pos: Vector2i) -> void:
	loaded_chunks[chunk_pos] = true 

	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	var has_saved_data = chunk_data.has(chunk_pos)
	var saved_layer1 = chunk_data.get(chunk_pos, {})

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var cell = Vector2i(global_x, global_y)
			
			# 1. PHÂN LỚP TUYẾN TÍNH: Ép nối chuỗi Cát -> Đất -> Cỏ
			var b_val = biome_noise.get_noise_2d(global_x, global_y)
			var biome_name = "grass"
			
			if b_val < -0.15:
				biome_name = "sand"  # Vùng thấp nhất (ví dụ bãi biển/vực cát)
			elif b_val < 0.15:
				biome_name = "dirt"  # Vùng trung gian (Đất luôn kẹp giữa Cát và Cỏ)
			else:
				biome_name = "grass" # Vùng cao/sâu trong đất liền (Cỏ xanh)
				
			# 2. CHỌN VARIANT (Giữ nguyên thuật toán chống kẻ sọc dọc của ông)
			var tile_options = biomes[biome_name]
			var dot_product = (global_x * 12.9898) + (global_y * 78.233) + biome_noise.seed
			var pseudo_rand = abs(sin(dot_product) * 43758.5453)
			var fraction = pseudo_rand - floor(pseudo_rand)
			
			var random_index = int(fraction * tile_options.size())
			var chosen_tile_coords = tile_options[random_index]
			
			var ground_source_id = 0 
			layer0.set_cell(cell, ground_source_id, chosen_tile_coords)
			
			if has_saved_data and saved_layer1.has(cell):
				var data = saved_layer1[cell]
				layer1.set_cell(cell, data["id"], data["coords"], data.get("alt", 0))

func unload_chunk(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	var current_layer1_data = {}

	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var cell = Vector2i(global_x, global_y)
			
			var source_id = layer1.get_cell_source_id(cell)
			if source_id != -1:
				current_layer1_data[cell] = {
					"id": source_id,
					"coords": layer1.get_cell_atlas_coords(cell),
					"alt": layer1.get_cell_alternative_tile(cell)
				}
			
			layer0.set_cell(cell, -1)
			layer1.set_cell(cell, -1)
			
	if current_layer1_data.size() > 0:
		chunk_data[chunk_pos] = current_layer1_data
	elif chunk_data.has(chunk_pos):
		chunk_data.erase(chunk_pos)

# ==========================================================
# HỆ THỐNG HOVER
# ==========================================================
func setup_hover_polygon() -> void:
	hover_effect = Polygon2D.new()
	hover_effect.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-8, 0)
	])
	hover_effect.color = Color(1, 1, 1, 0.4)
	hover_effect.y_sort_enabled = false 
	hover_effect.top_level = true       
	hover_effect.z_index = 100          
	hover_effect.visible = true
	add_child(hover_effect)

func get_hovered_tile() -> Vector2i:
	var mouse_pos = get_local_mouse_position()
	return layer0.local_to_map(mouse_pos)

func handle_hover_effect() -> void:
	var tile_pos = get_hovered_tile()
	var local_pos = layer0.map_to_local(tile_pos)
	
	hover_effect.global_position = layer0.to_global(local_pos)
	hover_effect.visible = true

	if layer1.get_cell_source_id(tile_pos) != -1:
		hover_effect.color = Color(1, 0, 0, 0.6) 
	else:
		hover_effect.color = Color(1, 1, 1, 0.4)
