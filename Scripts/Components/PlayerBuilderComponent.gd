class_name PlayerBuilderComponent
extends Node

@onready var inventory_comp = get_parent().get_node_or_null("PlayerInventoryComponent")
var _tilemap_node = null

func _ready() -> void:
	_tilemap_node = get_tree().current_scene.get_node_or_null("TileMap")

func _unhandled_input(event: InputEvent) -> void:
	if not _is_ready_to_build(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_place_object()

func _is_ready_to_build() -> bool:
	return inventory_comp != null and _tilemap_node != null

# ==============================================================================
# 🎯 1. TÍNH TOÁN LƯỚI TỌA ĐỘ (Lấy ô Dưới Cùng làm Mốc)
# ==============================================================================
func get_occupied_cells(bottom_cell: Vector2i, build_size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(build_size.x):
		for y in range(build_size.y):
			# Trừ lùi tọa độ để quét ngược lên hướng Bắc
			cells.append(Vector2i(bottom_cell.x - x, bottom_cell.y - y))
	return cells

func can_build_here(bottom_cell: Vector2i, build_size: Vector2i) -> bool:
	var target_cells = get_occupied_cells(bottom_cell, build_size)
	var base_elev = _tilemap_node.get_cell_elevation(bottom_cell)
	
	# 🎯 1. TÌM TỌA ĐỘ LƯỚI MÀ PLAYER ĐANG ĐỨNG
	var player_node = get_parent()
	var player_cell = _tilemap_node.base_ground.local_to_map(_tilemap_node.base_ground.to_local(player_node.global_position))
	
	for cell in target_cells:
		# 🎯 2. CHỐNG XÂY ĐÈ LÊN PLAYER
		if cell == player_cell: 
			return false
			
		# Rớt ra ngoài map?
		if not _tilemap_node.world_data.has(cell): 
			return false
		
		# Khác độ cao với ô gốc? (Chống xây nhà bị gãy)
		var cell_elev = _tilemap_node.get_cell_elevation(cell)
		if cell_elev != base_elev: 
			return false
		
		# Bị kẹt đá, cây hoặc nước?
		if _tilemap_node.has_obstacle(cell, cell_elev) or _tilemap_node.world_data[cell].get("is_water", false): 
			return false
			
	return true

func _try_place_object() -> void:
	var item = inventory_comp.get_equipped_item()
	if not item or item.type != ItemData.ItemType.PLACEABLE or item.object_scene == null: return

	var hovered_cell = _tilemap_node.get_hovered_tile()
	if hovered_cell == Vector2i(-9999, -9999): return

	# 🎯 ĐỌC KÍCH THƯỚC ĐỘNG TỪ ITEM
	var current_build_size = Vector2i(1, 1)
	if "build_size" in item:
		current_build_size = item.build_size

	if not can_build_here(hovered_cell, current_build_size):
		return

	_spawn_object(item, hovered_cell, current_build_size)
	_consume_item()

	if _tilemap_node.has_node("HoverManager"):
		_tilemap_node.get_node("HoverManager").force_update_hover()
	get_viewport().set_input_as_handled()

func _spawn_object(item: ItemData, bottom_cell: Vector2i, build_size: Vector2i) -> void:
	var obj_node = item.object_scene.instantiate() as Node2D
	
	# Đồng bộ với hệ thống Spawner mới của ông
	_tilemap_node.add_child(obj_node)
	
	# Định vị ảnh 3D nằm chính xác ở Ô Dưới Cùng (Bottom Cell)
	var local_pos = _tilemap_node.base_ground.map_to_local(bottom_cell)
	obj_node.global_position = _tilemap_node.base_ground.to_global(local_pos)
	
	var elev = _tilemap_node.get_cell_elevation(bottom_cell)
	if obj_node.has_method("init"):
		obj_node.init(elev, _tilemap_node.cliff_height)
	else:
		var sprite = obj_node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.offset.y = -(elev * _tilemap_node.cliff_height)
			
	# 🎯 QUAN TRỌNG NHẤT: Trói buộc toàn bộ 4 ô đất cho 1 khối Object
	var target_cells = get_occupied_cells(bottom_cell, build_size)
	for cell in target_cells:
		_tilemap_node.world_data[cell]["object"] = item.id
		_tilemap_node.spawned_objects[cell] = obj_node # Lưu Reference để khi Hover biết là cùng 1 khối
		_tilemap_node._refresh_astar(cell) # Ép AI né toàn bộ khối 2x2
		
		# Cập nhật viền sáng cho các ô bị chiếm
		if _tilemap_node.has_node("Spawner"):
			_tilemap_node.spawner.update_surrounding_highlights(cell)

func _consume_item() -> void:
	var slot = inventory_comp.get_equipped_slot()
	slot.quantity -= 1
	if slot.quantity <= 0:
		slot.clear()
	inventory_comp.inventory.changed.emit(inventory_comp.equipped_slot_index)
