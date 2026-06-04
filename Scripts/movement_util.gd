class_name MovementUtils
extends Node

static var astar: AStarGrid2D

static func update_grid(layer0: TileMapLayer, layer1: TileMapLayer) -> void:
	if not astar:
		astar = AStarGrid2D.new()
		astar.cell_size = Vector2(16, 8)
		# SỬA Ở ĐÂY: Cấm tiệt A* đi chéo. Bắt buộc phải đi ziczac theo tâm các viên gạch (Grid X/Y)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER

	var rect = layer0.get_used_rect()
	if rect.size == Vector2i.ZERO: return

	astar.region = rect
	astar.update()
	
	astar.fill_solid_region(rect, true)

	for cell in layer0.get_used_cells():
		if layer1.get_cell_source_id(cell) == -1:
			astar.set_point_solid(cell, false)

static func get_path_to_tile(start: Vector2, target: Vector2i, base_layer: TileMapLayer) -> Array[Vector2]:
	if not astar or not astar.is_in_bounds(target.x, target.y): return []

	var start_cell = base_layer.local_to_map(base_layer.to_local(start))
	if not astar.is_in_bounds(start_cell.x, start_cell.y): return []

	var path_cells = astar.get_id_path(start_cell, target)
	var world_path: Array[Vector2] = []
	
	for cell in path_cells:
		world_path.append(base_layer.to_global(base_layer.map_to_local(cell)))
		
	return world_path
