extends Node2D

@onready var base_ground: TileMapLayer = $Layer0
@onready var base_object: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

var world_data: Dictionary = {}
@export var chunk_size: int = 16
@export var render_distance: int = 2
@export var cliff_height: int = 6
@export var max_elevation: int = 13
@export var hover_face_height: int = 3

var ground_layers: Array[TileMapLayer] = []
var object_layers: Array[TileMapLayer] = []

# Từ điển quản lý các object đã sinh ra để xóa khi đi xa
var spawned_objects: Dictionary = {}

var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)],
	"sand": [Vector2i(7, 3), Vector2i(9, 3)],
	"dirt": [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]
}

var object_scenes = {
	# "tên_object": {"source_id": ID_CỦA_SCENE_COLLECTION, "alt_id": ID_CỦA_SCENE_BÊN_TRONG}
	"LightBulb": {"source_id": 4, "alt_id": 1},
	"rock1": {"source_id": 2, "alt_id": 1}
}

var hover_effect: Polygon2D
var biome_noise: FastNoiseLite
var elevation_noise: FastNoiseLite

var loaded_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i(9999, 9999)
var is_generating: bool = false

func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()
	setup_noises()
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
			o_layer.clear()
		else:
			g_layer = base_ground.duplicate(); g_layer.clear(); g_layer.name = "GroundLayer_" + str(i); add_child(g_layer)
			o_layer = base_object.duplicate(); o_layer.clear(); o_layer.name = "ObjectLayer_" + str(i); add_child(o_layer)
		
		# 1. Hình ảnh Layer bị đẩy lên không trung
		var elev_shift = cliff_height * i
		g_layer.position.y = -elev_shift
		o_layer.position.y = -elev_shift
		
		# 2. Đẩy Mốc Y-Sort ngược lại xuống đất để bằng với Z=0 (Player)
		g_layer.y_sort_origin = elev_shift
		o_layer.y_sort_origin = elev_shift     
		
		# 3. Tất cả mọi thứ phải nằm chung 1 mặt phẳng Z
		g_layer.z_index = 0
		o_layer.z_index = 0
		g_layer.y_sort_enabled = true
		o_layer.y_sort_enabled = true
		
		var t: float = float(i) / max_elevation
		var brightness: float = lerp(0.58, 1.0, t)
		var mod_color := Color(brightness, brightness * 0.97, brightness * 0.93, 1.0)
		g_layer.self_modulate = mod_color
		o_layer.self_modulate = mod_color
		
		ground_layers.append(g_layer)
		object_layers.append(o_layer)
		
		# Đẩy base_object xuống đáy cây Scene để nó luôn đè lên mặt cỏ khi trùng Y-Sort
		move_child(base_object, -1)

func setup_noises() -> void:
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.015
	
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi() + 777
	elevation_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	elevation_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	elevation_noise.frequency = 0.025 
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_PING_PONG

func _process(_delta: float) -> void:
	if not player or is_generating: return
	var player_cell = base_ground.local_to_map(base_ground.to_local(player.global_position))
	var player_chunk = Vector2i(floor(float(player_cell.x) / chunk_size), floor(float(player_cell.y) / chunk_size))
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks_async(current_chunk)
	handle_hover_effect()

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
			
			var voxel_pos_2d = Vector2i(global_x, global_y)
			# Chỉ sinh bề mặt
			if not world_data.has(voxel_pos_2d):
				var b_val = biome_noise.get_noise_2d(global_x, global_y)
				var biome_name = "grass"
				if b_val < -0.15: biome_name = "sand"
				elif b_val < 0.15: biome_name = "dirt"
				
				var e_val = elevation_noise.get_noise_2d(global_x, global_y)
				var normalized_e = pow((e_val + 1.0) / 2.0, 1.5)
				var elevation = clampi(int(normalized_e * (max_elevation + 1)), 0, max_elevation)
				
				# Tính toán logic Object xuất hiện
				var spawn_obj = "none"
				if biome_name == "grass": 
					var rand = randf()
					if rand < 0.05:      # 5% tỉ lệ mọc cây (Đèn)
						spawn_obj = "LightBulb"
					elif rand < 0.12:    # 7% tỉ lệ mọc đá
						spawn_obj = "rock1"
						
				world_data[voxel_pos_2d] = {
					"type": "ground", 
					"biome": biome_name, 
					"z": elevation,
					"object": spawn_obj
				}
					
			render_voxel_column(pos_2d)

