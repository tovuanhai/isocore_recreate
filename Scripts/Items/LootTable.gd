# LootTable.gd
# Resource định nghĩa những gì một block/entity drop khi bị phá hủy.
# Tạo .tres file, gắn vào block/enemy trong Inspector.
class_name LootTable
extends Resource

# Một entry trong bảng loot
class LootEntry:
	var item_id: StringName
	var min_amount: int
	var max_amount: int
	var weight: float   # Trọng số xác suất (lớn hơn = xuất hiện nhiều hơn)

	func _init(id: StringName, mn: int, mx: int, w: float = 1.0) -> void:
		item_id = id
		min_amount = mn
		max_amount = mx
		weight = w

# Danh sách drop entries — định nghĩa thủ công trong code hoặc subclass
# Vì GDScript resource không support nested custom class export tốt,
# ta dùng 4 parallel arrays cho dễ edit trong Inspector:
@export var item_ids: Array[StringName] = []
@export var min_amounts: Array[int] = []
@export var max_amounts: Array[int] = []
@export var weights: Array[float] = []

# Roll loot — trả về Array của {id, amount}
# guaranteed_rolls: số drop chắc chắn (dùng hết weight pool)
# bonus_rolls: số drop thêm ngẫu nhiên
func roll(guaranteed_rolls: int = 1, bonus_rolls: int = 0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if item_ids.is_empty():
		return results

	var total_rolls = guaranteed_rolls + bonus_rolls
	for _r in total_rolls:
		var picked = _weighted_random_pick()
		if picked >= 0:
			var amount = randi_range(min_amounts[picked], max_amounts[picked])
			results.append({ "id": item_ids[picked], "amount": amount })

	return results

func _weighted_random_pick() -> int:
	var total_weight = 0.0
	for w in weights:
		total_weight += w

	var roll = randf() * total_weight
	var cumulative = 0.0
	for i in item_ids.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return i
	return item_ids.size() - 1  # fallback

# Helper: thêm entry bằng code (dùng khi tạo loot table dynamic)
func add_entry(item_id: StringName, min_amt: int, max_amt: int, weight: float = 1.0) -> void:
	item_ids.append(item_id)
	min_amounts.append(min_amt)
	max_amounts.append(max_amt)
	weights.append(weight)
