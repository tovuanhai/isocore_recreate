extends Node

var hub: Node2D
var hover_sprite: Sprite2D
var ghost_sprite: Sprite2D 

var cached_inv_comp: Node 
var _last_hovered_cell := Vector2i(-9999, -9999)
var _last_held_item = null

# ==========================================
# 🎯 THÊM BIẾN DÀNH CHO OUTLINE EFFECT
# ==========================================
var outline_material: ShaderMaterial = null
var _last_hovered_object: Node = null

@export var hover_texture: Texture2D 

func initialize(p_hub: Node2D) -> void:
	hub = p_hub
	if hub.player and hub.player.has_node("PlayerInventoryComponent"):
		cached_inv_comp = hub.player.get_node("PlayerInventoryComponent")

func setup_hover_effect() -> void:
	if hover_sprite != null: return 
	
	# 🎯 BẠN ĐÃ TẢI SHADER TỪ YOUTUBE VÀO ĐÂY!
	var outline_shader = preload("res://Resources/Shaders/outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = outline_shader
	# Ông có thể đổi màu ở đây, tôi đang để Trắng (1,1,1) mờ một chút (0.9)
	outline_material.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 0.9)) 
	outline_material.set_shader_parameter("width", 1) # Độ dày viền
	
	hover_sprite = Sprite2D.new()
	if hover_texture:
		hover_sprite.texture = hover_texture
	hover_sprite.top_level = true
	hover_sprite.z_index = 0
	hover_sprite.y_sort_enabled = false 
	hub.add_child(hover_sprite)
	
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

# ==========================================
# 🎯 HÀM PHỤ: GẮN/XÓA VIỀN CHO OBJECT
# ==========================================
func _apply_outline(obj: Node) -> void:
	if not is_instance_valid(obj): return
	for child in obj.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.material = outline_material
			break # Chỉ tô viền lớp Sprite đầu tiên tìm thấy

func _remove_outline(obj: Node) -> void:
	if not is_instance_valid(obj): return
	for child in obj.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.material = null
			break

func handle_hover_effect() -> void:
	var mouse_pos = hover_sprite.get_global_mouse_position()
	var current_cell = get_hovered_tile(mouse_pos)
	var held_item = _get_held_placeable_item()

	if current_cell == _last_hovered_cell and held_item == _last_held_item:
		return 

	_last_hovered_cell = current_cell
	_last_held_item = held_item
	
	# 🧹 DỌN DẸP OUTLINE CŨ KHI CHUỘT LIA SANG Ô KHÁC
	if _last_hovered_object != null:
		_remove_outline(_last_hovered_object)
		_last_hovered_object = null

	if current_cell != Vector2i(-9999, -9999):
		var actual_z = hub.world_data[current_cell]["z"]
		var surface_z = get_surface_elevation(current_cell)
		
		# 🎯 TÌM VÀ TÔ VIỀN OBJECT MỚI NẾU CÓ
		if hub.world_data[current_cell].get("object", "none") != "none":
			if hub.spawned_objects.has(current_cell):
				_last_hovered_object = hub.spawned_objects[current_cell]
				_apply_outline(_last_hovered_object)
		
		if surface_z >= 0 and surface_z < hub.ground_layers.size():
			var target_layer = hub.ground_layers[surface_z]
			var final_pos = target_layer.to_global(target_layer.map_to_local(current_cell))
			
			hover_sprite.global_position = final_pos
			ghost_sprite.global_position = final_pos
			hover_sprite.visible = true
			
			if held_item != null:
				ghost_sprite.visible = true
				ghost_sprite.texture = held_item.icon 
				if ghost_sprite.texture != null:
					ghost_sprite.offset.y = -(ghost_sprite.texture.get_height() / 4.0)
				else:
					ghost_sprite.offset.y = 0
				
				var is_blocked = has_obstacle(current_cell, actual_z) or hub.world_data[current_cell].get("is_water", false)
				
				if is_blocked:
					hover_sprite.modulate = Color("#ff4444", 0.8) 
					ghost_sprite.modulate = Color("#ff4444", 0.6)
				else:
					hover_sprite.modulate = Color("#00BFFF", 0.9) 
					ghost_sprite.modulate = Color(1.0, 1.0, 1.0, 0.7) 
			else:
				ghost_sprite.visible = false
				hover_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0) 
	else:
		hover_sprite.visible = false
		ghost_sprite.visible = false

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
