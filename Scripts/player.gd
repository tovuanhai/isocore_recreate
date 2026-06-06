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
	z_index = 0
	y_sort_enabled = true # Y-Sort gốc của Godot
	
	if visual_root:
		visual_root.z_index = 0
		visual_root.y_sort_enabled = false
		visual_root.position = Vector2.ZERO
	if sprite:
		sprite.z_index = 0
		sprite.y_sort_enabled = false
		
	self.modulate = Color.WHITE

func _physics_process(_delta: float) -> void:
	if tile_map_node == null: return
	var base_layer = tile_map_node.base_ground
	
	# Vì Player luôn di chuyển trên mặt phẳng 2D, hàm này không bao giờ bị sai tọa độ lưới
	var player_cell = base_layer.local_to_map(base_layer.to_local(global_position))
	
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)

func _process(_delta: float) -> void:
	# 🎯 CHÂN LÝ Ở ĐÂY: KHÔNG HACK Z-INDEX, KHÔNG HACK Y-SORT ORIGIN NỮA!
	# Cả cơ thể Mèo ở Y=0 phẳng. Ta chỉ KÉO MỖI BỨC ẢNH BAY LÊN TRỜI.
	var c_height = float(cliff_height)
	if sprite:
		sprite.position = Vector2(sprite_fix_x, -(elevation_float * c_height) + sprite_fix_y)

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
		var cell_path = MovementUtils.get_path_cells(player_cell, clicked_tile)
		_set_path_from_cells(cell_path)

func _set_path_from_cells(cell_path: Array[Vector2i]) -> void:
	current_path.clear()
	var base_layer = tile_map_node.base_ground
	for cell in cell_path:
		var local_pos = base_layer.map_to_local(cell)
		# Đường đi phẳng hoàn toàn
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
