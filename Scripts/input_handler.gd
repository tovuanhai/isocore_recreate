# input_handler.gd
# Node con trực tiếp của Player
# Chịu trách nhiệm đọc input chuột và điều phối hành động dựa trên Công cụ đang cầm
extends Node

@onready var player: Player = get_parent()
@onready var fsm = get_parent().get_node("StateMachine")

# 🎯 CODE SẠCH: Tìm Component an toàn, không hardcode cứng đường dẫn "../"
@onready var inventory_comp = get_parent().get_node_or_null("PlayerInventoryComponent")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit"):
		get_tree().quit()
	
	# 1. Không nhận input khi đang trong hoạt ảnh tương tác (cuốc, chặt)
	if fsm and fsm.get("current_state") and fsm.current_state.name.to_lower() == "interact":
		return

	# ============================================================
	# 🎯 QUẢN LÝ PHÍM E (INTERACT) ƯU TIÊN THEO CON TRỎ CHUỘT
	# ============================================================
	if event.is_action_pressed("interact"):
		_handle_interaction_by_mouse()
		return

	# (Phần code click chuột trái/phải bên dưới của ông cứ giữ nguyên)
	if not (event is InputEventMouseButton and event.pressed): return
	if not player.tile_map_node or not MovementUtils: return

	var clicked_tile = player.tile_map_node.get_hovered_tile()
	if clicked_tile == Vector2i(-9999, -9999): return

	var player_cell = player.get_current_cell()
	var data = player.tile_map_node.world_data.get(clicked_tile, {})

	# ============================================================
	# ĐIỀU PHỐI HÀNH ĐỘNG 
	# ============================================================
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(player_cell, clicked_tile, data)

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(player_cell, clicked_tile, data)


func _handle_left_click(player_cell: Vector2i, clicked_tile: Vector2i, data: Dictionary) -> void:
	# Click chuột trái: Mặc định là Click-to-Move hoặc Tương tác cơ bản
	if data.get("object", "none") != "none":
		# Có vật thể (đá, cây) -> Lại gần để chuẩn bị khai thác
		_try_interact(player_cell, clicked_tile, "mine_object")
	else:
		# Đất trống -> Di chuyển
		player.interact_type = ""
		var cell_path = MovementUtils.get_path_cells(player_cell, clicked_tile)
		player.set_path_from_cells(cell_path)


func _handle_right_click(player_cell: Vector2i, clicked_tile: Vector2i, data: Dictionary) -> void:
	if inventory_comp == null: return
	
	var equipped_item = inventory_comp.get_equipped_item()
	
	if equipped_item != null:
		
		if equipped_item.type == ItemData.ItemType.PLACEABLE:
			return 

		if equipped_item.type == ItemData.ItemType.TOOL:
			var tool = equipped_item as ToolData
			
			if tool and tool.tool_category == ToolData.ToolCategory.SHOVEL:
				_execute_ground_interaction(player_cell, clicked_tile, data)
				return
			else:
				return
	

# 🎯 ĐÃ XÓA TÀN DƯ HƯ VÔ: Không còn logic Shift để đắp đất miễn phí nữa
func _execute_ground_interaction(player_cell: Vector2i, clicked_tile: Vector2i, data: Dictionary) -> void:
	var is_land = data.get("z", 0) > player.tile_map_node.water_level
	var no_object = data.get("object", "none") == "none"
	
	
	if is_land and no_object:
		_try_interact(player_cell, clicked_tile, "mine_ground")


func _try_interact(player_cell: Vector2i, clicked_tile: Vector2i, action: String) -> void:
	var stand_cell = MovementUtils.find_closest_interactable_neighbor(
		player_cell, clicked_tile, player.tile_map_node
	)
	if stand_cell == Vector2i(-9999, -9999): return

	player.interact_tile = clicked_tile
	player.interact_type = action

	if player_cell == stand_cell:
		player.set_path_from_cells([])
		fsm._on_transition_requested("Interact")
	else:
		var cell_path = MovementUtils.get_path_cells(player_cell, stand_cell)
		player.set_path_from_cells(cell_path)

func _handle_interaction_by_mouse() -> void:
	# =========================================================================
	# LỚP ƯU TIÊN 1: BẮT CHÍNH XÁC THEO Ô ĐẤT ĐANG SÁNG (Tuyệt đối không trượt)
	# =========================================================================
	var hovered_cell = player.tile_map_node.get_hovered_tile()
	if hovered_cell != Vector2i(-9999, -9999):
		# Kiểm tra xem trên ô gạch này có vật thể nào đang được sinh ra không
		if player.tile_map_node.spawned_objects.has(hovered_cell):
			var target_obj = player.tile_map_node.spawned_objects[hovered_cell]
			if is_instance_valid(target_obj):
				var comp = target_obj.get_node_or_null("InteractComponent")
				# Đảm bảo Player đứng đủ gần thì mới cho phép Mở
				if comp and target_obj.global_position.distance_to(player.global_position) <= comp.interact_distance:
					comp.interacted.emit()
					return # Trúng đích tuyệt đối thì dừng hàm luôn, không cần quét nữa!

	# =========================================================================
	# LỚP ƯU TIÊN 2: BẮT THEO KHOẢNG CÁCH CHUỘT (Dự phòng khi chỉ hơi lệch)
	# =========================================================================
	var interactables = get_tree().get_nodes_in_group("interactable_components")
	if interactables.is_empty(): return
	
	var global_mouse_pos = player.get_global_mouse_position()
	var best_target: Node = null
	var closest_mouse_dist = INF
	
	for comp in interactables:
		if not is_instance_valid(comp): continue
		
		var parent_obj = comp.get_parent()
		# Vẫn phải đảm bảo Mèo nằm trong phạm vi tương tác của vật thể
		if parent_obj.global_position.distance_to(player.global_position) <= comp.interact_distance:
			
			# 🎯 ĐÂY LÀ MA THUẬT: Dời tâm đo lường lên trên 12 pixel (Giữa thân vật thể)
			# Để chống lại ảo giác của góc nhìn Isometric!
			var visual_center = parent_obj.global_position + Vector2(0, -12)
			
			var dist_to_mouse = visual_center.distance_to(global_mouse_pos)
			if dist_to_mouse < closest_mouse_dist:
				closest_mouse_dist = dist_to_mouse
				best_target = comp
				
	# Nếu dùng lưới quét dự phòng mà tìm thấy, thì phát lệnh Mở!
	if best_target != null:
		best_target.interacted.emit()
