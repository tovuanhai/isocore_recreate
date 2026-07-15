class_name Player
extends CharacterBody2D

@export var speed: float = 50.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tile_map_node: Node2D = $"../TileMap"

@onready var visual_root: Node2D = $VisualRoot
@onready var sprite2: Sprite2D = $VisualRoot/Sprite2D
@onready var shadow_sprite: Sprite2D = $VisualRoot/ShadowSprite # 🎯 Nhớ sửa dòng này

# --- PATH & INTERACT ---
var current_path: Array[Vector2] = []
var last_dir: String = "dr"
var interact_tile: Vector2i = Vector2i(-9999, -9999)
var interact_type: String = ""

# --- ELEVATION & JUMP ---
@export var cliff_height: int = 6
var current_elevation: int = 0
var elevation_float: float = 0.0
var elevation_tween: Tween

@export var sprite_fix_x: float = 0.0
@export var sprite_fix_y: float = 0.0
var current_jump_z: float = 0.0

@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
var magnet_zone: Area2D
var _last_elev_cell: Vector2i = Vector2i(9999, 9999)

func _ready() -> void:
	z_index = 0
	y_sort_enabled = true

	if visual_root:
		visual_root.z_index = 0
		visual_root.y_sort_enabled = false
		visual_root.position = Vector2.ZERO
		
	if shadow_sprite:
		shadow_sprite.z_index = 0
		shadow_sprite.y_sort_enabled = false
		
	magnet_zone = get_node_or_null("MagnetZone") # Tự điền tên Area2D nhặt đồ của ông vào đây nếu cần
	self.modulate = Color.WHITE
	GameEvents.tile_hit.connect(_on_player_interact)

func get_visual_position() -> Vector2:
	return sprite2.global_position if sprite2 else global_position

func _physics_process(delta: float) -> void:
	if not tile_map_node: return
	var player_cell = tile_map_node.base_ground.local_to_map(
		tile_map_node.base_ground.to_local(global_position)
	)
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)

func _process(_delta: float) -> void:
	# 1. 🚨 KHÓA CHẾT KHIÊN Y-SORT Ở MẶT ĐẤT
	if visual_root:
		visual_root.position = Vector2.ZERO 
		
	# 2. Tính toán các mốc độ cao
	var base_elev_y = -(elevation_float * float(cliff_height))
	var cat_y = base_elev_y - current_jump_z
	
	# 3. Kéo con mèo bay lên
	if sprite2:
		sprite2.position = Vector2(sprite_fix_x, cat_y + sprite_fix_y)
		
	# 4. Ép cái bóng nằm im dưới đồi, nhảy lên thì thu nhỏ
	if shadow_sprite:
		shadow_sprite.position.y = base_elev_y
		
		# Thu nhỏ bóng khi nhảy (Bóp scale từ 1.0 xuống 0.3)
		var shadow_scale = clampf(1.0 - (current_jump_z / 80.0), 0.3, 1.0)
		shadow_sprite.scale = Vector2(shadow_scale, shadow_scale)
		shadow_sprite.modulate.a = shadow_scale * 0.7 
		
	if is_instance_valid(magnet_zone):
		magnet_zone.position.y = cat_y

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

func get_current_cell() -> Vector2i:
	if not tile_map_node: return Vector2i.ZERO
	return tile_map_node.base_ground.local_to_map(
		tile_map_node.base_ground.to_local(global_position)
	)

func _on_player_interact(_player, _cell, _action, _dmg):
	pass

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

func get_inventory() -> RefCounted:
	var comp = get_node_or_null("PlayerInventoryComponent")
	if comp and comp.has_method("get_inventory"):
		return comp.get_inventory()
	return null
