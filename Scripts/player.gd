class_name Player 
extends CharacterBody2D

@export var speed: float = 40.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tile_map_node: Node2D = $"../TileMap"
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D

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

var elevation_float: float = 0.0
var elevation_tween: Tween

@export var sprite_fix_x: float = 0.0
@export var sprite_fix_y: float = 0.0


func _ready() -> void:
	# 🔒 KÍCH HOẠT CHẾ ĐỘ PHẲNG TUYỆT ĐỐI CHO PLAYER
	z_index = 0
	y_sort_enabled = true
	
	if visual_root:
		visual_root.y_sort_enabled = false
		visual_root.position = Vector2.ZERO
	if sprite:
		sprite.y_sort_enabled = false

	# Đăng ký hộ khẩu tầng gốc ban đầu
	if tile_map_node:
		call_deferred("reparent", tile_map_node.base_object)
		
	self.modulate = Color.WHITE
	# Dành cho CanvasItem (Node2D), thuộc tính này giúp node không bị ảnh hưởng bởi Modulate của cha
	self.set_meta("original_modulate", true) # (Đánh dấu meta nếu cần thiết)


func _physics_process(_delta: float) -> void:
	if tile_map_node == null: return
	var base_layer = tile_map_node.base_ground
	var player_cell = base_layer.local_to_map(base_layer.to_local(global_position))
	
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)


func _process(_delta: float) -> void:
	var n_factor = 4.0 # Đồng bộ chuẩn chỉ với z_sort_boost của TileMap
	var c_height = float(cliff_height)
	
	# Tính toán lát cắt vị trí ảo theo công thức JohnBrx
	var current_boost = elevation_float * n_factor
	var current_shift = -(elevation_float * c_height)
	
	# Dịch chuyển visual_root nội bộ mà không bật top_level để triệt tiêu 100% lỗi giật lag camera!
	if visual_root:
		visual_root.position = Vector2(0, current_boost)
		
	if sprite:
		# Giữ nguyên Sprite position để tránh xung đột AnimationPlayer
		sprite.position = Vector2(sprite_fix_x, current_shift - current_boost + sprite_fix_y)


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
	
	if elevation_tween and elevation_tween.is_valid():
		elevation_tween.kill()
	
	elevation_tween = get_tree().create_tween()
	elevation_tween.tween_property(self, "elevation_float", float(current_elevation), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	# 🎯 BÍ THUẬT NHẬP CƯ LUÂN PHIÊN CHUẨN ISO:
	# Đổi tầng đến đâu, ném thẳng Player làm con của Layer tương ứng đến đó để Godot tự xử lý Draw Call!
	if tile_map_node and target_elev < tile_map_node.object_layers.size():
		var target_layer = tile_map_node.object_layers[target_elev]
		reparent.call_deferred(target_layer)
