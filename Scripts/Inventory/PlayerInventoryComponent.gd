# PlayerInventoryComponent.gd
# Node component gắn vào Player. Quản lý Inventory của player.
# Player chỉ cần gọi: $InventoryComponent.inventory để truy cập.
# Implement get_inventory() để GroundItem có thể nhặt.
#class_name PlayerInventoryComponent
extends Node

@export var slot_count: int = 30
@export var hotbar_size: int = 10   # Bao nhiêu slot đầu là hotbar

var inventory: Inventory
var equipped_slot_index: int = 0   # Slot đang cầm trên tay (hotbar)

@onready var sprite_2d = $"../VisualRoot/Sprite2D"

const GROUND_ITEM_SCENE = preload("res://Scenes/GroundItem.tscn")

signal hotbar_selection_changed(index: int)

func _ready() -> void:
	inventory = Inventory.new(slot_count)

	# Forward signal lên GameEvents để UI toàn cục có thể lắng nghe
	inventory.changed.connect(func(slot_idx: int):
		GameEvents.inventory_changed.emit(inventory, slot_idx)
	)
	# Bật tai nghe lắng nghe tiếng loa vứt đồ
	GameEvents.drop_item_requested.connect(_on_drop_item_requested)
	
	# ----------------------------------------------------------------------
	# 🎯 CODE TEST: Tự động nhét Cuốc Gỗ vào túi lúc mới vào game
	# ----------------------------------------------------------------------
	var test_pickaxe = load("res://Resources/Items/wooden_pickaxe.tres")
	if test_pickaxe:
		# Thêm 1 cây cuốc vào túi. Nó sẽ tự chui vào ô Hotbar đầu tiên (index 0)
		inventory.add_item(test_pickaxe, 1)

# ---------------------------------------------------------------------------
# Giao diện cho GroundItem
# ---------------------------------------------------------------------------
func get_inventory() -> Inventory:
	return inventory

# ---------------------------------------------------------------------------
# Hotbar — đổi slot cầm trên tay
# ---------------------------------------------------------------------------
func select_hotbar_slot(index: int) -> void:
	index = clampi(index, 0, hotbar_size - 1)
	if index == equipped_slot_index:
		return
	equipped_slot_index = index
	hotbar_selection_changed.emit(equipped_slot_index)

func get_equipped_slot() -> InventorySlot:
	return inventory.get_slot(equipped_slot_index)

# Trả về ItemData đang cầm (null nếu tay không)
func get_equipped_item() -> ItemData:
	var slot = get_equipped_slot()
	if slot and not slot.is_empty():
		return slot.item
	return null

# ---------------------------------------------------------------------------
# Input cuộn hotbar (gọi từ Player._input hoặc _unhandled_input)
# ---------------------------------------------------------------------------
func handle_hotbar_scroll(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			select_hotbar_slot(equipped_slot_index - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			select_hotbar_slot(equipped_slot_index + 1)

# Sửa lại hàm hứng phím số 1 -> 0
func handle_hotbar_number_keys(event: InputEvent) -> void:
	for i in hotbar_size:
		# Thuật toán lấy số action: i=0->phím 1, ..., i=8->phím 9, i=9->phím 0
		var key_num = (i + 1) % 10 
		if Input.is_action_just_pressed("hotbar_%d" % key_num):
			select_hotbar_slot(i)

# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Enter — xem túi đồ khi test
		inventory.print_contents()

func _input(event: InputEvent) -> void:
	# ---------------------------------------------------------
	# 1. XỬ LÝ NHẤN PHÍM SỐ (1 -> 9, và 0)
	# ---------------------------------------------------------
	if event is InputEventKey and event.pressed and not event.echo:
		# Nếu bấm từ phím 1 đến phím 9 (Index từ 0 đến 8)
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var target_index = event.keycode - KEY_1
			set_equipped_slot(target_index)
			
		# Nếu bấm phím 0 (Index 9 - Ô cuối cùng)
		elif event.keycode == KEY_0:
			set_equipped_slot(9)


	# ---------------------------------------------------------
	# 2. XỬ LÝ LĂN CHUỘT (WHEEL UP / WHEEL DOWN)
	# ---------------------------------------------------------
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Cuộn xuống -> Dịch qua phải 1 ô. Nếu đang ở ô cuối thì vòng lại ô đầu (0)
			var new_idx = (equipped_slot_index + 1) % hotbar_size
			set_equipped_slot(new_idx)
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Cuộn lên -> Dịch sang trái 1 ô. Nếu đang ở ô đầu thì vòng xuống ô cuối (9)
			var new_idx = (equipped_slot_index - 1 + hotbar_size) % hotbar_size
			set_equipped_slot(new_idx)

# Hàm chuẩn hóa việc chuyển ô và bắn tín hiệu cho UI biết
func set_equipped_slot(index: int) -> void:
	# Chỉ xử lý nếu chọn ô mới, tránh Spam code
	if equipped_slot_index != index:
		equipped_slot_index = index
		hotbar_selection_changed.emit(equipped_slot_index)

func _on_drop_item_requested(item_data: ItemData, quantity: int, durability: int) -> void:
	if GROUND_ITEM_SCENE == null: 
		return
	
	var drop_node = GROUND_ITEM_SCENE.instantiate() as GroundItem
	var player = get_parent()
	
	# Gán vị trí xuất phát
	drop_node.global_position = sprite_2d.global_position 
	
	var world_layer = player.get_parent()
	
	# 🎯 ĐÃ SỬA: Dùng add_child trực tiếp thay vì call_deferred
	world_layer.add_child(drop_node)
	
	# Bây giờ cục đồ đã nằm chắc chắn trong Tree rồi, gọi setup() thoải mái không bao giờ lỗi!
	if drop_node.has_method("setup"):
		drop_node.setup(item_data.id, quantity, durability)
