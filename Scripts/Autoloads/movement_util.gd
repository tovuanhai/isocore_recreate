extends Node

var astar = AStar2D.new()

const WATER_COST = 4.0
const LAND_COST = 1.0

func cell_to_id(cell: Vector2i) -> int:
	return (cell.x + 10000) + (cell.y + 10000) * 20000

# ============================================================
# 1. QUẢN LÝ ĐỒ THỊ A* (TỐI ƯU O(N) LỤC ĐỊA, CHỐNG LEO VÁCH)
# ============================================================
func update_grid(tile_map) -> void:
	astar.clear()
	for cell in tile_map.world_data.keys(): 
		_add_cell_to_astar(tile_map, cell)
	
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for cell in tile_map.world_data.keys():
		_connect_cell_to_neighbors(tile_map, cell, tolerance, dirs)

func update_chunk(tile_map, chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * tile_map.chunk_size
	var start_y = chunk_pos.y * tile_map.chunk_size
	
	# Thêm điểm
	for x in range(tile_map.chunk_size):
		for y in range(tile_map.chunk_size):
			_add_cell_to_astar(tile_map, Vector2i(start_x + x, start_y + y))
			
	# Nối điểm (+1 ô rìa)
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for x in range(-1, tile_map.chunk_size + 1):
		for y in range(-1, tile_map.chunk_size + 1):
			var cell = Vector2i(start_x + x, start_y + y)
			_connect_cell_to_neighbors(tile_map, cell, tolerance, dirs)

func update_cell_pathfinding(tile_map, cell: Vector2i) -> void:
	var id = cell_to_id(cell)
	if not _is_walkable(tile_map, cell):
		if astar.has_point(id): astar.remove_point(id)
		return
		
	if not astar.has_point(id): 
		_add_cell_to_astar(tile_map, cell)
		
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	_connect_cell_to_neighbors(tile_map, cell, tolerance, dirs)

func remove_cell(cell: Vector2i) -> void:
	var id = cell_to_id(cell)
	if astar.has_point(id): astar.remove_point(id)

func _connect_cell_to_neighbors(tile_map, cell: Vector2i, tolerance: int, dirs: Array) -> void:
	var id = cell_to_id(cell)
	if not astar.has_point(id): return
	
	var elev = _get_walkable_elevation(tile_map, cell)
	
	for dir in dirs:
		var neighbor = cell + dir
		var nid = cell_to_id(neighbor)
		if not astar.has_point(nid): continue
		
		var nelev = _get_walkable_elevation(tile_map, neighbor)
		if nelev == -1: continue
		
		# KHÓA LEO VÁCH DỰNG ĐỨNG
		if abs(elev - nelev) > tolerance:
			continue 
			
		if not astar.are_points_connected(id, nid):
			astar.connect_points(id, nid)

func _is_walkable(tile_map, cell: Vector2i) -> bool:
	if not tile_map.world_data.has(cell): return false
	var data = tile_map.world_data[cell]
	if data.get("is_water", false): return true
	if data.get("object", "none") != "none": return false
	var elev = data["z"]
	return not tile_map.has_obstacle(cell, elev)

func _get_walkable_elevation(tile_map, cell: Vector2i) -> int:
	if not tile_map.world_data.has(cell): return -1
	var data = tile_map.world_data[cell]
	if data.get("is_water", false): return tile_map.water_level
	return data["z"]

func _add_cell_to_astar(tile_map, cell: Vector2i) -> void:
	if not _is_walkable(tile_map, cell): return
	var id = cell_to_id(cell)
	if astar.has_point(id): return

	var local_pos = tile_map.base_ground.map_to_local(cell)
	var gpos = tile_map.base_ground.to_global(local_pos) 
	astar.add_point(id, gpos)

	var data = tile_map.world_data[cell]
	if data.get("is_water", false):
		astar.set_point_weight_scale(id, WATER_COST)
	else:
		astar.set_point_weight_scale(id, LAND_COST)

func get_path_cells(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var start_id = cell_to_id(start_cell)
	var target_id = cell_to_id(target_cell)
	if not astar.has_point(start_id) or not astar.has_point(target_id): return []

	var id_path = astar.get_id_path(start_id, target_id)
	var cell_path: Array[Vector2i] = []
	for id in id_path:
		var y = int(id / 20000) - 10000
		var x = int(id % 20000) - 10000
		cell_path.append(Vector2i(x, y))

	if cell_path.size() > 0: cell_path.remove_at(0)
	return cell_path

func find_closest_interactable_neighbor(start_cell: Vector2i, target_cell: Vector2i, tile_map) -> Vector2i:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var best_cell = Vector2i(-9999, -9999)
	var min_distance = INF
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1

	for dir in dirs:
		var neighbor = target_cell + dir
		if not _is_walkable(tile_map, neighbor): continue
		if tile_map.world_data.get(neighbor, {}).get("is_water", false): continue
		var elev = _get_walkable_elevation(tile_map, neighbor)
		var target_elev = _get_walkable_elevation(tile_map, target_cell)
		if abs(elev - target_elev) <= tolerance:
			var dist = start_cell.distance_to(neighbor)
			if dist < min_distance:
				min_distance = dist
				best_cell = neighbor
	return best_cell


# ============================================================
# CỖ MÁY QUỸ ĐẠO CHÍNH (ĐỒNG BỘ MÁY TRẠNG THÁI)
# ============================================================

# 🎯 HÀM A: DỰNG ĐƯỜNG ĐI CHUẨN ISOCORE (Alt + Click)
func build_path_for_player(player, tile_map, target_tile: Vector2i) -> void:
	var current_cell = player.get_current_cell()
	if not _is_walkable(tile_map, target_tile):
		target_tile = find_closest_interactable_neighbor(current_cell, target_tile, tile_map)
		
	if target_tile != Vector2i(-9999, -9999):
		var cell_path = get_path_cells(current_cell, target_tile)
		player.current_path.clear()
		
		if not cell_path.is_empty():
			var start_local = tile_map.base_ground.map_to_local(current_cell)
			var start_global = tile_map.base_ground.to_global(start_local)
			
			if player.global_position.distance_to(start_global) > 1.5:
				player.current_path.append(start_global)
			
			for cl in cell_path:
				var local_p = tile_map.base_ground.map_to_local(cl)
				var global_p = tile_map.base_ground.to_global(local_p)
				player.current_path.append(global_p)

# 🎯 CHUYÊN GIA KIỂM TRA VA CHẠM VÁCH NÚI (Trả về hướng trượt Slide)
func get_slide_direction(player, tile_map, iso_dir: Vector2, speed: float, delta: float) -> Vector2:
	var current_cell = player.get_current_cell()
	var curr_z = _get_walkable_elevation(tile_map, current_cell)
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var look_ahead = speed * delta * 2.0 
	
	# Trượt X
	var test_x = player.global_position + Vector2(iso_dir.x * look_ahead, 0)
	var cell_x = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(test_x))
	if cell_x != current_cell:
		var z_x = _get_walkable_elevation(tile_map, cell_x)
		if not _is_walkable(tile_map, cell_x) or z_x == -1 or abs(z_x - curr_z) > tolerance:
			iso_dir.x = 0 

	# Trượt Y
	var test_y = player.global_position + Vector2(0, iso_dir.y * look_ahead)
	var cell_y = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(test_y))
	if cell_y != current_cell:
		var z_y = _get_walkable_elevation(tile_map, cell_y)
		if not _is_walkable(tile_map, cell_y) or z_y == -1 or abs(z_y - curr_z) > tolerance:
			iso_dir.y = 0 
			
	return iso_dir.normalized()

