extends Node2D

@onready var base_ground: TileMapLayer = $Layer0
@onready var base_object: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

# ==========================================================
# 🧠 VOXEL CORE DATA ARCHITECTURE
# ==========================================================
var world_data: Dictionary = {}
@export var chunk_size: int = 16
@export var render_distance: int = 2
@export var cliff_height: int = 6
@export var max_elevation: int = 5
@export var hover_face_height: int = 3

# Hệ số JohnBrx để dịch chuyển mốc phân lớp ảo cho từng tầng gạch
var z_sort_boost: int = 4

var ground_layers: Array[TileMapLayer] = []
var object_layers: Array[TileMapLayer] = []

var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)],
	"sand": [Vector2i(7, 3), Vector2i(9, 3)],
	"dirt": [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]
}

var rock_cluster_thresholds = {"grass": 0.42, "dirt": 0.38, "sand": 0.55}
var auto_rock_source_id: int = -1
var auto_rock_alternative_id: int = -1

var hover_effect: Polygon2D
var biome_noise: FastNoiseLite
var rock_noise: FastNoiseLite
var elevation_noise: FastNoiseLite

var loaded_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i(9999, 9999)
var is_generating: bool = false


func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()
	setup_noises()
	auto_detect_rock_ids()
	setup_hover_polygon()
	
	if player:
		setup_safe_spawn()


func setup_elevation_layers() -> void:
	y_sort_enabled = true
	ground_layers.clear()
	object_layers.clear()
	
	for i in range(max_elevation + 1):
		var g_layer: TileMapLayer
		var o_layer: TileMapLayer
		
		if i == 0:
			g_layer = base_ground
			o_layer = base_object
		else:
			g_layer = base_ground.duplicate()
			g_layer.clear()
			g_layer.name = "GroundLayer_" + str(i)
			add_child(g_layer)
			
			o_layer = base_object.duplicate()
			o_layer.clear()
			o_layer.name = "ObjectLayer_" + str(i)
			add_child(o_layer)
		
		var elev_shift = cliff_height * i
		g_layer.position.y = -elev_shift
		o_layer.position.y = -elev_shift
		
		# Áp dụng công thức dịch mốc Y-Sort để các lớp đan cài vào nhau
		g_layer.y_sort_origin = elev_shift + (i * z_sort_boost) - 1
		o_layer.y_sort_origin = elev_shift + (i * z_sort_boost)
		
		var t: float = float(i) / max_elevation
		var brightness: float = lerp(0.58, 1.0, t)
		var mod_color := Color(brightness, brightness * 0.97, brightness * 0.93, 1.0)
		
		# 🎯 TẢO THANH NHIỄM MÀU: Dùng self_modulate để chỉ nhuộm màu gạch, không nhuộm Player!
		g_layer.self_modulate = mod_color
		o_layer.self_modulate = mod_color
		
		g_layer.y_sort_enabled = true
		o_layer.y_sort_enabled = true
		g_layer.z_index = 0
		o_layer.z_index = 0
		
		ground_layers.append(g_layer)
		object_layers.append(o_layer)


func setup_noises() -> void:
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.01
	
	rock_noise = FastNoiseLite.new()
	rock_noise.seed = randi() + 1234
	rock_noise.frequency = 0.08
	
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi() + 777
	elevation_noise.frequency = 0.015


func auto_detect_rock_ids() -> void:
	var tileset = base_object.tile_set
	if not tileset: return
	for i in tileset.get_source_count():
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		if source is TileSetScenesCollectionSource and source.get_scene_tiles_count() > 0:
			auto_rock_source_id = source_id
			auto_rock_alternative_id = source.get_scene_tile_id(0)
			return


func _process(_delta: float) -> void:
	handle_world_generation()
	handle_hover_effect()


func handle_world_generation() -> void:
	if not player or is_generating: return
	var player_cell = base_ground.local_to_map(base_ground.to_local(player.global_position))
	var player_chunk = Vector2i(floor(float(player_cell.x) / chunk_size), floor(float(player_cell.y) / chunk_size))
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
			unload_chunk_visuals(loaded_pos)
			chunks_to_remove.append(loaded_pos)
	await get_tree().process_frame
	for pos in chunks_to_remove: loaded_chunks.erase(pos)
	for chunk_pos in chunks_needed.keys():
		if not loaded_chunks.has(chunk_pos):
			generate_chunk_data_and_render(chunk_pos)
			await get_tree().process_frame
	if MovementUtils and MovementUtils.has_method("update_grid"):
		MovementUtils.update_grid(self)
	is_generating = false


func generate_chunk_data_and_render(chunk_pos: Vector2i) -> void:
	loaded_chunks[chunk_pos] = true
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var pos_2d = Vector2i(global_x, global_y)
			if not world_data.has(Vector3i(global_x, global_y, 0)):
				var b_val = biome_noise.get_noise_2d(global_x, global_y)
				var biome_name = "grass"
				if b_val < -0.15: biome_name = "sand"
				elif b_val < 0.15: biome_name = "dirt"
				var e_val = elevation_noise.get_noise_2d(global_x, global_y)
				var normalized_e = (e_val + 1.0) / 2.0
				var elevation = clampi(int(normalized_e * (max_elevation + 1)), 0, max_elevation)
				var has_rock = false
				if auto_rock_source_id != -1:
					var r_noise_val = rock_noise.get_noise_2d(global_x, global_y)
					var threshold = rock_cluster_thresholds.get(biome_name, 0.5)
					if r_noise_val > threshold:
						var edge_dot = (global_x * 45.13) + (global_y * 91.27) + rock_noise.seed
						var edge_rand = abs(sin(edge_dot) * 43758.5453) - floor(abs(sin(edge_dot) * 43758.5453))
						if edge_rand < 0.85: has_rock = true
				for z in range(elevation + 1):
					var voxel_pos = Vector3i(global_x, global_y, z)
					world_data[voxel_pos] = {"type": "ground", "biome": biome_name}
					if z == elevation and has_rock:
						world_data[voxel_pos]["object"] = auto_rock_source_id
			render_voxel_column(pos_2d)


