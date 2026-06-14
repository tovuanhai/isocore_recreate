# Inventory.gd
# Logic core của túi đồ. Class thuần, không extends Node hay Resource.
# Có thể gắn vào Player, Chest, NPC, v.v.
# UI lắng nghe signal "changed" để tự refresh.
class_name Inventory
extends RefCounted

signal changed(slot_index: int)  # Bắn ra mỗi khi 1 slot thay đổi

var slots: Array[InventorySlot] = []
var size: int = 0

func _init(slot_count: int) -> void:
	size = slot_count
	slots.resize(size)
	for i in size:
		slots[i] = InventorySlot.new()

# ---------------------------------------------------------------------------
# Thêm item — trả về số lượng còn dư (0 = thêm hết)
# ---------------------------------------------------------------------------
# 🎯 ĐÃ SỬA: Thêm tham số custom_durability để ghi nhớ độ bền khi nhặt đồ từ đất
func add_item(item: ItemData, amount: int = 1, custom_durability: int = -1) -> int:
	var remainder = amount

	# Pass 1: Ưu tiên lấp đầy slot đang có item cùng loại (chỉ stackable)
	if item.is_stackable:
		for i in size:
			if not slots[i].is_empty() and slots[i].item.id == item.id:
				remainder = slots[i].add(item, remainder)
				changed.emit(i)
				if remainder == 0:
					return 0

	# Pass 2: Mở slot trống mới
	for i in size:
		if slots[i].is_empty():
			remainder = slots[i].add(item, remainder)
			
			# 🎯 ĐÃ THÊM: Nếu có độ bền tùy chỉnh (như đồ cũ rớt ra đất), ép đè vào slot mới mở
			if custom_durability >= 0:
				slots[i].durability = custom_durability
				
			changed.emit(i)
			if remainder == 0:
				return 0

	return remainder  # Túi đầy, còn dư bao nhiêu

# ---------------------------------------------------------------------------
# Xóa item theo ID — trả về số lượng thực sự đã xóa
# ---------------------------------------------------------------------------
func remove_item(item_id: StringName, amount: int = 1) -> int:
	var total_removed = 0
	var remaining = amount

	for i in size:
		if remaining <= 0:
			break
		if not slots[i].is_empty() and slots[i].item.id == item_id:
			var removed = slots[i].remove(remaining)
			total_removed += removed
			remaining -= removed
			changed.emit(i)

	return total_removed

# ---------------------------------------------------------------------------
# Đếm tổng số lượng item theo ID
# ---------------------------------------------------------------------------
func count_item(item_id: StringName) -> int:
	var total = 0
	for slot in slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.quantity
	return total

func has_item(item_id: StringName, amount: int = 1) -> bool:
	return count_item(item_id) >= amount

# ---------------------------------------------------------------------------
# Lấy slot tại index
# ---------------------------------------------------------------------------
func get_slot(index: int) -> InventorySlot:
	if index < 0 or index >= size:
		return null
	return slots[index]

# ---------------------------------------------------------------------------
# Hoán đổi 2 slot (dùng cho drag-drop UI)
# ---------------------------------------------------------------------------
func swap_slots(index_a: int, index_b: int) -> void:
	if index_a == index_b:
		return
	var tmp = slots[index_a].duplicate_slot()
	slots[index_a].item = slots[index_b].item
	slots[index_a].quantity = slots[index_b].quantity
	slots[index_a].durability = slots[index_b].durability
	slots[index_b].item = tmp.item
	slots[index_b].quantity = tmp.quantity
	slots[index_b].durability = tmp.durability
	changed.emit(index_a)
	changed.emit(index_b)

# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------
func print_contents() -> void:
	print("=== Inventory (%d slots) ===" % size)
	for i in size:
		var s = slots[i]
		if not s.is_empty():
			var dur_str = " [dur:%d]" % s.durability if s.durability >= 0 else ""
			print("  [%d] %s x%d%s" % [i, s.item.id, s.quantity, dur_str])
