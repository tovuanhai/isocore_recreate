extends Node

@onready var hub = get_parent()

func render_voxel_column(pos_2d: Vector2i) -> void:
	if hub.world_data.has(pos_2d):
		var data = hub.world_data[pos_2d]
		var z = data["z"]
		
		for h in range(z + 1):
			var tile_options = hub.biomes[data["biome"]]
			# Lấy seed từ biome_noise của WorldGenerator
			var noise_seed = hub.world_generator.biome_noise.seed
			var dot_product = (pos_2d.x * 12.9898) + (pos_2d.y * 78.233) + noise_seed
			var fraction = abs(sin(dot_product) * 43758.5453) - floor(abs(sin(dot_product) * 43758.5453))
			var chosen_tile = tile_options[int(fraction * tile_options.size())]
			
			hub.ground_layers[h].set_cell(pos_2d, 0, chosen_tile)
			
			if data.has("object") and data["object"] != "none":
				if h == z:
					if hub.object_scenes.has(data["object"]) and not hub.spawned_objects.has(pos_2d):
						spawn_object_scene(pos_2d, data["object"], z)

func spawn_object_scene(cell: Vector2i, object_name: String, z: int) -> void:
	if not hub.object_scenes.has(object_name) or hub.spawned_objects.has(cell):
		return

	var scene_res = load("res://Scenes/" + object_name + ".tscn")
	if not scene_res:
		return

	var obj = scene_res.instantiate()
	# Ném thẳng ra Giám Đốc (tile_map) để chung mâm Y-Sort với Player
	hub.add_child.call_deferred(obj)
	
	# Khóa cứng va chạm vào đúng tâm ô lưới
	obj.position = hub.base_ground.map_to_local(cell)

	if obj.has_method("init"):
		obj.call("init", z, hub.cliff_height)

	hub.spawned_objects[cell] = obj

func unload_chunk_visuals(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size
	
	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var cell = Vector2i(start_x + x, start_y + y)
			
			for h in range(hub.max_elevation + 1):
				hub.ground_layers[h].set_cell(cell, -1)
				hub.object_layers[h].set_cell(cell, -1)
				
			if hub.spawned_objects.has(cell):
				if is_instance_valid(hub.spawned_objects[cell]):
					hub.spawned_objects[cell].queue_free()
				hub.spawned_objects.erase(cell)

# ====== LOGIC TÌM ĐIỂM HỒI SINH ======
func setup_safe_spawn() -> void:
	if not hub.player: return
	for cx in range(-2, 3):
		for cy in range(-2, 3):
			hub.world_generator.generate_chunk_data_and_render(Vector2i(cx, cy))
	
	hub.chunk_manager.current_chunk = Vector2i(0, 0)
	var spawn_cell := find_safe_spawn_cell()
	if spawn_cell == Vector2i(-9999, -9999): return
	
	var elev := get_cell_elevation(spawn_cell)
	hub.player._last_elev_cell = spawn_cell
	hub.player.current_elevation = elev
	hub.player.elevation_float = float(elev)
	
	hub.player.global_position = hub.base_ground.to_global(hub.base_ground.map_to_local(spawn_cell))

func find_safe_spawn_cell() -> Vector2i:
	var best_cell: Vector2i = Vector2i(-9999, -9999)
	var best_score: int = -999999
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for x in range(-64, 65):
		for y in range(-64, 65):
			var cell: Vector2i = Vector2i(x, y)
			var elev: int = get_cell_elevation(cell)
			if elev == -1: continue
			
			var score: int = (hub.max_elevation - elev) * 120
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

func get_cell_elevation(cell: Vector2i) -> int:
	if hub.world_data.has(cell): return hub.world_data[cell]["z"]
	return -1
