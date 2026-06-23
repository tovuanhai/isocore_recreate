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

func _try_place_object() -> void:
	var item = inventory_comp.get_equipped_item()
	if not item or item.type != ItemData.ItemType.PLACEABLE or item.object_scene == null:
		return
		
	var hovered_cell = _tilemap_node.get_hovered_tile()
	if hovered_cell == Vector2i(-9999, -9999) or not _tilemap_node.world_data.has(hovered_cell):
		return
		
	var elev = _tilemap_node.get_cell_elevation(hovered_cell)
	
	# Cấm xây nếu có vật thể khác hoặc là nước
	if _tilemap_node.has_obstacle(hovered_cell, elev) or _tilemap_node.world_data[hovered_cell].get("is_water", false):
		return
		
	_spawn_object(item, hovered_cell)
	_consume_item()
	
	# 🎯 Cập nhật lại Hover (Đổi bóng sang màu Đỏ do ô này đã bị lấp)
	if _tilemap_node.has_node("HoverManager"):
		_tilemap_node.get_node("HoverManager").force_update_hover()
		
	get_viewport().set_input_as_handled()

func _spawn_object(item: ItemData, cell: Vector2i) -> void:
	var obj_node = item.object_scene.instantiate() as Node2D
	get_parent().get_parent().add_child(obj_node)
	
	var local_pos = _tilemap_node.base_ground.map_to_local(cell)
	obj_node.global_position = _tilemap_node.base_ground.to_global(local_pos)
	
	var elev = _tilemap_node.get_cell_elevation(cell)
	if obj_node.has_method("init"):
		obj_node.init(elev, _tilemap_node.cliff_height)
	else:
		var sprite = obj_node.get_node_or_null("Sprite2D")
		if sprite: sprite.offset.y = -(elev * _tilemap_node.cliff_height)
	
	_tilemap_node.world_data[cell]["object"] = item.id
	_tilemap_node.spawned_objects[cell] = obj_node
	_tilemap_node._refresh_astar(cell)

func _consume_item() -> void:
	var slot = inventory_comp.get_equipped_slot()
	slot.quantity -= 1
	if slot.quantity <= 0:
		slot.clear()
	inventory_comp.inventory.changed.emit(inventory_comp.equipped_slot_index)
