class_name Player 
extends CharacterBody2D

@export var speed: float = 40.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# Tham chiếu trực tiếp đến Node TileMap và các lớp con của nó
@onready var tile_map_node: Node2D = $"../TileMap"
@onready var tilemap_layer: TileMapLayer = $"../TileMap/Layer0"
@onready var blocked_layer: TileMapLayer = $"../TileMap/Layer1"

# Kho chứa dữ liệu dùng chung (Giữ nguyên cho các State con gọi)
var current_path: Array[Vector2] = []
var last_dir: String = "dr" 
var pending_mine_tile: Vector2i = Vector2i.ZERO 
var has_pending_mine: bool = false               

@export var default_max_hits: int = 3
@export var indestructible_alternative_id: int = 1
var tile_durability: Dictionary = {}

# Bắt click chuột để vẽ đường di chuyển / đào đá
func _unhandled_input(event: InputEvent) -> void:
	# Báo FSM: Đang đập đá cấm click linh tinh
	var fsm = $StateMachine
	if fsm.current_state and fsm.current_state.name.to_lower() == "mine":
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target_mouse_pos = get_global_mouse_position()
		
		if tilemap_layer != null and blocked_layer != null and tile_map_node != null:
			# Dùng hàm chuẩn của chính TileMap để lấy ô đang hover chuột
			var clicked_tile = tile_map_node.get_hovered_tile()
			
			# Nếu click trượt ra ngoài vùng đất đã generate thì bỏ qua
			if clicked_tile == Vector2i(-9999, -9999):
				return
			
			# TRƯỜNG HỢP 1: CLICK VÀO Ô CÓ ĐÁ/OBJECT THỀM LAYER 1
			if blocked_layer.get_cell_source_id(clicked_tile) != -1:
				var player_tile = tilemap_layer.local_to_map(tilemap_layer.to_local(global_position))
				var neighbors = tilemap_layer.get_surrounding_cells(clicked_tile)
				
				# Nếu đang đứng ngay cạnh cục đá rồi -> Đập luôn, không đi đâu cả
				if player_tile in neighbors:
					current_path.clear()
					pending_mine_tile = clicked_tile
					has_pending_mine = true
				else:
					# Tìm một ô đất trống xung quanh cục đá để đi tới đó rồi mới đập
					var chosen_neighbor = Vector2i(-9999, -9999)
					var found = false
					for neighbor in neighbors:
						if blocked_layer.get_cell_source_id(neighbor) == -1 and tilemap_layer.get_cell_source_id(neighbor) != -1:
							chosen_neighbor = neighbor
							found = true
							break
					
					if found:
						# ĐỒNG BỘ: Gọi hàm tìm đường mới sang tọa độ Cell (Vector2i)
						var new_path = MovementUtils.get_path_to_tile(global_position, chosen_neighbor, tilemap_layer)
						_set_path(new_path)
						pending_mine_tile = clicked_tile
						has_pending_mine = true
			
			# TRƯỜNG HỢP 2: CLICK VÀO Ô ĐẤT TRỐNG ĐỂ DI CHUYỂN BÌNH THƯỜNG
			else:
				has_pending_mine = false 
				# ĐỒNG BỘ: Truyền clicked_tile (Vector2i) và layer0 vào hàm tìm đường mới
				var new_path = MovementUtils.get_path_to_tile(global_position, clicked_tile, tilemap_layer)
				_set_path(new_path)

func _set_path(new_path: Array[Vector2]) -> void:
	current_path.clear()
	for point in new_path:
		current_path.append(point)

func get_4_way_dir(angle: float) -> String:
	if angle >= 0 and angle < 90: return "dr"
	elif angle >= 90 and angle <= 180: return "dl"
	elif angle >= -180 and angle < -90: return "ul"
	else: return "ur"