func render_voxel_column(pos_2d: Vector2i) -> void:
	if world_data.has(pos_2d):
		var data = world_data[pos_2d]
		var z = data["z"]
		
		for h in range(z + 1):
			var tile_options = biomes[data["biome"]]
			var dot_product = (pos_2d.x * 12.9898) + (pos_2d.y * 78.233) + biome_noise.seed
			var fraction = abs(sin(dot_product) * 43758.5453) - floor(abs(sin(dot_product) * 43758.5453))
			var chosen_tile = tile_options[int(fraction * tile_options.size())]
			
			ground_layers[h].set_cell(pos_2d, 0, chosen_tile)
			
			if data.has("object") and data["object"] != "none":
				if h == z:
					if object_scenes.has(data["object"]) and not spawned_objects.has(pos_2d):
						spawn_object_scene(pos_2d, data["object"], z)



func unload_chunk_visuals(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * chunk_size
	var start_y = chunk_pos.y * chunk_size
	
	for x in range(chunk_size):
		for y in range(chunk_size):
			var cell = Vector2i(start_x + x, start_y + y)
			
			for h in range(max_elevation + 1):
				ground_layers[h].set_cell(cell, -1)
				object_layers[h].set_cell(cell, -1)
				
			if spawned_objects.has(cell):
				var item = spawned_objects[cell]
				if typeof(item) == TYPE_DICTIONARY:
					if is_instance_valid(item.main):
						item.main.queue_free()
					for s in item.slices:
						if is_instance_valid(s):
							s.queue_free()
				else:
					if is_instance_valid(item):
						item.queue_free()
						
				spawned_objects.erase(cell)




func get_cell_elevation(cell: Vector2i) -> int:
	if world_data.has(cell): return world_data[cell]["z"]
	return -1

func render_north_cliff_outline(cell: Vector2i, current_elev: int, layer_index: int) -> void:
	var north_cell = cell + Vector2i(0, -1)
	var north_elev = get_cell_elevation(north_cell)
	
	# Chỉ vẽ outline nếu phía Bắc thấp hơn
	if north_elev != -1 and north_elev < current_elev:
		# Ở đây bạn cần có tile "north outline" trong tileset
		# Ví dụ: dùng source_id = 0, atlas_coords của tile viền bắc
		ground_layers[layer_index].set_cell(cell, 0, Vector2i(0, 3))  # ← thay bằng tile outline của bạn

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	if world_data.has(cell):
		var data = world_data[cell]
		
		# 1. Lệch độ cao (Vách đá) -> Không đi được
		if data["z"] != elevation: 
			return true
			
		# 2. Ô đó có cây hoặc đá -> Không đi được
		if data.get("object", "none") != "none":
			return true
			
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
	var base_layer = base_ground 
	
	for z in range(max_elevation, -1, -1):
		var elev_shift = cliff_height * z
		var layer_mouse_pos = mouse_pos + Vector2(0, elev_shift)
		
		var cell = base_layer.local_to_map(base_layer.to_local(layer_mouse_pos))
		if world_data.has(cell) and world_data[cell]["z"] >= z:
			best_cell = cell
			break 
			
	return best_cell

func handle_hover_effect() -> void:
	var cell = get_hovered_tile()
	if cell != Vector2i(-9999, -9999):
		var top_elev = get_cell_elevation(cell)
		if top_elev >= 0 and top_elev < ground_layers.size():
			var target_layer = ground_layers[top_elev]
			hover_effect.global_position = target_layer.to_global(target_layer.map_to_local(cell))
			hover_effect.visible = true
			
			# Logic check chướng ngại vật
			if has_obstacle(cell, top_elev):
				hover_effect.color = Color(1.0, 0.0, 0.0, 0.5) 
			else:
				hover_effect.color = Color(1.0, 1.0, 1.0, 0.5)
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
	
	var elev := get_cell_elevation(spawn_cell)
	player._last_elev_cell = spawn_cell
	player.current_elevation = elev
	player.elevation_float = float(elev)
	
	player.global_position = base_ground.to_global(base_ground.map_to_local(spawn_cell))

func find_safe_spawn_cell() -> Vector2i:
	var best_cell: Vector2i = Vector2i(-9999, -9999)
	var best_score: int = -999999
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for x in range(-64, 65):
		for y in range(-64, 65):
			var cell: Vector2i = Vector2i(x, y)
			var elev: int = get_cell_elevation(cell)
			if elev == -1: continue
			
			var score: int = (max_elevation - elev) * 120
			var flat_bonus: int = 0
			for dir in directions:
				var nc = cell + dir
				var ne = get_cell_elevation(nc)
				if ne != -1 and abs(ne - elev) <= 1:
					flat_bonus += 1
			score += flat_bonus * 25
			
			if score > best_score:
				best_score = score
				best_cell = cell
	return best_cell

# 🎯 CÔNG THỨC JOHNBRX HOÀN CHỈNH 🎯
#func spawn_object_scene(cell: Vector2i, object_name: String, z: int) -> void:
	#if not object_scenes.has(object_name): return
	#
	#var scene_path = "res://Scenes/" + object_name + ".tscn"
	#var scene_res = load(scene_path)
	#if not scene_res: return
	#
	#var obj_instance = scene_res.instantiate()
	#
	## 1. Thêm vào làm CON của TileMap (Chung mâm với Player, thoát khỏi ma trận TileMapLayer)
	#self.add_child(obj_instance)
	#
	## 2. Đặt vị trí vật lý sát mặt phẳng Y=0
	#obj_instance.position = base_ground.map_to_local(cell)
	#
	##obj_instance.z_index = z
	#
	## 3. KÉO MỖI HÌNH ẢNH LÊN NÚI (Công thức John)
	#var offset_y = -(z * cliff_height)
	#for child in obj_instance.get_children():
		## Chỉ nhấc hình ảnh/ánh sáng, BỎ QUA các khung va chạm vật lý
		#if child is Node2D and not child is CollisionShape2D and not child is CollisionPolygon2D:
			#child.position.y += offset_y
			#
	## 4. Lưu vào danh sách để quản lý bộ nhớ
	#spawned_objects[cell] = obj_instance
# 🎯 CÔNG THỨC JOHNBRX HOÀN CHỈNH (PHIÊN BẢN TỐI ƯU GODOT 4) 🎯



func spawn_object_scene(cell: Vector2i, object_name: String, z: int) -> void:
	if not object_scenes.has(object_name) or spawned_objects.has(cell):
		return

	var scene_res = load("res://Scenes/" + object_name + ".tscn")
	if not scene_res:
		return

	var obj = scene_res.instantiate()
	
	# Gọi init trước để nó tự cắt lát
	if obj.has_method("init"):
		obj.call("init", z)

	# Ném gốc đèn vào đúng tầng đất của nó
	object_layers[z].add_child(obj)
	var flat_pos = base_ground.map_to_local(cell)
	obj.position = flat_pos

	var tracked_slices = []

	# PHÂN PHÁT LÁT CẮT LÊN TRỜI
	for child in obj.get_children():
		if child is Sprite2D and child.name.begins_with("JohnSlice_"):
			var slice_index = child.name.get_slice("_", 1).to_int()
			var target_z = z + slice_index
			
			if target_z > max_elevation:
				target_z = max_elevation
				
			if target_z == z:
				continue
				
			var local_pos = child.position
			var original_offset = child.offset
			
			# Chuyển nhà sang Layer tương ứng với độ cao đỉnh đèn
			obj.remove_child(child)
			object_layers[target_z].add_child(child)
			
			# 🎯 BÙ TRỪ TUYỆT ĐỐI:
			# - Giữ nguyên position (Y-Sort) bằng cách cộng dồn flat_pos.
			# - Đẩy offset xuống đúng bằng lượng Layer nhấc lên (diff_y).
			child.position = flat_pos + local_pos
			
			var diff_y = (target_z - z) * cliff_height
			child.offset = original_offset + Vector2(0, diff_y)
			
			tracked_slices.append(child)

	spawned_objects[cell] = {
		"main": obj,
		"slices": tracked_slices
	}
