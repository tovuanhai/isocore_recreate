# PlayerInventoryComponent.gd
# Node component gắn vào Player. Quản lý Inventory của player.
# Player chỉ cần gọi: $InventoryComponent.inventory để truy cập.
# Implement get_inventory() để GroundItem có thể nhặt.
#class_name PlayerInventoryComponent
extends Node

@export var slot_count: int = 30
@export var hotbar_size: int = 9   # Bao nhiêu slot đầu là hotbar

var inventory: Inventory
var equipped_slot_index: int = 0   # Slot đang cầm trên tay (hotbar)

signal hotbar_selection_changed(index: int)

func _ready() -> void:
	inventory = Inventory.new(slot_count)

	# Forward signal lên GameEvents để UI toàn cục có thể lắng nghe
	inventory.changed.connect(func(slot_idx: int):
		GameEvents.inventory_changed.emit(inventory, slot_idx)
	)

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

func handle_hotbar_number_keys(event: InputEvent) -> void:
	for i in hotbar_size:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			select_hotbar_slot(i)

# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Enter — xem túi đồ khi test
		inventory.print_contents()
