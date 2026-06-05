extends Node

var astar = AStar2D.new()

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
	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var cell = Vector2i(x, y)
			var elev = tile_map.get_cell_elevation(cell)
			if elev != -1 and not tile_map.has_obstacle(cell, elev):
				var id = cell_to_id(cell)
				var world_pos = tile_map.base_ground.to_global(tile_map.base_ground.map_to_local(cell))
				astar.add_point(id, world_pos)
				walkable_cells.append({"cell": cell, "elev": elev, "id": id})
	
	# 🎯 CHÂN LÝ ĐI THẲNG ISOMETRIC: Khóa cứng 4 hướng di chuyển cạnh mặt thoi
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for data in walkable_cells:
		for dir in directions:
			var neighbor_cell = data.cell + dir
			var neighbor_id = cell_to_id(neighbor_cell)
			if astar.has_point(neighbor_id):
				var neighbor_elev = tile_map.get_cell_elevation(neighbor_cell)
				if neighbor_elev != -1 and abs(data.elev - neighbor_elev) <= 1:
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
