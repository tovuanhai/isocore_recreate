class_name GroundItem
extends Area2D

const MAGNET_SPEED: float = 50.0
const PICKUP_DISTANCE: float = 5.0
const MAGNET_RANGE: float = 15.0   # Khoảng cách bắt đầu hút (thay Area2D)
const MAGNET_DELAY: float = 0.6   # Giây chờ trước khi cho phép hút

const GRAVITY: float = 300.0
const BOUNCE_DAMPING: float = 0.35

var item_id: StringName = ""
var quantity: int = 1
var durability: int = -1

var _velocity: Vector2 = Vector2.ZERO
var _vertical_velocity: float = 0.0
var _on_ground: bool = false
var _ground_y: float = 0.0
var _can_be_magnetized: bool = false

# Player reference — tìm tự động qua group
var _player: Node2D = null

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(id: StringName, amount: int, dur: int = -1) -> void:
	item_id = id
	quantity = amount
	durability = dur # <-- Lưu lại độ bền thực tế vào biến của GroundItem
	
	_update_sprite()
	_launch()
	
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _update_sprite() -> void:
	var spr = get_node_or_null("Sprite2D")
	if spr == null:
		return
	var item_data = ItemRegistry.get_item(item_id)
	if item_data and item_data.icon:
		spr.texture = item_data.icon
	else:
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(16, 16)
		spr.texture = placeholder

func _launch() -> void:
	_ground_y = global_position.y
	_can_be_magnetized = false

	var angle = randf_range(0.0, TAU)
	var speed = randf_range(40.0, 90.0)
	_velocity = Vector2(cos(angle), sin(angle) * 0.5) * speed
	_vertical_velocity = randf_range(-50.0, -30.0)

	get_tree().create_timer(MAGNET_DELAY).timeout.connect(
		func(): _can_be_magnetized = true
	)

# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_process_physics(delta)
		return

	# Lấy vị trí visual của player để so sánh
	var target_pos: Vector2
	if _player.has_method("get_visual_position"):
		target_pos = _player.get_visual_position()
	else:
		target_pos = _player.global_position

	# Chỉ tính khoảng cách X vì world isometric — Y bị lệch do elevation
	var dist = global_position.distance_to(target_pos)

	if _can_be_magnetized and dist < MAGNET_RANGE:
		_process_magnet(delta, target_pos)
	else:
		_process_physics(delta)

func _process_physics(delta: float) -> void:
	if _on_ground:
		return

	global_position += _velocity * delta
	_velocity = _velocity.lerp(Vector2.ZERO, delta * 3.0)

	_vertical_velocity += GRAVITY * delta
	global_position.y += _vertical_velocity * delta

	if global_position.y >= _ground_y:
		global_position.y = _ground_y
		_vertical_velocity *= -BOUNCE_DAMPING
		if abs(_vertical_velocity) < 8.0:
			_vertical_velocity = 0.0
			_on_ground = true

	## Z-index theo vị trí Y để nằm đúng depth
	#z_index = int(global_position.y / 10)

func _process_magnet(delta: float, target_pos: Vector2) -> void:
	global_position = global_position.move_toward(target_pos, MAGNET_SPEED * delta)
	z_index = int(global_position.y / 10)

	if global_position.distance_to(target_pos) < PICKUP_DISTANCE:
		_pickup(_player)

# ---------------------------------------------------------------------------
# Pickup
# ---------------------------------------------------------------------------
func _pickup(target: Node2D) -> void:
	if not target.has_method("get_inventory"):
		return
	var inv: Inventory = target.get_inventory()
	if inv == null:
		return
		
	# 🎯 ĐÃ SỬA: Truyền thêm biến durability đang lưu dưới đất vào lại túi đồ
	var remainder = inv.add_item(ItemRegistry.get_item(item_id), quantity, durability)
	
	if remainder == 0:
		GameEvents.item_picked_up.emit(item_id, quantity)
		queue_free()
	else:
		quantity = remainder
