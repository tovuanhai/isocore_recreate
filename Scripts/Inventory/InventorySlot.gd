# InventorySlot.gd
# Đại diện cho 1 ô trong inventory.
# Không phải Resource — chỉ là class thuần để thao tác logic.
class_name InventorySlot

var item: ItemData = null
var quantity: int = 0
var durability: int = -1  # -1 = không dùng (non-tool). Dùng cho Tool/Weapon/Armor.

func is_empty() -> bool:
	return item == null or quantity <= 0

func clear() -> void:
	item = null
	quantity = 0
	durability = -1

# Trả về số lượng item dư sau khi thêm (0 = thêm hết)
func add(incoming: ItemData, amount: int) -> int:
	if is_empty():
		item = incoming
		quantity = 0
		if incoming is ToolData:
			durability = (incoming as ToolData).max_durability

	if item.id != incoming.id:
		return amount  # Slot đang chứa item khác

	var space = item.max_stack - quantity
	var added = min(space, amount)
	quantity += added
	return amount - added

func remove(amount: int) -> int:
	var removed = min(quantity, amount)
	quantity -= removed
	if quantity <= 0:
		clear()
	return removed

func duplicate_slot() -> InventorySlot:
	var s = InventorySlot.new()
	s.item = item
	s.quantity = quantity
	s.durability = durability
	return s
