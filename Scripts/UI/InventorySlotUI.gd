class_name InventorySlotUI
extends Control

@onready var icon: TextureRect = $Icon
@onready var quantity_label: Label = $QuantityLabel
@onready var durability_bar: ProgressBar = $DurabilityBar
@onready var highlight_border: TextureRect = $HighlightBorder

# Thêm cái onready này ở trên đầu file chung với đống Label cũ
@onready var hotbar_number_label: Label = $HotbarNumberLabel

var slot_index: int = -1
var inventory_ref: Inventory
var _is_hotbar_slot: bool = false # Biến nội bộ

func _ready() -> void:
	_clear_visual()
	# Bật cảm biến lắng nghe chuột ra/vào
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_as_hotbar() -> void:
	_is_hotbar_slot = true

func update_slot(slot: InventorySlot, inv: Inventory = null) -> void:
	if inv != null:
		inventory_ref = inv

	# 🎯 ĐÃ SỬA: Chỉ hiện số NẾU lưới này được đánh dấu là Hotbar
	if _is_hotbar_slot and slot_index >= 0 and slot_index < 10:
		if slot_index == 9:
			hotbar_number_label.text = "0"
		else:
			hotbar_number_label.text = str(slot_index + 1)
		hotbar_number_label.show()
	else:
		hotbar_number_label.hide()

	# --- Đống code check icon, quantity, durability cũ của ông giữ nguyên ở dưới này ---
	if slot == null or slot.is_empty():
		_clear_visual()
		return

	if slot.item and slot.item.icon:
		icon.texture = slot.item.icon
		icon.show()
	else:
		icon.hide()

	if slot.quantity > 1:
		quantity_label.text = str(slot.quantity)
		quantity_label.show()
	else:
		quantity_label.hide()

	if slot.durability >= 0 and slot.item is ToolData:
		var tool_data = slot.item as ToolData
		durability_bar.max_value = tool_data.max_durability
		durability_bar.value = slot.durability
		durability_bar.show()
	else:
		durability_bar.hide()


func set_highlight(active: bool) -> void:
	if highlight_border:
		highlight_border.visible = active


func _clear_visual() -> void:
	if icon: icon.texture = null; icon.hide()
	if quantity_label: quantity_label.hide()
	if durability_bar: durability_bar.hide()
	if highlight_border: highlight_border.hide()


# ---------------------------------------------------------------------------
# 🎯 ĐÃ THÊM: Bắt sự kiện click chuột để kích hoạt hệ thống Click-to-Pick
# ---------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if inventory_ref != null and slot_index >= 0:
			# Bắn loa thông báo cho đầu não biết ô này vừa bị click trúng
			GameEvents.ui_slot_clicked.emit(inventory_ref, slot_index)
			# 🎯 THÊM DÒNG NÀY: Đánh dấu "Tao xử lý click rồi", cấm rớt tín hiệu xuống game làm Mèo chạy!
			accept_event()

# ---------------------------------------------------------------------------
# CẢM BIẾN TOOLTIP (KHI CHUỘT RÀ VÀO / BAY RA)
# ---------------------------------------------------------------------------
func _on_mouse_entered() -> void:
	if inventory_ref != null and slot_index >= 0:
		GameEvents.ui_slot_hovered.emit(inventory_ref, slot_index)

func _on_mouse_exited() -> void:
	GameEvents.ui_slot_unhovered.emit()
