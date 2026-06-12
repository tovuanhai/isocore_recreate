extends Node

var astar = AStar2D.new()

# Cost để đi qua 1 ô nước — cao hơn đất liền để A* ưu tiên đường bờ
const WATER_COST = 4.0
const LAND_COST = 1.0

func cell_to_id(cell: Vector2i) -> int:
	return (cell.x + 10000) + (cell.y + 10000) * 20000


# ----------------------------------------------
# QUẢN LÝ ĐỒ THỊ A*
# ----------------------------------------------
func update_grid(tile_map) -> void:
	astar.clear()

	for cell in tile_map.world_data.keys():
		_add_cell_to_astar(tile_map, cell)

	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for cell in tile_map.world_data.keys():
		var id = cell_to_id(cell)
		if not astar.has_point(id): continue
		var elev = _get_walkable_elevation(tile_map, cell)
		for dir in dirs:
			var neighbor = cell + dir
			var nid = cell_to_id(neighbor)
			if not astar.has_point(nid): continue
			var nelev = _get_walkable_elevation(tile_map, neighbor)
			if nelev != -1 and abs(elev - nelev) <= tolerance:
				if not astar.are_points_connected(id, nid):
					astar.connect_points(id, nid)


func update_chunk(tile_map, chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * tile_map.chunk_size
	var start_y = chunk_pos.y * tile_map.chunk_size
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	# Bước 1: Add các ô trong chunk
	for x in range(tile_map.chunk_size):
		for y in range(tile_map.chunk_size):
			_add_cell_to_astar(tile_map, Vector2i(start_x + x, start_y + y))

	# Bước 2: Nối + biên chunk lân cận
	for x in range(-1, tile_map.chunk_size + 1):
		for y in range(-1, tile_map.chunk_size + 1):
			var cell = Vector2i(start_x + x, start_y + y)
			var id = cell_to_id(cell)
			if not astar.has_point(id): continue
			var elev = _get_walkable_elevation(tile_map, cell)
			for dir in dirs:
				var neighbor = cell + dir
				var nid = cell_to_id(neighbor)
				if not astar.has_point(nid): continue
				var nelev = _get_walkable_elevation(tile_map, neighbor)
				if nelev != -1 and abs(elev - nelev) <= tolerance:
					if not astar.are_points_connected(id, nid):
						astar.connect_points(id, nid)


func update_cell_pathfinding(tile_map, cell: Vector2i) -> void:
	var id = cell_to_id(cell)

	# Nếu không walkable → xóa khỏi A*
	if not _is_walkable(tile_map, cell):
		if astar.has_point(id):
			astar.remove_point(id)
		return

	# Add nếu chưa có
	if not astar.has_point(id):
		_add_cell_to_astar(tile_map, cell)

	# Kết nối với hàng xóm
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var elev = _get_walkable_elevation(tile_map, cell)
	for dir in dirs:
		var neighbor = cell + dir
		var nid = cell_to_id(neighbor)
		if not astar.has_point(nid): continue
		var nelev = _get_walkable_elevation(tile_map, neighbor)
		if nelev != -1 and abs(elev - nelev) <= tolerance:
			if not astar.are_points_connected(id, nid):
				astar.connect_points(id, nid)


func remove_cell(cell: Vector2i) -> void:
	var id = cell_to_id(cell)
	if astar.has_point(id):
		astar.remove_point(id)


# ============================================================
# HELPER: Tách logic walkable + elevation ra 1 chỗ
# ============================================================

func _is_walkable(tile_map, cell: Vector2i) -> bool:
	if not tile_map.world_data.has(cell): return false
	var data = tile_map.world_data[cell]
	# Nước: walkable ở mặt trên (water_level), không bị block bởi obstacle
	if data.get("is_water", false): return true
	# Đất: không có obstacle
	var elev = data["z"]
	return not tile_map.has_obstacle(cell, elev)


func _get_walkable_elevation(tile_map, cell: Vector2i) -> int:
	if not tile_map.world_data.has(cell): return -1
	var data = tile_map.world_data[cell]
	# Nước luôn đi ở mặt water_level, không phải đáy
	if data.get("is_water", false): return tile_map.water_level
	return data["z"]


func _add_cell_to_astar(tile_map, cell: Vector2i) -> void:
	if not _is_walkable(tile_map, cell): return
	var id = cell_to_id(cell)
	if astar.has_point(id): return

	# Dùng water_level làm elevation cho ô nước
	var walk_elev = _get_walkable_elevation(tile_map, cell)
	var local_pos = tile_map.base_ground.map_to_local(cell)
	# Tính global pos theo walk_elev để path nằm đúng mặt nước
	var elev_offset = Vector2(0, -walk_elev * tile_map.cliff_height)
	var gpos = tile_map.base_ground.to_global(local_pos) + elev_offset
	astar.add_point(id, gpos)

	# Weighting: ô nước đắt hơn để A* ưu tiên đường bờ
	var data = tile_map.world_data[cell]
	if data.get("is_water", false):
		astar.set_point_weight_scale(id, WATER_COST)
	else:
		astar.set_point_weight_scale(id, LAND_COST)


# ----------------------------------------------
# PATH
# ----------------------------------------------
func get_path_cells(start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var start_id = cell_to_id(start_cell)
	var target_id = cell_to_id(target_cell)

	if not astar.has_point(start_id) or not astar.has_point(target_id):
		return []

	var id_path = astar.get_id_path(start_id, target_id)
	var cell_path: Array[Vector2i] = []
	for id in id_path:
		var y = int(id / 20000) - 10000
		var x = int(id % 20000) - 10000
		cell_path.append(Vector2i(x, y))

	if cell_path.size() > 0:
		cell_path.remove_at(0)

	return cell_path


# ----------------------------------------------
# HỖ TRỢ TƯƠNG TÁC & DI CHUYỂN
# ----------------------------------------------
func find_closest_interactable_neighbor(start_cell: Vector2i, target_cell: Vector2i, tile_map) -> Vector2i:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var best_cell = Vector2i(-9999, -9999)
	var min_distance = INF
	var tolerance = tile_map.config.cliff_step_tolerance if tile_map.get("config") else 1

	for dir in dirs:
		var neighbor = target_cell + dir
		if not _is_walkable(tile_map, neighbor): continue
		# Không đứng trên nước để tương tác
		if tile_map.world_data.get(neighbor, {}).get("is_water", false): continue
		var elev = _get_walkable_elevation(tile_map, neighbor)
		var target_elev = _get_walkable_elevation(tile_map, target_cell)
		if abs(elev - target_elev) <= tolerance:
			var dist = start_cell.distance_to(neighbor)
			if dist < min_distance:
				min_distance = dist
				best_cell = neighbor

	return best_cell


func move_along_path(player, tile_map, delta: float, speed: float, is_swimming: bool) -> String:
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if not is_swimming and player.interact_type != "":
			return "Interact"
		return "Idle"

	var target = player.current_path[0]
	var cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var data = tile_map.world_data.get(cell, {})
	var is_water_cell = data.get("is_water", false)

	# Chuyển state dựa trên loại ô ĐANG ĐI VÀO
	if not is_swimming and is_water_cell: return "Swim"
	if is_swimming and not is_water_cell: return "Move"

	# Tính hướng TRƯỚC khi move
	var dir = (target - player.global_position).normalized()
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir.angle()))

	player.global_position = player.global_position.move_toward(target, speed * delta)

	var snap_threshold = tile_map.config.move_snap_threshold if tile_map.get("config") else 1.0
	if player.global_position.distance_to(target) < snap_threshold:
		player.global_position = target
		player.current_path.remove_at(0)
		GameEvents.player_moved.emit(player, cell, tile_map.get_cell_elevation(cell))

	# Dùng walk animation tạm khi chưa có swim animation
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)

	return ""
