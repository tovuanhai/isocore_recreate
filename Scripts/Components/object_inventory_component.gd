class_name ObjectInventoryComponent
extends Node

@export var slot_count: int = 20
var inventory: Inventory

func _ready() -> void:
	inventory = Inventory.new(slot_count)

# Thêm tham số exact_pos vào đây
func drop_all_items(exact_pos: Vector2) -> void:
	if inventory == null: return
	
	var health_comp = get_parent().get_node_or_null("HealthDropComponent")
	if not health_comp: return
	
	for i in range(slot_count):
		var slot = inventory.get_slot(i)
		if slot != null and not slot.is_empty():
			# 🎯 Truyền đủ 4 tham số: item, quantity, durability, exact_pos
			health_comp._spawn_dropped_item(slot.item, slot.quantity, slot.durability, exact_pos)
