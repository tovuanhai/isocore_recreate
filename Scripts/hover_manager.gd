extends Node

var hub: Node2D
var hover_effect: Polygon2D

func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func setup_hover_polygon() -> void:
	hover_effect = Polygon2D.new()
	hover_effect.polygon = PackedVector2Array([Vector2(0, -4), Vector2(8, 0), Vector2(0, 4), Vector2(-8, 0)])
	hover_effect.color = Color(1, 1, 1, 0.4)
	hover_effect.top_level = true
	hover_effect.z_index = 100
	hub.add_child(hover_effect)

func get_surface_elevation(cell: Vector2i) -> int:
	if hub.world_data.has(cell):
		# Nếu là nước, mặt nổi của nó là water_level. Nếu trên cạn, mặt nổi là z.
		if hub.world_data[cell].get("is_water", false): return hub.water_level
		return hub.world_data[cell]["z"]
	return -1


func get_hovered_tile() -> Vector2i:
	var mouse_pos = hover_effect.get_global_mouse_position()
	var best_cell = Vector2i(-9999, -9999)
	var base_layer = hub.base_ground 
	
	for z in range(hub.max_elevation, -1, -1):
		var elev_shift = hub.cliff_height * z
		var layer_mouse_pos = mouse_pos + Vector2(0, elev_shift)
		
		var cell = base_layer.local_to_map(base_layer.to_local(layer_mouse_pos))
		if hub.world_data.has(cell):
			var surface_z = get_surface_elevation(cell)
			if surface_z >= z:
				best_cell = cell
				break 
	return best_cell

func handle_hover_effect() -> void:
	var cell = get_hovered_tile()
	if cell != Vector2i(-9999, -9999):
		var surface_z = get_surface_elevation(cell)
		var actual_z = hub.world_data[cell]["z"]
		
		if surface_z >= 0 and surface_z < hub.ground_layers.size():
			var target_layer = hub.ground_layers[surface_z]
			hover_effect.global_position = target_layer.to_global(target_layer.map_to_local(cell))
			hover_effect.visible = true
			
			# Check chướng ngại vật (Nước BẮT BUỘC là chướng ngại vật)
			if has_obstacle(cell, actual_z) or hub.world_data[cell].get("is_water", false):
				hover_effect.color = Color(1.0, 0.0, 0.0, 0.5) 
			else:
				hover_effect.color = Color(1.0, 1.0, 1.0, 0.5)
	else:
		hover_effect.visible = false

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	if hub.world_data.has(cell):
		var data = hub.world_data[cell]
		
		## 1. LUẬT MỚI: Cấm bơi lội (Nước là chướng ngại vật tuyệt đối)
		#if data.get("is_water", false):
			#return true
			
		# 2. Cấm leo trèo: Lệch độ cao (Vách đá)
		if data["z"] != elevation: 
			return true
			
		# 3. Đâm vào vật thể: Cây đèn, cục đá
		if data.get("object", "none") != "none":
			return true
			
	return false

func get_cell_elevation(cell: Vector2i) -> int:
	if hub.world_data.has(cell): return hub.world_data[cell]["z"]
	return -1
