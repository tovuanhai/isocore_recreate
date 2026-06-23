class_name GroundItem
extends Area2D

const MAGNET_SPEED: float = 150.0 # Hút cực nhanh và mượt
const PICKUP_DISTANCE: float = 10.0
const MAGNET_RANGE: float = 60.0   # Tăng tầm hút lên để dễ nhặt hơn (Khoảng 3 ô gạch)
const MAGNET_DELAY: float = 0.5    # Rớt xuống nửa giây là nhặt được

const GRAVITY: float = 500.0
const BOUNCE_DAMPING: float = 0.4

var item_id: StringName = ""
var quantity: int = 1
var durability: int = -1

var _velocity: Vector2 = Vector2.ZERO
var _visual_z: float = 0.0 # 🎯 Trục Z ảo để tưng lên rớt xuống (Hình ảnh)
var _z_velocity: float = 0.0
var _on_ground: bool = false
var _can_be_magnetized: bool = false
var _base_elev_offset: float = 0.0 # Lưu lại độ cao của ngọn đồi nó đang nằm

var _player: Node2D = null
@onready var sprite = $Sprite2D

func _ready() -> void:
	var notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		# Phóng to vùng nhận diện ra to đùng: (-100, -150) là kéo lên trên sang trái, 
		# (200, 200) là kích thước rộng dài. Nó sẽ đánh thức cái cây TRƯỚC KHI camera kịp lia tới!
		notifier.rect = Rect2(-100, -150, 200, 200)
		
		notifier.screen_entered.connect(_on_screen_entered)
		notifier.screen_exited.connect(_on_screen_exited)
		
func setup(id: StringName, amount: int, dur: int = -1) -> void:
	item_id = id
	quantity = amount
	durability = dur
	
	_update_sprite()
	
	# Lưu lại offset đồi núi do hòm đẻ ra truyền cho
	if sprite:
		_base_elev_offset = sprite.offset.y
		
	_launch()
	
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _update_sprite() -> void:
	if sprite == null: return
	var item_data = ItemRegistry.get_item(item_id)
	if item_data and item_data.icon:
		sprite.texture = item_data.icon
	else:
		# Nếu lỡ gõ sai ID, hiện cục vuông tím để cảnh báo thay vì tàng hình
		var placeholder = PlaceholderTexture2D.new()
		placeholder.size = Vector2(16, 16)
		sprite.texture = placeholder

func _launch() -> void:
	_can_be_magnetized = false
	_on_ground = false
	_visual_z = 0.0

	# Bắn tản ra xung quanh trên mặt đất
	var angle = randf_range(0.0, TAU)
	var speed = randf_range(20.0, 50.0)
	_velocity = Vector2(cos(angle), sin(angle) * 0.5) * speed 
	
	# Lực nảy bổng lên trời
	_z_velocity = randf_range(50.0, 90.0) 

	get_tree().create_timer(MAGNET_DELAY).timeout.connect(
		func(): _can_be_magnetized = true
	)

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_process_physics(delta)
		return

	var dist_x = abs(global_position.x - _player.global_position.x)

	# 🎯 ĐÃ SỬA: Chỉ hút về global_position thuần túy, tuyệt đối KHÔNG dùng visual_position!
	var target_pos: Vector2 = _player.global_position 

	if _can_be_magnetized and _on_ground and dist_x < MAGNET_RANGE:
		_process_magnet(delta, target_pos)
	else:
		_process_physics(delta)

func _process_physics(delta: float) -> void:
	if not _on_ground:
		# 1. Trượt ngang/dọc trên mặt đất phẳng
		global_position += _velocity * delta
		_velocity = _velocity.lerp(Vector2.ZERO, delta * 4.0)

		# 2. Xử lý ảo giác rơi tự do (Visual Z)
		_visual_z += _z_velocity * delta
		_z_velocity -= GRAVITY * delta

		if _visual_z <= 0.0:
			_visual_z = 0.0
			_z_velocity *= -BOUNCE_DAMPING
			if abs(_z_velocity) < 20.0:
				_z_velocity = 0.0
				_on_ground = true

	# 3. Kéo giãn Sprite lên trời (bao gồm cả độ cao đồi núi), Tọa độ gốc nằm im!
	if sprite:
		sprite.offset.y = _base_elev_offset - _visual_z

func _process_magnet(delta: float, target_pos: Vector2) -> void:
	global_position = global_position.move_toward(target_pos, MAGNET_SPEED * delta)
	
	if global_position.distance_to(target_pos) < PICKUP_DISTANCE:
		_pickup(_player)

func _pickup(target: Node2D) -> void:
	if not target.has_method("get_inventory"): return
	var inv: Inventory = target.get_inventory()
	if inv == null: return
		
	var remainder = inv.add_item(ItemRegistry.get_item(item_id), quantity, durability)
	if remainder == 0:
		GameEvents.item_picked_up.emit(item_id, quantity)
		queue_free()
	else:
		quantity = remainder

# Hứng tín hiệu thừa từ Scene để Editor không báo lỗi đỏ
func _on_body_entered(_body: Node2D) -> void:
	pass

# 🎯 ĐÃ THÊM HÀM NÀY ĐỂ SPAWNER GỌI TỚI
func set_visual_z(val: float) -> void:
	_visual_z = val

# Bật hiển thị -> Y-Sort hoạt động lại
func _on_screen_entered() -> void:
	var main_sprite = get_node_or_null("Sprite2D2")
	var shadow_sprite = get_node_or_null("Sprite2D")
	if main_sprite: main_sprite.show()
	if shadow_sprite: shadow_sprite.show()

# Tắt hiển thị -> Rút phích cắm Y-Sort, siêu nhẹ máy
func _on_screen_exited() -> void:
	var main_sprite = get_node_or_null("Sprite2D2")
	var shadow_sprite = get_node_or_null("Sprite2D")
	if main_sprite: main_sprite.hide()
	if shadow_sprite: shadow_sprite.hide()