func render_voxel_column(pos_2d: Vector2i) -> void:
	for z in range(max_elevation + 1):
		var voxel_pos = Vector3i(pos_2d.x, pos_2d.y, z)
		if world_data.has(voxel_pos):
			var data = world_data[voxel_pos]
			var tile_options = biomes[data["biome"]]
			var dot_product = (pos_2d.x * 12.9898) + (pos_2d.y * 78.233) + biome_noise.seed
			var fraction = abs(sin(dot_product) * 43758.5453) - floor(abs(sin(dot_product) * 43758.5453))
			var chosen_tile = tile_options[int(fraction * tile_options.size())]
			ground_layers[z].set_cell(pos_2d, 0, chosen_tile)
			if data.has("object") and data["object"] != -1:
				object_layers[z].set_cell(pos_2d, data["object"], Vector2i(0, 0), auto_rock_alternative_id)


func unload_chunk_visuals(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	for x in range(chunk_size):
		for y in range(chunk_size):
			var cell = Vector2i(start_x + x, start_y + y)
			for h in range(max_elevation + 1):
				ground_layers[h].set_cell(cell, -1)
				object_layers[h].set_cell(cell, -1)


func get_cell_elevation(cell: Vector2i) -> int:
	for z in range(max_elevation, -1, -1):
		if world_data.has(Vector3i(cell.x, cell.y, z)): return z
	return -1


func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	var voxel_pos = Vector3i(cell.x, cell.y, elevation)
	if world_data.has(voxel_pos):
		return world_data[voxel_pos].has("object") and world_data[voxel_pos]["object"] != -1
	return false


func setup_hover_polygon() -> void:
	hover_effect = Polygon2D.new()
	hover_effect.polygon = PackedVector2Array([Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-8, 0)])
	hover_effect.color = Color(1, 1, 1, 0.4)
	hover_effect.top_level = true
	hover_effect.z_index = 100
	add_child(hover_effect)


func get_hovered_tile() -> Vector2i:
	var mouse_pos = get_global_mouse_position()
	var best_cell = Vector2i(-9999, -9999)
	var max_sort_value = -999999.0
	var base_cell = base_ground.local_to_map(base_ground.to_local(mouse_pos))
	
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var cell = base_cell + Vector2i(dx, dy)
			var max_z = get_cell_elevation(cell)
			if max_z == -1: continue
			for z in range(0, max_z + 1):
				var top_center = ground_layers[z].to_global(ground_layers[z].map_to_local(cell))
				var p_top = top_center + Vector2(0, -4)
				var p_right = top_center + Vector2(8, 0)
				var p_bottom = top_center + Vector2(0, 4)
				var p_left = top_center + Vector2(-8, 0)
				
				var v_bottom = p_bottom + Vector2(0, hover_face_height)
				var v_left = p_left + Vector2(0, hover_face_height)
				var v_right = p_right + Vector2(0, hover_face_height)
				var poly = PackedVector2Array([p_top, p_right, v_right, v_bottom, v_left, p_left])
				
				if Geometry2D.is_point_in_polygon(mouse_pos, poly):
					var sort_value = (cell.x + cell.y) * 1000 + z
					if sort_value > max_sort_value:
						max_sort_value = sort_value
						best_cell = cell
	return best_cell


func handle_hover_effect() -> void:
	var cell = get_hovered_tile()
	if cell != Vector2i(-9999, -9999):
		var top_elev = get_cell_elevation(cell)
		hover_effect.global_position = ground_layers[top_elev].to_global(ground_layers[top_elev].map_to_local(cell))
		hover_effect.visible = true
		if has_obstacle(cell, top_elev): hover_effect.color = Color(1, 0, 0, 0.6)
		else: hover_effect.color = Color(1, 1, 1, 0.4)
	else:
		hover_effect.visible = false


func setup_safe_spawn() -> void:
	if not player: return
	for cx in range(-2, 3):
		for cy in range(-2, 3):
			generate_chunk_data_and_render(Vector2i(cx, cy))
	
	current_chunk = Vector2i(0, 0)
	var spawn_cell := find_safe_spawn_cell()
	if spawn_cell == Vector2i(-9999, -9999): return
	
	var local_pos := base_ground.map_to_local(spawn_cell)
	player.global_position = base_ground.to_global(local_pos)
	
	var elev := get_cell_elevation(spawn_cell)
	player._last_elev_cell = spawn_cell
	player.current_elevation = elev
	
	# Đăng ký hộ khẩu tầng xuất phát đầu game chuẩn chỉ
	if elev < object_layers.size():
		player.call_deferred("reparent", object_layers[elev])


func find_safe_spawn_cell() -> Vector2i:
	var best_cell: Vector2i = Vector2i(-9999, -9999)
	var best_score: int = -999999
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for x in range(-64, 65):
		for y in range(-64, 65):
			var cell: Vector2i = Vector2i(x, y)
			var elev: int = get_cell_elevation(cell)
			if elev == -1 or has_obstacle(cell, elev): continue
			var score: int = (max_elevation - elev) * 120
			var flat_bonus: int = 0
			for dir in directions:
				var nc = cell + dir
				var ne = get_cell_elevation(nc)
				if ne != -1 and not has_obstacle(nc, ne) and abs(ne - elev) <= 1:
					flat_bonus += 1
			score += flat_bonus * 25
			if score > best_score:
				best_score = score
				best_cell = cell
	return best_cell
