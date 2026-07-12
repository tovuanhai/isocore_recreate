extends Node

var hub: Node2D
var hover_sprites: Array[Sprite2D] = []
var ghost_sprite: Sprite2D 

var cached_inv_comp: Node 
var _last_hovered_cell := Vector2i(-9999, -9999)
var _last_held_item = null

# ==========================================
# 🎯 THÊM BIẾN DÀNH CHO OUTLINE EFFECT
# ==========================================
var outline_material: ShaderMaterial = null
var _last_hovered_object: Node = null

# Thêm 2 biến này ở phần đầu file (khu vực khai báo biến)
var _outlined_sprite: Node = null
var _original_material: Material = null

@export var hover_texture: Texture2D 

func initialize(p_hub: Node2D) -> void:
	hub = p_hub
	if hub.player and hub.player.has_node("PlayerInventoryComponent"):
		cached_inv_comp = hub.player.get_node("PlayerInventoryComponent")

func setup_hover_effect() -> void:
	if hover_sprites.size() > 0: return 
	
	var outline_shader = preload("res://Resources/Shaders/outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = outline_shader
	outline_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 0.9)) 
	outline_material.set_shader_parameter("width", 1) 
	
	# Tạo sẵn 9 cái Sprite viền để tái sử dụng
	for i in range(9):
		var hs = Sprite2D.new()
		if hover_texture: hs.texture = hover_texture
		hs.top_level = true
		hs.z_index = 0
		hs.y_sort_enabled = false 
		hs.visible = false
		hub.add_child(hs)
		hover_sprites.append(hs)
	
	ghost_sprite = Sprite2D.new()
	ghost_sprite.top_level = true
	ghost_sprite.z_index = 0 
	ghost_sprite.y_sort_enabled = false
	hub.add_child(ghost_sprite)

func get_surface_elevation(cell: Vector2i) -> int:
	if hub.world_data.has(cell):
		if hub.world_data[cell].get("is_water", false): return hub.water_level
		return hub.world_data[cell]["z"]
	return -1

func get_hovered_tile(mouse_pos: Vector2) -> Vector2i:
	var base_layer = hub.base_ground 
	var local_mouse_pos = base_layer.to_local(mouse_pos)
	var c_height = hub.cliff_height
	
	for z in range(hub.max_elevation, -1, -1):
		var check_pos = local_mouse_pos + Vector2(0, z * c_height)
		var cell = base_layer.local_to_map(check_pos)
		
		if hub.world_data.has(cell):
			var surface_z = get_surface_elevation(cell)
			if surface_z >= z:
				return cell 
				
	return Vector2i(-9999, -9999)

func _apply_outline(obj: Node) -> void:
	if not is_instance_valid(obj): return
	
	# 🎯 1. Ưu tiên tìm thằng Sprite2D2 (Hình ảnh chính) trước
	var target_sprite = obj.get_node_or_null("Sprite2D2")
	
	# 🎯 2. Nếu không có, quét tìm nhưng BỎ QUA các node Bóng!
	if target_sprite == null:
		for child in obj.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				# Né các node nằm trong group Bóng mà ông đã quy định
				if child.is_in_group("isometric_shadows") or child.name.to_lower().contains("shadow"):
					continue
				target_sprite = child
				break
				
	# 🎯 3. Lên viền và BẢO LƯU Material cũ
	if target_sprite != null:
		if target_sprite.has_meta("is_flashing") and target_sprite.get_meta("is_flashing") == true:
			return
			
		_outlined_sprite = target_sprite
		# Lưu lại đồ zin (Ví dụ: shader lá cây đung đưa, hoặc shader màu)
		_original_material = target_sprite.material 
		
		target_sprite.material = outline_material

func _remove_outline(obj: Node) -> void:
	if not is_instance_valid(obj): return
	
	if is_instance_valid(_outlined_sprite):
		if not (_outlined_sprite.has_meta("is_flashing") and _outlined_sprite.get_meta("is_flashing") == true):
			# 🎯 TRẢ LẠI ĐỒ ZIN THAY VÌ DÙNG LỆNH GÁN NULL TÀN NHẪN
			_outlined_sprite.material = _original_material
			
	_outlined_sprite = null
	_original_material = null

