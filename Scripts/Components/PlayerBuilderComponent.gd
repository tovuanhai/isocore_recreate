extends Node

@onready var inventory_comp = get_parent().get_node_or_null("PlayerInventoryComponent")
var _placement_preview: Sprite2D = null
var _tilemap_node = null

func _ready() -> void:
	_tilemap_node = get_tree().current_scene.get_node_or_null("TileMap")
	_setup_preview_sprite()

func _process(_delta: float) -> void:
	_update_placement_preview()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_ready_to_build(): return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_try_place_object()

# ==============================================================================
# HÀM PHỤ TRỢ (HELPERS)
# ==============================================================================

func _is_ready_to_build() -> bool:
	return inventory_comp != null and _tilemap_node != null

func _setup_preview_sprite() -> void:
	_placement_preview = Sprite2D.new()
	_placement_preview.name = "PlacementPreview"
	_placement_preview.modulate = Color(1, 1, 1, 0.5)
	_placement_preview.hide()
	get_parent().get_parent().call_deferred("add_child", _placement_preview)

func _update_placement_preview() -> void:
	if not _is_ready_to_build(): return
	
	var item = inventory_comp.get_equipped_item()
	if item and item.type == ItemData.ItemType.PLACEABLE and item.object_scene != null:
		var hovered_cell = _tilemap_node.get_hovered_tile()
		
		# Chỉ hiện bóng ma nếu đang trỏ vào ô đất hợp lệ
		if hovered_cell != Vector2i(-9999, -9999) and _tilemap_node.world_data.has(hovered_cell):
			_placement_preview.texture = item.icon
			_align_preview_to_isometric_grid(hovered_cell)
			_placement_preview.show()
			return
			
	_placement_preview.hide()

func _align_preview_to_isometric_grid(cell: Vector2i) -> void:
	var elev = _tilemap_node.get_cell_elevation(cell)
	var local_pos = _tilemap_node.base_ground.map_to_local(cell)
	var global_pos = _tilemap_node.base_ground.to_global(local_pos)
	
	# Cắm gốc xuống đất, kéo ảnh lên theo độ cao
	_placement_preview.global_position = global_pos
	_placement_preview.offset.y = -(elev * _tilemap_node.cliff_height)
	_placement_preview.z_index = 5

func _try_place_object() -> void:
	var item = inventory_comp.get_equipped_item()
	if not item or item.type != ItemData.ItemType.PLACEABLE or item.object_scene == null or not _placement_preview.visible:
		return
		
	var hovered_cell = _tilemap_node.get_hovered_tile()
	if hovered_cell == Vector2i(-9999, -9999) or not _tilemap_node.world_data.has(hovered_cell):
		return
		
	# Cấm xây đè lên vật thể khác
	if _tilemap_node.world_data[hovered_cell].get("object", "none") != "none":
		return
		
	_spawn_object(item, hovered_cell)
	_consume_item()
	get_viewport().set_input_as_handled()

func _spawn_object(item: ItemData, cell: Vector2i) -> void:
	var obj_node = item.object_scene.instantiate() as Node2D
	get_parent().get_parent().add_child(obj_node)
	
	# Copy tọa độ từ bóng ma
	obj_node.global_position = _placement_preview.global_position
	
	# Kích hoạt Offset của vật thể
	var elev = _tilemap_node.get_cell_elevation(cell)
	if obj_node.has_method("init"):
		obj_node.init(elev, _tilemap_node.cliff_height)
	else:
		var sprite = obj_node.get_node_or_null("Sprite2D")
		if sprite: sprite.offset.y = -(elev * _tilemap_node.cliff_height)
	
	# Đăng ký với Map và cập nhật AStar
	_tilemap_node.world_data[cell]["object"] = item.id
	_tilemap_node.spawned_objects[cell] = obj_node
	_tilemap_node._refresh_astar(cell)

func _consume_item() -> void:
	var slot = inventory_comp.get_equipped_slot()
	slot.quantity -= 1
	if slot.quantity <= 0:
		slot.clear()
	inventory_comp.inventory.changed.emit(inventory_comp.equipped_slot_index)
