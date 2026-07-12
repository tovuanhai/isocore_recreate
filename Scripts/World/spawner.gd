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
			# 🎯 Bèo thì phải nổi ở mặt nước (water_level), cây cối trên bờ thì lấy z bề mặt
			var obj_z = hub.water_level if is_water else z
			spawn_object_scene(pos_2d, data["object"], obj_z)

	# =========================================================
	# 🎯 4. ĐÃ SỬA: GỌI HÀM KẺ VIỀN SAU KHI VẼ XONG MỌI THỨ
	# =========================================================
	update_cell_highlight(pos_2d)
	# Cập nhật luôn 2 ô phía trước mặt để vá lỗi rách viền ở ranh giới Chunk
	update_cell_highlight(pos_2d + Vector2i(1, 0))
	update_cell_highlight(pos_2d + Vector2i(0, 1))

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

func unload_chunk_visuals(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size
	
	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var cell = Vector2i(start_x + x, start_y + y)
			
			# 🚨 CHỈ DỌN NHỮNG Ô CÓ TỒN TẠI DỮ LIỆU
			if not hub.world_data.has(cell): continue
			var z = hub.world_data[cell]["z"]
			
			# 🚨 CHỈ XÓA TỪ TẦNG 0 ĐẾN TẦNG Z (Tránh vòng lặp mù quáng 40 lần)
			for h in range(z + 1):
				hub.ground_layers[h].set_cell(cell, -1)
				hub.water_layers[h].set_cell(cell, -1)
				hub.object_layers[h].set_cell(cell, -1)
				hub.highlight_layers[h].set_cell(cell, -1)
				
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

# ==============================================================================
# 🎯 HỆ THỐNG KẺ VIỀN SÁNG CHUẨN XÁC ĐẾN TỪNG PIXEL
# ==============================================================================
func update_cell_highlight(pos_2d: Vector2i) -> void:
	if not hub.world_data.has(pos_2d): return
	var data = hub.world_data[pos_2d]
	var z = data["z"]
	var is_water = data.get("is_water", false)

	# Dọn rác viền cũ
	for h in range(hub.max_elevation + 1):
		hub.highlight_layers[h].set_cell(pos_2d, -1)

	if is_water: return 

	var get_surface_z = func(cell: Vector2i) -> int:
		if hub.world_data.has(cell):
			var c_data = hub.world_data[cell]
			return hub.water_level if c_data.get("is_water", false) else c_data["z"]
		return z 

	# ---------------------------------------------------------
	# 🎯 ĐÃ SỬA: NHỜ ENGINE GODOT TỰ ĐỘNG TÌM HÀNG XÓM
	# Hàm get_neighbor_cell() giải quyết triệt để lỗi sai lệch trục!
	# ---------------------------------------------------------
	var nw_cell = hub.base_ground.get_neighbor_cell(pos_2d, TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE)
	var ne_cell = hub.base_ground.get_neighbor_cell(pos_2d, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE)
	
	# Ô Góc Bắc (Tít đằng sau) chính là hàng xóm Đông Bắc của ô Tây Bắc
	var n_cell = hub.base_ground.get_neighbor_cell(nw_cell, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE)

	var z_nw = get_surface_z.call(nw_cell)
	var z_ne = get_surface_z.call(ne_cell)
	var z_n  = get_surface_z.call(n_cell)

	# Lệnh check: Lớp hiện tại (z) phải LỚN HƠN layer của mấy thằng đằng sau
	var exposed_left = z > z_nw
	var exposed_right = z > z_ne
	var exposed_north = z > z_n

	if exposed_left or exposed_right:
		var final_coords = Vector2i(-1, -1)
		
		# 🛠️ NẾU VIỀN TRÁI/PHẢI BỊ NGƯỢC, ÔNG ĐỔI CHỖ (4,1) VÀ (5,1) CHO NHAU
		var tile_both  = Vector2i(3, 1) # Góc ^
		var tile_left  = Vector2i(4, 1) # Viền /
		var tile_right = Vector2i(5, 1) # Viền \
		
		if exposed_left and exposed_right: 
			final_coords = tile_both
		elif exposed_left: 
			final_coords = tile_left
		elif exposed_right: 
			final_coords = tile_right
			
		if final_coords != Vector2i(-1, -1):
			hub.highlight_layers[z].set_cell(pos_2d, 0, final_coords)

# ==============================================================================
# 🎯 CẬP NHẬT VIỀN CHO CHÍNH NÓ VÀ CÁC Ô BỊ ẢNH HƯỞNG PHÍA TRƯỚC
# ==============================================================================
func update_surrounding_highlights(pos_2d: Vector2i) -> void:
	# 1. Cập nhật chính nó (Trường hợp nó bị lún lộ vách)
	update_cell_highlight(pos_2d)
	
	# 2. Cập nhật 3 ô đằng trước (Tây Nam, Đông Nam và Góc Nam). 
	# Khi pos_2d bị đào lún xuống, 3 ô này sẽ bị lộ vách đá sau lưng chúng ra!
	var sw_cell = hub.base_ground.get_neighbor_cell(pos_2d, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE)
	var se_cell = hub.base_ground.get_neighbor_cell(pos_2d, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE)
	var s_cell = hub.base_ground.get_neighbor_cell(pos_2d, TileSet.CELL_NEIGHBOR_BOTTOM_CORNER)
	
	update_cell_highlight(sw_cell)
	update_cell_highlight(se_cell)
	update_cell_highlight(s_cell)
