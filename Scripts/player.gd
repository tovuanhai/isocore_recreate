class_name Player
extends CharacterBody2D

@export var speed: float = 40.0
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var tile_map_node: Node2D = $"../TileMap"
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: Sprite2D = $VisualRoot/Sprite2D

#@export var inventory: Inventory

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

@onready var col_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var _last_elev_cell: Vector2i = Vector2i(9999, 9999)

# 🎯 ĐÃ THÊM: Node vùng nam châm để đi hút đồ rơi
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

	# 🎯 ĐÃ THÊM: Tự động khởi tạo Nam Châm Hút Đồ bằng Code 100% sạch sẽ
	# Không bắt ông phải vào Editor tạo bằng tay, tránh lỗi cấu hình sai Layer/Mask
	#_setup_magnet_physics()

	GameEvents.tile_hit.connect(_on_player_interact)

func get_visual_position() -> Vector2:
	return sprite.global_position

func _physics_process(_delta: float) -> void:
	if not tile_map_node: return
	var player_cell = tile_map_node.base_ground.local_to_map(
		tile_map_node.base_ground.to_local(global_position)
	)
	if player_cell != _last_elev_cell:
		_last_elev_cell = player_cell
		_update_player_elevation(player_cell)


func _process(_delta: float) -> void:
	var visual_offset_y = -(elevation_float * float(cliff_height))
	if sprite:
		sprite.position = Vector2(sprite_fix_x, visual_offset_y + sprite_fix_y)
	if col_shape:
		col_shape.position.y = visual_offset_y
		
	# Đẩy vị trí Nam châm chạy theo cao độ thực tế của Player liên tục để hút chuẩn xác
	if is_instance_valid(magnet_zone):
		magnet_zone.position.y = visual_offset_y


# ============================================================
# INVENTORY DATA INTERFACE (Cơ chế lấy túi đồ chuẩn mẫu)
# ============================================================

func get_inventory() -> Inventory:
	return $PlayerInventoryComponent.get_inventory()


# ============================================================
# MAGNET PHYSICS SYSTEM (Hệ thống vật lý hút đồ tự động)
# ============================================================

#func _setup_magnet_physics() -> void:
	#magnet_zone = Area2D.new()
	#magnet_zone.name = "MagnetZone"
	#
	## Cấu hình quét va chạm: Tắt Layer để không cản đường ai
	#magnet_zone.collision_layer = 0
	## Quét Mask số 3 (layer "items" — nơi GroundItem nằm)
	#magnet_zone.collision_mask = 4  # bit 3 = giá trị 4
	#
	#var shape_node = CollisionShape2D.new()
	#var circle_shape = CircleShape2D.new()
	#circle_shape.radius = 60.0 # Bán kính nam châm quét đồ to đùng theo ý ông
	#shape_node.shape = circle_shape
	#
	#magnet_zone.add_child(shape_node)
	#add_child(magnet_zone)
	
	#magnet_zone.area_entered.connect(_on_magnet_zone_area_entered)
	#magnet_zone.area_exited.connect(_on_magnet_zone_area_exited)

#
#func _on_magnet_zone_area_entered(area: Area2D) -> void:
	#if area is GroundItem:
		#area.activate_magnet(self)
#
#
#func _on_magnet_zone_area_exited(area: Area2D) -> void:
	#if area is GroundItem:
		#area.deactivate_magnet()


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


# Fallback để tránh lỗi nếu kết nối sự kiện cũ từ TileMap chưa dọn sạch
func _on_player_interact(_player, _cell, _action, _dmg):
	pass
