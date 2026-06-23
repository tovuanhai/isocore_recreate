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

	inventory.changed.connect(func(slot_idx: int):
		GameEvents.inventory_changed.emit(inventory, slot_idx)
	)
	GameEvents.drop_item_requested.connect(_on_drop_item_requested)
	
	# TEST: Tự động nhét hòm vào túi
	var test_chest = load("res://Resources/Items/wooden_chest.tres")
	var test_bench = load("res://Resources/Items/wooden_bench.tres")
	if test_bench:
		inventory.add_item(test_bench, 1)
	if test_chest:
		inventory.add_item(test_chest, 1)



# ---------------------------------------------------------------------------
# Giao diện truy xuất dữ liệu
# ---------------------------------------------------------------------------
func get_inventory() -> Inventory:
	return inventory

func select_hotbar_slot(index: int) -> void:
	index = clampi(index, 0, hotbar_size - 1)
	if index == equipped_slot_index:
		return
	equipped_slot_index = index
	hotbar_selection_changed.emit(equipped_slot_index)

func get_equipped_slot() -> InventorySlot:
	return inventory.get_slot(equipped_slot_index)

func get_equipped_item() -> ItemData:
	var slot = get_equipped_slot()
	if slot and not slot.is_empty():
		return slot.item
	return null

# ---------------------------------------------------------------------------
# Xử lý Input Hotbar & Drop
# ---------------------------------------------------------------------------
#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_accept"):  # Enter — xem túi đồ khi test
		#inventory.print_contents()

func _input(event: InputEvent) -> void:
	# 1. Phím số
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			set_equipped_slot(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			set_equipped_slot(9)

	# 2. Lăn chuột
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_equipped_slot((equipped_slot_index + 1) % hotbar_size)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_equipped_slot((equipped_slot_index - 1 + hotbar_size) % hotbar_size)

func set_equipped_slot(index: int) -> void:
	if equipped_slot_index != index:
		equipped_slot_index = index
		hotbar_selection_changed.emit(equipped_slot_index)

func _on_drop_item_requested(item_data: ItemData, quantity: int, durability: int) -> void:
	if GROUND_ITEM_SCENE == null: return
	
	var drop_node = GROUND_ITEM_SCENE.instantiate() as GroundItem
	drop_node.global_position = sprite_2d.global_position
	
	var world_layer = get_parent().get_parent()
	if world_layer:
		world_layer.add_child(drop_node)
	
	if drop_node.has_method("setup"):
		drop_node.setup(item_data.id, quantity, durability)
