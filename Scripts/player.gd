class_name Player 
extends CharacterBody2D

@export var speed: float = 40.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tile_map_node: Node2D = $"../TileMap"
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D2

var _last_elev_cell: Vector2i = Vector2i(9999, 9999)
var current_path: Array[Vector2] = []
var last_dir: String = "dr" 
var pending_mine_tile: Vector2i = Vector2i.ZERO 
var has_pending_mine: bool = false               

@export var default_max_hits: int = 3
@export var indestructible_alternative_id: int = 1
var tile_durability: Dictionary = {}

@export var cliff_height: int = 6
var current_elevation: int = 0

# 🎯 BIẾN BẢO VỆ PIVOT CHỐNG BAY LƠ LỬNG
var base_sprite_offset: Vector2 = Vector2.ZERO
var z_shift_y: float = 0.0
var elevation_tween: Tween

func _ready() -> void:
	y_sort_enabled = true
	
	if sprite:
		sprite.y_sort_enabled = true
		sprite.set("y_sort_origin", -48)     # ← Đặt trên Sprite, giá trị lớn
	
	if visual_root:
		visual_root.y_sort_enabled = true
	
	if sprite:
		base_sprite_offset = sprite.offset



func _physics_process(_delta: float) -> void:
	if tile_map_node == null: return
	var base_layer = tile_map_node.base_ground
	var player_cell = base_layer.local_to_map(base_layer.to_local(global_position))
	
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)


func _process(_delta: float) -> void:
	if visual_root:
		# Dịch cả cụm visual theo chiều cao (chính xác hơn offset rất nhiều)
		visual_root.position = Vector2(0, z_shift_y)
		
	
	# Nếu vẫn muốn giữ offset riêng của sprite (căn art), giữ dòng này:
	if sprite:
		sprite.offset = base_sprite_offset

func _unhandled_input(event: InputEvent) -> void:
	var fsm = get_node_or_null("StateMachine")
	if fsm and fsm.get("current_state") and fsm.current_state.name.to_lower() == "mine":
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if tile_map_node == null or MovementUtils == null: return
			
		var clicked_tile = tile_map_node.get_hovered_tile()
		if clicked_tile == Vector2i(-9999, -9999): return
			
		var base_layer = tile_map_node.base_ground
		var player_cell = base_layer.local_to_map(base_layer.to_local(global_position))
		var clicked_elev = tile_map_node.get_cell_elevation(clicked_tile)
		
		if clicked_elev != -1 and tile_map_node.has_obstacle(clicked_tile, clicked_elev):
			var neighbors = base_layer.get_surrounding_cells(clicked_tile)
			if player_cell in neighbors:
				current_path.clear()
				pending_mine_tile = clicked_tile
				has_pending_mine = true
			else:
				var chosen_neighbor = Vector2i(-9999, -9999)
				var found = false
				for neighbor in neighbors:
					var n_elev = tile_map_node.get_cell_elevation(neighbor)
					if n_elev != -1 and not tile_map_node.has_obstacle(neighbor, n_elev):
						chosen_neighbor = neighbor
						found = true
						break
				if found:
					var cell_path = MovementUtils.get_path_cells(player_cell, chosen_neighbor)
					_set_path_from_cells(cell_path)
					pending_mine_tile = clicked_tile
					has_pending_mine = true
		else:
			has_pending_mine = false 
			var cell_path = MovementUtils.get_path_cells(player_cell, clicked_tile)
			_set_path_from_cells(cell_path)

func _set_path_from_cells(cell_path: Array[Vector2i]) -> void:
	current_path.clear()
	var base_layer = tile_map_node.base_ground
	for cell in cell_path:
		var local_pos = base_layer.map_to_local(cell)
		var global_pos = base_layer.to_global(local_pos)
		current_path.append(global_pos)

func get_4_way_dir(angle: float) -> String:
	if angle >= 0 and angle < 90: return "dr"
	elif angle >= 90 and angle <= 180: return "dl"
	elif angle >= -180 and angle < -90: return "ul"
	else: return "ur"

func _update_player_elevation(cell: Vector2i) -> void:
	var target_elev = tile_map_node.get_cell_elevation(cell)
	if target_elev == -1 or target_elev == current_elevation:
		return
	
	current_elevation = target_elev
	
	var ch = tile_map_node.cliff_height if tile_map_node else cliff_height
	var target_shift = float(- (ch * current_elevation))
	
	if elevation_tween and elevation_tween.is_valid():
		elevation_tween.kill()
	
	elevation_tween = get_tree().create_tween()
	elevation_tween.tween_property(self, "z_shift_y", target_shift, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# === Y-SORT + Z_INDEX (phiên bản ổn định) ===
	if sprite:
		sprite.y_sort_enabled = true
		sprite.set("y_sort_origin", -22)          # Giá trị này khá tốt, bạn có thể chỉnh -18 ~ -26
	
	# z_index an toàn nhưng vẫn đủ mạnh
	var base_layer = tile_map_node.base_ground
	var player_cell = base_layer.local_to_map(base_layer.to_local(global_position))
	#z_index = current_elevation * 2 + 1
