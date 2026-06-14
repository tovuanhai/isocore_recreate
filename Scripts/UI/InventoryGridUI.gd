class_name InventoryGridUI
extends MarginContainer

const SLOT_UI_SCENE = preload("res://Scenes/UI/InventorySlotUI.tscn")

# 🎯 ĐÃ SỬA: Khai báo lại biến ở dạng thường để code chạy mượt mà không bị lỗi "not declared"
var grid_container: GridContainer = null

# Thông số cấu hình phân mảnh cho Grid này
@export var start_index: int = 0
@export var slot_count: int = 10

var _slot_ui_nodes: Array[InventorySlotUI] = []


# ---------------------------------------------------------------------------
# Khởi tạo ma trận ô giao diện trống
# ---------------------------------------------------------------------------
func initialize_grid() -> void:
	# 1. Cơ chế tự cứu hộ nếu Editor bị thiếu hoặc null node GridContainer
	if grid_container == null:
		grid_container = get_node_or_null("GridContainer")
		
	if grid_container == null:
		# Nếu tìm khắp nơi vẫn không thấy, tự đẻ ra 1 cái GridContainer mới bằng lệnh
		grid_container = GridContainer.new()
		grid_container.name = "GridContainer"
		add_child(grid_container)
		
	## 🎯 ĐÃ SỬA: Ép cái Grid mọc đều ra 4 hướng từ tâm, không được mọc lệch xuống dưới phải nữa!
	#grid_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	#grid_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	#grid_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	# 2. Tự động chỉnh số cột (Columns) theo ý đồ phân mảnh
	if slot_count == 10:
		grid_container.columns = 10
	else:
		grid_container.columns = 10 # 7 cột nhìn rất cân đối cho hòm đồ chính 21 ô

	# 3. Dọn sạch các node cũ nếu có
	for child in grid_container.get_children():
		child.queue_free()
	_slot_ui_nodes.clear()

	# 4. Đẻ các ô UI con ra dựa trên số lượng quy định
	for i in slot_count:
		var slot_ui = SLOT_UI_SCENE.instantiate() as InventorySlotUI
		grid_container.add_child(slot_ui)
		
		# Gán vị trí ID thực tế cho ô UI biết đường tự quản lý
		slot_ui.slot_index = start_index + i
		_slot_ui_nodes.append(slot_ui)


# ---------------------------------------------------------------------------
# Vẽ lại toàn bộ lưới khi lần đầu nạp túi đồ vào người
# ---------------------------------------------------------------------------
func refresh_all(inventory: Inventory) -> void:
	for slot_ui in _slot_ui_nodes:
		var actual_slot = inventory.get_slot(slot_ui.slot_index)
		if slot_ui and is_instance_valid(slot_ui):
			# 🎯 ĐÃ THÊM: Truyền luôn cả cái túi đồ (inventory) vào cho UI con
			slot_ui.update_slot(actual_slot, inventory)


# ---------------------------------------------------------------------------
# CẬP NHẬT CỤC BỘ: Chỉ vẽ lại đúng ô bị thay đổi (Tối ưu hiệu năng cao)
# ---------------------------------------------------------------------------
func update_single_slot(inventory: Inventory, global_slot_idx: int) -> void:
	if global_slot_idx >= start_index and global_slot_idx < (start_index + slot_count):
		var local_idx = global_slot_idx - start_index
		var actual_slot = inventory.get_slot(global_slot_idx)
		if _slot_ui_nodes[local_idx] and is_instance_valid(_slot_ui_nodes[local_idx]):
			# 🎯 ĐÃ THÊM: Truyền luôn cả cái túi đồ (inventory) vào cho UI con
			_slot_ui_nodes[local_idx].update_slot(actual_slot, inventory)


# ---------------------------------------------------------------------------
# Hỗ trợ lấy ô UI đơn lẻ để bật tắt khung sáng (Dùng riêng cho Hotbar)
# ---------------------------------------------------------------------------
func get_slot_ui_by_global_index(global_slot_idx: int) -> InventorySlotUI:
	if global_slot_idx >= start_index and global_slot_idx < (start_index + slot_count):
		return _slot_ui_nodes[global_slot_idx - start_index]
	return null
