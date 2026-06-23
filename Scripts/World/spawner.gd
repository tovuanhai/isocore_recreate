extends Node

var hub: Node2D

# 🎯 HỆ THỐNG TIME SLICING
var render_queue: Array[Vector2i] = []
@export var max_render_time_msec: int = 5 

func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func _process(_delta: float) -> void:
	if render_queue.is_empty(): return
		
	var start_time = Time.get_ticks_msec()
	
	while not render_queue.is_empty():
		var pos_2d = render_queue.pop_back() 
		render_voxel_column(pos_2d)
		
		if Time.get_ticks_msec() - start_time >= max_render_time_msec:
			break

func enqueue_chunk_render(cells: Array) -> void:
	render_queue.append_array(cells)

func render_voxel_column(pos_2d: Vector2i) -> void:
	if not hub.world_data.has(pos_2d): return
	var data = hub.world_data[pos_2d]
	
	# z ở đây chính là BỀ MẶT ĐẤT CỨNG (Trên bờ thì là Đỉnh Đồi, Dưới nước thì là Đáy Biển)
	var z = data["z"] 
	var is_water = data.get("is_water", false)
	
	var start_h = z 
	
	var dirs = [
		Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)
	]
	
	for d in dirs:
		var n_pos = pos_2d + d
		if hub.world_data.has(n_pos):
			var n_z = hub.world_data[n_pos]["z"]
			if n_z < start_h:
				start_h = n_z
		else:
			start_h = 0 

	start_h = maxi(0, start_h - 1) 

	# 1. VẼ ĐẤT/ĐÁ (Vẽ từ start_h lên tới z)
	for h in range(start_h, z + 1):
		var current_biome = "dirt"
		# Chỉ lợp cỏ/cát/tuyết ở bề mặt trên cùng trên cạn
		if h == z and not is_water:
			current_biome = data["biome"]
			
		var tile_options = hub.biomes[current_biome]
		var noise_seed = hub.world_generator.density_noise.seed
		var dot_product = (pos_2d.x * 12.9898) + (pos_2d.y * 78.233) + noise_seed
		var fraction = abs(sin(dot_product) * 43758.5453) - floor(abs(sin(dot_product) * 43758.5453))
		var chosen_tile = tile_options[int(fraction * tile_options.size())]
		
		hub.ground_layers[h].set_cell(pos_2d, 0, chosen_tile)
	
	# =========================================================
	# 2. VẼ NƯỚC (CHỈ VẼ DUY NHẤT 1 TẤM KÍNH Ở MẶT NƯỚC)
	# =========================================================
	# 🎯 ĐÃ SỬA: Cứ đất nào lún thấp hơn mặt nước là auto bị ngập!
	if is_water or z < hub.water_level:
		hub.water_layers[hub.water_level].set_cell(pos_2d, 0, hub.water_tile)
	
	# 3. SINH ĐỒ VẬT
	if data.has("object") and data["object"] != "none":
		if hub.object_scenes.has(data["object"]) and not hub.spawned_objects.has(pos_2d):
			spawn_object_scene(pos_2d, data["object"], z)

# ==============================================================================
# HÀM SINH/HỦY OBJECT GỐC (DÙNG INSTANTIATE TRUYỀN THỐNG)
# ==============================================================================
func spawn_object_scene(cell: Vector2i, object_name: String, z: int) -> void:
	if not object_name in hub.object_scenes or hub.spawned_objects.has(cell): return
	var scene_res = load("res://Scenes/" + object_name + ".tscn")
	if not scene_res: return

	var obj = scene_res.instantiate()
	hub.add_child(obj)
	obj.position = hub.base_ground.map_to_local(cell)

	if obj.has_method("init"): obj.call("init", z, hub.cliff_height)
	if obj.has_method("set_cell"): obj.call("set_cell", cell)

	hub.spawned_objects[cell] = obj

# Dọn dẹp Chunk cũng phải dọn luôn Water Layer
func unload_chunk_visuals(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size
	
	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var cell = Vector2i(start_x + x, start_y + y)
			for h in range(hub.max_elevation + 1):
				hub.ground_layers[h].set_cell(cell, -1)
				hub.water_layers[h].set_cell(cell, -1) # 🎯 THÊM DÒNG NÀY
				hub.object_layers[h].set_cell(cell, -1)
				
			if hub.spawned_objects.has(cell):
				if is_instance_valid(hub.spawned_objects[cell]):
					hub.spawned_objects[cell].queue_free()
				hub.spawned_objects.erase(cell)

# ==============================================================================
# HÀM SPAWN AN TOÀN KHI MỚI VÀO GAME
# ==============================================================================
func setup_safe_spawn() -> void:
	if not hub.player: return
	
	for cx in range(-2, 3):
		for cy in range(-2, 3):
			var chunk_pos = Vector2i(cx, cy)
			
			var chunk_data = hub.world_generator.generate_chunk_data(chunk_pos)
			
			for pos in chunk_data:
				hub.world_data[pos] = chunk_data[pos]
				
			for pos in chunk_data:
				render_voxel_column(pos)
				
			hub.chunk_manager.loaded_chunks[chunk_pos] = true
	
	hub.chunk_manager.current_chunk = Vector2i(0, 0)
	
	if MovementUtils and MovementUtils.has_method("update_chunk"):
		for cx in range(-2, 3):
			for cy in range(-2, 3):
				MovementUtils.update_chunk(hub, Vector2i(cx, cy))
	
	var spawn_cell : Vector2i = find_safe_spawn_cell()
	if spawn_cell == Vector2i(-9999, -9999): return
	
	var elev = hub.get_cell_elevation(spawn_cell)
	hub.player._last_elev_cell = spawn_cell
	hub.player.current_elevation = elev
	hub.player.elevation_float = float(elev)
	hub.player.global_position = hub.base_ground.to_global(hub.base_ground.map_to_local(spawn_cell))

func find_safe_spawn_cell() -> Vector2i:
	var cfg = hub.config
	var r = 32
	var best_cell := Vector2i.ZERO 
	var best_score := -999999
	var directions: Array[Vector2i] = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var cell := Vector2i(x, y)
			var elev : int = hub.get_cell_elevation(cell)
			if elev == -1 or elev <= hub.water_level: continue
			if hub.world_data.has(cell) and hub.world_data[cell].get("object", "none") != "none": continue
			
			var score : int = (hub.max_elevation - elev) * cfg.safe_spawn_elev_weight
			var flat_bonus := 0
			for dir in directions:
				var ne = hub.get_cell_elevation(cell + dir)
				if ne != -1 and abs(ne - elev) <= cfg.cliff_step_tolerance:
					flat_bonus += 1
			score += flat_bonus * cfg.safe_spawn_flat_bonus
			
			if score > best_score:
				best_score = score
				best_cell = cell
	return best_cell
