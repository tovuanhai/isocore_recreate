# input_handler.gd
# Node con trực tiếp của Player
# Chịu toàn bộ trách nhiệm đọc input chuột và quyết định hành động
extends Node

@onready var player: Player = get_parent()
@onready var fsm = get_parent().get_node("StateMachine")


func _unhandled_input(event: InputEvent) -> void:
	# Không nhận input khi đang Interact
	if fsm and fsm.get("current_state") and fsm.current_state.name.to_lower() == "interact":
		return

	if not (event is InputEventMouseButton and event.pressed): return
	if not player.tile_map_node or not MovementUtils: return

	var clicked_tile = player.tile_map_node.get_hovered_tile()
	if clicked_tile == Vector2i(-9999, -9999): return

	var player_cell = player.get_current_cell()
	var data = player.tile_map_node.world_data.get(clicked_tile, {})

	# ============================================================
	# NHẬN DIỆN HÀNH ĐỘNG
	# ============================================================
	if event.button_index == MOUSE_BUTTON_LEFT:
		_handle_left_click(player_cell, clicked_tile, data)

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(player_cell, clicked_tile, data)


func _handle_left_click(player_cell: Vector2i, clicked_tile: Vector2i, data: Dictionary) -> void:
	if data.get("object", "none") != "none":
		# Click vào object → mine
		_try_interact(player_cell, clicked_tile, "mine_object")
	else:
		# Click vào đất trống → di chuyển
		player.interact_type = ""
		var cell_path = MovementUtils.get_path_cells(player_cell, clicked_tile)
		player.set_path_from_cells(cell_path)


func _handle_right_click(player_cell: Vector2i, clicked_tile: Vector2i, data: Dictionary) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_try_interact(player_cell, clicked_tile, "build_ground")
	else:
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