# ============================================================
# HOẠT HỌA 8 HƯỚNG ISOMETRIC
# ============================================================
func _get_8_way_dir_string(angle: float) -> String:
	if angle >= -22.5 and angle < 22.5: return "r"
	elif angle >= 22.5 and angle < 67.5: return "dr"
	elif angle >= 67.5 and angle < 112.5: return "d"
	elif angle >= 112.5 and angle < 157.5: return "dl"
	elif angle >= 157.5 or angle < -157.5: return "l"
	elif angle >= -157.5 and angle < -112.5: return "ul"
	elif angle >= -112.5 and angle < -67.5: return "u"
	elif angle >= -67.5 and angle < -22.5: return "ur"
	return "dr"

func _play_directional_animation(player, prefix: String, direction_suffix: String) -> void:
	if not is_instance_valid(player.anim_player): return
	var anim_name = prefix + direction_suffix
	
	if not player.anim_player.has_animation(anim_name):
		var fallback = direction_suffix
		match direction_suffix:
			"r": fallback = "dr"
			"l": fallback = "dl"
			"u": fallback = "ur"
			"d": fallback = "dl"
		anim_name = prefix + fallback

	if player.anim_player.has_animation(anim_name) and player.anim_player.current_animation != anim_name:
		player.anim_player.play(anim_name)
