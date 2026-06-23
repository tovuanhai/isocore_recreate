extends StaticBody2D

@export var chest_item_id: String = "wooden_chest" 
@export var max_health: int = 3 # 🎯 SỐ MÁU CỦA CÁI HÒM

const GROUND_ITEM_SCENE = preload("res://Scenes/GroundItem.tscn")
const INTERACT_DISTANCE = 60.0 

var chest_inventory: Inventory
var current_health: int # Máu hiện tại

func _ready() -> void:
	y_sort_enabled = true
	current_health = max_health 
	_ensure_inventory()
	
	# 🎯 Nối dây tín hiệu từ cái Mắt thần vào Rương
	var interact_comp = get_node_or_null("InteractComponent")
	if interact_comp:
		interact_comp.interacted.connect(_on_chest_interacted)

func _ensure_inventory() -> void:
	if chest_inventory == null:
		chest_inventory = Inventory.new(20)
		# 🎯 ĐÃ XÓA CODE TEST ĐÁ Ở ĐÂY! Bây giờ hòm sinh ra sẽ trống rỗng 100%

func init(z: int, cliff_h: int) -> void:
	var elev_shift = z * cliff_h
	var main_sprite = get_node_or_null("Sprite2D2")
	if main_sprite:
		main_sprite.offset.y -= elev_shift
		main_sprite.show()
	var shadow_sprite = get_node_or_null("Sprite2D")
	if shadow_sprite: 
		shadow_sprite.offset.y -= elev_shift

# ==============================================================================
# HỆ THỐNG VẬT LÝ VÀ PHÁ HỦY TÍCH HỢP CHO TOOL (CUỐC/RÌU)
# ==============================================================================

# Hàm này được gọi từ interact_state.gd khi người chơi cuốc trúng
func take_damage(amount: int) -> void:
	current_health -= amount
	
	# Tại đây ông có thể gọi Animation hoặc đổi màu Sprite chớp đỏ cho cái Hòm
	# Ví dụ: $AnimationPlayer.play("hit")
	
	if current_health <= 0:
		break_object()

func break_object() -> void:
	_ensure_inventory()
	
	# Xả sạch đồ bên trong rương ra đất
	for i in range(chest_inventory.size):
		var slot = chest_inventory.get_slot(i)
		if slot != null and not slot.is_empty():
			_spawn_dropped_item(slot.item, slot.quantity, slot.durability)
			
	# Rớt chính cái xác Hòm Gỗ ra đất
	var chest_data = ItemRegistry.get_item(chest_item_id)
	if chest_data:
		_spawn_dropped_item(chest_data, 1, -1)
		
	_cleanup_map_data()
	queue_free()
	
# Hàm này sẽ được gọi khi Mèo chỉ chuột vào Rương và bấm E
func _on_chest_interacted() -> void:
	_ensure_inventory()
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_inv_comp = players[0].get_node_or_null("PlayerInventoryComponent")
		if player_inv_comp:
			# Bắn loa gọi UI mở cả 2 hòm lên
			GameEvents.chest_opened.emit(chest_inventory, player_inv_comp.inventory)

func _spawn_dropped_item(item: ItemData, amount: int, dur: int) -> void:
	if GROUND_ITEM_SCENE == null or item == null: return
	
	var drop = GROUND_ITEM_SCENE.instantiate()
	drop.z_index = 1 # Đảm bảo item nổi lên cỏ
	
	# Tính toán tọa độ và offset trước
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	var final_pos = self.global_position + random_offset
	
	var final_offset_y = 0.0
	var my_main_sprite = get_node_or_null("Sprite2D2")
	if my_main_sprite: 
		final_offset_y = my_main_sprite.offset.y
	
	# 🎯 ĐÃ SỬA: Đẻ trực tiếp ra Scene Tree, KHÔNG dùng call_deferred hay func() nữa!
	get_tree().current_scene.add_child(drop)
	
	# Nạp thông số ngay lập tức
	drop.global_position = final_pos
	var drop_sprite = drop.get_node_or_null("Sprite2D")
	if drop_sprite: 
		drop_sprite.offset.y = final_offset_y
		
	if drop.has_method("setup"): 
		drop.setup(item.id, amount, dur)

func _cleanup_map_data() -> void:
	var tile_map = get_tree().current_scene.get_node_or_null("TileMap")
	
	if tile_map and tile_map.get("base_ground"):
		var local_pos = tile_map.base_ground.to_local(global_position)
		var cell = tile_map.base_ground.local_to_map(local_pos)
		
		if tile_map.world_data.has(cell):
			tile_map.world_data[cell]["object"] = "none" 
			if tile_map.spawned_objects.has(cell):
				tile_map.spawned_objects.erase(cell)
			tile_map._refresh_astar(cell)
