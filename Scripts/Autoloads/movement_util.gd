extends Node

var astar = AStar2D.new()

# Chuyển đổi tọa độ Vector2i thành ID duy nhất không trùng lặp
func cell_to_id(cell: Vector2i) -> int:
	return (cell.x + 10000) + (cell.y + 10000) * 20000

func update_grid(tile_map: Node2D) -> void:
	astar.clear()
	var chunk_size = tile_map.chunk_size
	var current_chunk = tile_map.current_chunk
	var r = tile_map.render_distance
	
	var start_x = (current_chunk.x - r) * chunk_size
	var start_y = (current_chunk.y - r) * chunk_size
	var end_x = (current_chunk.x + r + 1) * chunk_size
	var end_y = (current_chunk.y + r + 1) * chunk_size
	
	var walkable_cells = []
	
	# Bước 1: Đăng ký toàn bộ các điểm nút hợp pháp lên không gian phẳng
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var cell = Vector2i(x, y)
			var elev = tile_map.get_cell_elevation(cell)
			
			if elev != -1 and not tile_map.has_obstacle(cell, elev):
				var id = cell_to_id(cell)
				var local_pos = tile_map.base_ground.map_to_local(cell)
				var global_pos = tile_map.base_ground.to_global(local_pos)
				
				astar.add_point(id, global_pos)
				walkable_cells.append({"cell": cell, "elev": elev, "id": id})
	
	# Bước 2: Khóa cứng di chuyển 4 hướng (Tương đương DIAGONAL_MODE_NEVER)
	# Chỉ định danh sách 4 hướng ngang dọc của mặt thoi Isometric
	var cardinal_directions = [
		Vector2i(1, 0),   # Đông Nam
		Vector2i(-1, 0),  # Tây Bắc
		Vector2i(0, 1),   # Tây Nam
		Vector2i(0, -1)   # Đông Bắc
	]
	
	# Bước 3: Xét duyệt điều kiện chiều cao để nối đường
	for data in walkable_cells:
		for dir in cardinal_directions:
			var neighbor_cell = data.cell + dir
			var neighbor_id = cell_to_id(neighbor_cell)
			
			if astar.has_point(neighbor_id):
				var neighbor_elev = tile_map.get_cell_elevation(neighbor_cell)
				
				# KIỂM TRA VÁCH ĐÁ: Chỉ nối cạnh nếu chênh lệch độ cao <= 1 tầng
				if neighbor_elev != -1 and (abs(data.elev - neighbor_elev) <= tile_map.config.cliff_step_tolerance):
					astar.connect_points(data.id, neighbor_id)

func get_path_cells(start_cell: Vector2i, end_cell: Vector2i) -> Array[Vector2i]:
	var start_id = cell_to_id(start_cell)
	var end_id = cell_to_id(end_cell)
	if not astar.has_point(start_id) or not astar.has_point(end_id): return []
		
	var id_path = astar.get_id_path(start_id, end_id)
	var result_path: Array[Vector2i] = []
	
	for id in id_path:
		var y = int(id / 20000) - 10000
		var x = (id % 20000) - 10000
		result_path.append(Vector2i(x, y))
	return result_path

func move_along_path(player, tile_map, delta: float, speed: float, is_swimming: bool) -> String:
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if not is_swimming and player.has_pending_mine:
			return "Mine"
		return "Idle"

	var target = player.current_path[0]
	var cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var elev = tile_map.get_cell_elevation(cell)

	# --- KIỂM TRA ĐỊA HÌNH → Đề xuất đổi state ---
	if elev != -1:
		if not is_swimming and elev <= tile_map.water_level:
			return "Swim"
		if is_swimming and elev > tile_map.water_level:
			return "Move"

	# --- DI CHUYỂN ---
	var dir = player.global_position.direction_to(target)
	player.global_position = player.global_position.move_toward(target, speed * delta)

	if player.global_position.distance_to(target) < tile_map.config.move_snap_threshold:
		player.global_position = target
		player.current_path.remove_at(0)
		
		# Báo cáo ô mới
		GameEvents.player_moved_to_cell.emit(player, cell, tile_map.get_cell_elevation(cell))
	
	# --- ANIMATION (Utils lo, State không cần đụng) ---
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir.angle()))
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)

	return "" # Không cần đổi state