func handle_hover_effect() -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	if hover_sprites.size() > 0:
		mouse_pos = hover_sprites[0].get_global_mouse_position()
		
	var current_cell = get_hovered_tile(mouse_pos)
	var held_item = _get_held_placeable_item()

	if current_cell == _last_hovered_cell and held_item == _last_held_item:
		return 

	_last_hovered_cell = current_cell
	_last_held_item = held_item
	
	if _last_hovered_object != null:
		_remove_outline(_last_hovered_object)
		_last_hovered_object = null

	# Tắt toàn bộ viền trước khi tính toán mới
	for hs in hover_sprites: hs.visible = false
	ghost_sprite.visible = false

	if current_cell != Vector2i(-9999, -9999):
		var actual_z = hub.world_data[current_cell]["z"]
		var surface_z = get_surface_elevation(current_cell)
		
		if hub.world_data[current_cell].get("object", "none") != "none":
			if hub.spawned_objects.has(current_cell):
				var obj = hub.spawned_objects[current_cell]
				
				# 🎯 LỚP PHÒNG THỦ TUYỆT ĐỐI
				if is_instance_valid(obj):
					_last_hovered_object = obj
					_apply_outline(_last_hovered_object)
				else:
					# Nếu phát hiện "xác chết" (Freed Instance) do đập đồ to còn sót lại -> Xóa luôn!
					hub.spawned_objects.erase(current_cell)
					hub.world_data[current_cell]["object"] = "none"
		
		if surface_z >= 0 and surface_z < hub.ground_layers.size():
			var b_size = Vector2i(1, 1)
			if held_item != null and "build_size" in held_item:
				b_size = held_item.build_size
				
			# Xác định danh sách các ô sẽ bị chiếm
			var target_cells = []
			for x in range(b_size.x):
				for y in range(b_size.y):
					target_cells.append(Vector2i(current_cell.x - x, current_cell.y - y))
					
			# 🎯 LẤY TỌA ĐỘ PLAYER CHO HOVER MANAGER
			var player_cell = Vector2i(-9999, -9999)
			if is_instance_valid(hub.player):
				player_cell = hub.base_ground.local_to_map(hub.base_ground.to_local(hub.player.global_position))
					
			# Kiểm tra xem có ô nào bị kẹt không
			var is_blocked = false
			for cell in target_cells:
				# 🎯 THÊM ĐIỀU KIỆN TRÙNG VỚI PLAYER_CELL
				if not hub.world_data.has(cell) or cell == player_cell:
					is_blocked = true; break
					
				var c_elev = get_surface_elevation(cell)
				if c_elev != surface_z or has_obstacle(cell, c_elev) or hub.world_data[cell].get("is_water", false):
					is_blocked = true; break

			# Vẽ các viền sáng
			for i in range(target_cells.size()):
				if i >= hover_sprites.size(): break
				var c = target_cells[i]
				if hub.world_data.has(c):
					var target_layer = hub.ground_layers[surface_z]
					var final_pos = target_layer.to_global(target_layer.map_to_local(c))
					
					hover_sprites[i].global_position = final_pos
					hover_sprites[i].visible = true
					
					if held_item != null:
						hover_sprites[i].modulate = Color("#ff4444", 0.8) if is_blocked else Color("#00BFFF", 0.9)
					else:
						hover_sprites[i].modulate = Color(1.0, 1.0, 1.0, 1.0)
						
			# Vẽ hình ảnh ảo (Ghost Sprite) ở ô Gốc (Dưới cùng)
			if held_item != null:
				var target_layer = hub.ground_layers[surface_z]
				ghost_sprite.global_position = target_layer.to_global(target_layer.map_to_local(current_cell))
				ghost_sprite.visible = true
				ghost_sprite.texture = held_item.icon 
				
				# 🎯 ĐỌC OFFSET TÙY CHỈNH TỪ ITEM
				if "ghost_offset" in held_item and held_item.ghost_offset != Vector2.ZERO:
					ghost_sprite.offset = held_item.ghost_offset
				elif ghost_sprite.texture != null:
					# Fallback nếu ông quên chưa cài
					ghost_sprite.offset.y = -(ghost_sprite.texture.get_height() / 4.0)
				else:
					ghost_sprite.offset.y = 0
				
				ghost_sprite.modulate = Color("#ff4444", 0.6) if is_blocked else Color(1.0, 1.0, 1.0, 0.7)
	#else:
		#hover_sprites.visible = false
		#ghost_sprite.visible = false

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	if hub.world_data.has(cell):
		var data = hub.world_data[cell]
		if data["z"] != elevation: 
			return true
		if data.get("object", "none") != "none":
			return true
	return false

func _get_held_placeable_item():
	if cached_inv_comp != null and cached_inv_comp.has_method("get_equipped_slot"):
		var slot = cached_inv_comp.get_equipped_slot()
		if slot and not slot.is_empty() and slot.item != null:
			if slot.item.type == ItemData.ItemType.PLACEABLE:
				return slot.item
	return null

func force_update_hover() -> void:
	_last_hovered_cell = Vector2i(-9999, -9999)
	# 🧹 Quét sạch outline phòng trường hợp Object vừa bị đập vỡ
	if _last_hovered_object != null:
		_remove_outline(_last_hovered_object)
		_last_hovered_object = null
