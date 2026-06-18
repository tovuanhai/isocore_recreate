# input_handler.gd
# Node con trực tiếp của Player
# Chịu trách nhiệm đọc input chuột và điều phối hành động dựa trên Công cụ đang cầm
extends Node

@onready var player: Player = get_parent()
@onready var fsm = get_parent().get_node("StateMachine")

# 🎯 CODE SẠCH: Tìm Component an toàn, không hardcode cứng đường dẫn "../"
@onready var inventory_comp = get_parent().get_node_or_null("PlayerInventoryComponent")

func _unhandled_input(event: InputEvent) -> void:
	# 1. Không nhận input khi đang trong hoạt ảnh tương tác (cuốc, chặt)
	if fsm and fsm.get("current_state") and fsm.current_state.name.to_lower() == "interact":
		return

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
