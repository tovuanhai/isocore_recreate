class_name Player
extends CharacterBody2D

@export var speed: float = 50.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tile_map_node: Node2D = $"../TileMap"
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D
@onready var sprite2 = $VisualRoot/Sprite2D2

# --- PATH & INTERACT ---
var current_path: Array[Vector2] = []
var last_dir: String = "dr"
var interact_tile: Vector2i = Vector2i(-9999, -9999)
var interact_type: String = ""

# --- ELEVATION ---
@export var cliff_height: int = 6
var current_elevation: int = 0
var elevation_float: float = 0.0
var elevation_tween: Tween

# --- VISUAL FIX ---
@export var sprite_fix_x: float = 0.0
@export var sprite_fix_y: float = 0.0

# 🎯 BIẾN MỚI CHO JUMP STATE
var current_jump_z: float = 0.0

@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var _last_elev_cell: Vector2i = Vector2i(9999, 9999)

# Node vùng nam châm để đi hút đồ rơi
var magnet_zone: Area2D

func _ready() -> void:
	z_index = 0
	y_sort_enabled = true

	if visual_root:
		visual_root.z_index = 0
		visual_root.y_sort_enabled = false
		visual_root.position = Vector2.ZERO
	if sprite:
		sprite.z_index = 0
		sprite.y_sort_enabled = false

	self.modulate = Color.WHITE
	GameEvents.tile_hit.connect(_on_player_interact)

func get_visual_position() -> Vector2:
	return sprite.global_position

func _physics_process(delta: float) -> void:
	if not tile_map_node: return
	
	# 🎯 ĐÃ ĐỒNG BỘ: Không gọi process_movement ở đây nữa, 
	# toàn bộ di chuyển sẽ do StateMachine điều phối thông qua Autoload.
	
	var player_cell = tile_map_node.base_ground.local_to_map(
		tile_map_node.base_ground.to_local(global_position)
	)
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)

func _process(_delta: float) -> void:
	# 🎯 Trừ thêm current_jump_z để nhấc bổng hình ảnh lên không trung
	var visual_offset_y = -(elevation_float * float(cliff_height)) - current_jump_z
	
	if sprite:
		sprite.position = Vector2(sprite_fix_x, visual_offset_y + sprite_fix_y)
		sprite2.position = Vector2(sprite_fix_x, visual_offset_y + sprite_fix_y)
	
	# Nhớ là tuyệt đối KHÔNG ĐỤNG chạm gì tới col_shape nhé!
	if is_instance_valid(magnet_zone):
		magnet_zone.position.y = visual_offset_y

# ============================================================
# INVENTORY DATA INTERFACE
# ============================================================
func get_inventory() -> Inventory:
	return $PlayerInventoryComponent.get_inventory()

# ============================================================
# PUBLIC HELPERS
# ============================================================
func get_4_way_dir(angle: float) -> String:
	if angle >= 0 and angle < 90: return "dr"
	elif angle >= 90 and angle <= 180: return "dl"
	elif angle >= -180 and angle < -90: return "ul"
	else: return "ur"

func set_path_from_cells(cell_path: Array[Vector2i]) -> void:
	current_path.clear()
	var base_layer = tile_map_node.base_ground
	for cell in cell_path:
		current_path.append(base_layer.to_global(base_layer.map_to_local(cell)))

func get_current_cell() -> Vector2i:
	return tile_map_node.base_ground.local_to_map(
		tile_map_node.base_ground.to_local(global_position)
	)

# ============================================================
# ELEVATION
# ============================================================
func _update_player_elevation(cell: Vector2i) -> void:
	if not tile_map_node.world_data.has(cell): return

	var data = tile_map_node.world_data[cell]
	var target_elev: int
	if data.get("is_water", false):
		target_elev = tile_map_node.water_level
	else:
		target_elev = data.get("z", 0)

	if target_elev == current_elevation: return
	current_elevation = target_elev

	if elevation_tween and elevation_tween.is_valid():
		elevation_tween.kill()

	elevation_tween = get_tree().create_tween()
	elevation_tween.tween_property(self, "elevation_float", float(current_elevation), 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_player_interact(_player, _cell, _action, _dmg):
	pass
