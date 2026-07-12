class_name HealthDropComponent
extends Node

@export var max_health: int = 3
@export var drop_item_id: String = "" # ID đồ rớt ra (VD: "stone", "wooden_chest")
@export var drop_amount: int = 1

const GROUND_ITEM_SCENE = preload("res://Scenes/GroundItem.tscn")
var current_health: int

func _ready() -> void:
	current_health = max_health

# Đã thêm exact_pos để nhận tọa độ chuẩn từ TileMap
func take_damage(amount: int, exact_pos: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	if current_health <= 0:
		break_object(exact_pos)

func break_object(exact_pos: Vector2 = Vector2.ZERO) -> void:
	var parent_obj = get_parent()
	if exact_pos == Vector2.ZERO:
		exact_pos = parent_obj.global_position

	# 🎯 CHỐT CHẶN 1: Tắt va chạm NGAY LẬP TỨC để chặn người chơi đập bồi thêm khi đang chạy VFX vỡ
	if parent_obj is CollisionObject2D:
		parent_obj.collision_layer = 0
		parent_obj.collision_mask = 0

	# 🎯 CHỐT CHẶN 2: CẤM GỌI parent_obj.hide() ở đây!
	# Phải giữ vật thể hiển thị thì chuỗi Tween Squash co giãn của vfx_manager mới hiện ra trên màn hình.

	# 1. Nhờ túi đồ xả rác ra trước (nếu là hòm/lò nung)
	var inv_comp = parent_obj.get_node_or_null("ObjectInventoryComponent")
	if inv_comp and inv_comp.has_method("drop_all_items"):
		inv_comp.drop_all_items(exact_pos)

	# 2. Xả chính bản thân nó (Cục hòm gỗ / Cục đá con rớt ra đất)
	if drop_item_id != "":
		var item_data = ItemRegistry.get_item(drop_item_id)
		if item_data:
			_spawn_dropped_item(item_data, drop_amount, -1, exact_pos)

	# 3. Dọn dẹp mảng dữ liệu TileMap và làm thông đường AStar ngay lập tức
	_cleanup_map_data(parent_obj)

	# 🎯 CHỐT CHẶN 3: Chờ đúng 0.2 giây (Khớp khít 100% với thời gian chạy nảy Squash của ông)
	# Khi hiệu ứng co giãn đàn hồi kết thúc mỹ mãn, ta mới chính thức giải phóng Node khỏi bộ nhớ!
	get_tree().create_timer(0.2).timeout.connect(parent_obj.queue_free)

# Hàm xả đồ chuẩn xác
func _spawn_dropped_item(item: ItemData, amount: int, dur: int, exact_pos: Vector2) -> void:
	if GROUND_ITEM_SCENE == null or item == null: return
	var parent_obj = get_parent()
	var drop = GROUND_ITEM_SCENE.instantiate()
	drop.z_index = 1
	
	get_tree().current_scene.add_child(drop)
	
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	drop.global_position = exact_pos + random_offset
	
	var final_offset_y = 0.0
	for child in parent_obj.get_children():
		if child is Sprite2D:
			final_offset_y = child.offset.y
			break
			
	var drop_sprite = drop.get_node_or_null("Sprite2D")
	if drop_sprite: 
		drop_sprite.offset.y = final_offset_y
		
	if drop.has_method("setup"): drop.setup(item.id, amount, dur)

func _cleanup_map_data(parent_obj: Node2D) -> void:
	var tile_map = get_tree().current_scene.get_node_or_null("TileMap")
	if not tile_map or not tile_map.get("base_ground"): return
		
	var center_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(parent_obj.global_position))
	
	# 🎯 QUÉT VÙNG 5x5 QUANH Ô GỐC ĐỂ TÌM VÀ XÓA MỌI Ô LIÊN KẾT VỚI OBJECT NÀY
	for x in range(-2, 3):
		for y in range(-2, 3):
			var scan_cell = center_cell + Vector2i(x, y)
			
			# Nếu ô này chứa đúng cái Object vừa bị đập vỡ
			if tile_map.spawned_objects.has(scan_cell) and tile_map.spawned_objects[scan_cell] == parent_obj:
				tile_map.spawned_objects.erase(scan_cell)
				
				if tile_map.world_data.has(scan_cell):
					tile_map.world_data[scan_cell]["object"] = "none" 
					
				tile_map._refresh_astar(scan_cell)
				
				if tile_map.has_node("Spawner"):
					tile_map.spawner.update_surrounding_highlights(scan_cell)

	if tile_map.has_node("HoverManager"):
		tile_map.hover_manager.force_update_hover()
