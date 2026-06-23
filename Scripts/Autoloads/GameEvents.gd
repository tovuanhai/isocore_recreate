# GameEvents.gd
# Autoload (Singleton). Đăng ký với tên "GameEvents".
# Bus signal toàn cục. Chỉ khai báo signal ở đây — KHÔNG có logic.
# Rule: signal tên theo dạng verb_noun hoặc noun_verbed.
extends Node

# ---------------------------------------------------------------------------
# PLAYER — Di chuyển & Trạng thái
# ---------------------------------------------------------------------------
signal player_moved(player: Node2D, cell: Vector2i, elevation: int)
signal player_entered_water(player: Node2D)
signal player_exited_water(player: Node2D)
signal player_died(player: Node2D)
signal player_took_damage(player: Node2D, amount: int)

# ---------------------------------------------------------------------------
# TOOL / INTERACTION
# ---------------------------------------------------------------------------
# Bắn khi player bắt đầu/kết thúc 1 hành động (vung cuốc, câu cá, v.v.)
signal player_action_started(player: Node2D, action: String)
signal player_action_finished(player: Node2D, action: String)

# Signal cho VFX — visual feedback
signal tile_hit_vfx(global_pos: Vector2, action_type: String, hit_node: Node2D)

# Signal cho TileMap — game logic
signal tile_hit(player: Node2D, cell: Vector2i, action_type: String, damage: int)

# Bắn khi tile/block bị phá hủy hoàn toàn
signal block_destroyed(cell: Vector2i, world_pos: Vector2, loot_table: LootTable)

# ---------------------------------------------------------------------------
# INVENTORY
# ---------------------------------------------------------------------------
# Bắn khi nhặt item
signal item_picked_up(item_id: StringName, amount: int)

# Bắn khi inventory thay đổi (UI lắng nghe cái này để refresh)
signal inventory_changed(inventory: Inventory, slot_index: int)

# ---------------------------------------------------------------------------
# STATUS EFFECTS
# ---------------------------------------------------------------------------
signal status_applied(entity: Node2D, effect_id: StringName)
signal status_removed(entity: Node2D, effect_id: StringName)

# Bắn khi có ai đó click chuột trái vào một ô UI túi đồ bất kỳ
signal ui_slot_clicked(inventory: Inventory, slot_index: int)

# Bắn khi chuột rà vào một ô
signal ui_slot_hovered(inventory: Inventory, slot_index: int)
# Bắn khi chuột lách ra khỏi ô
signal ui_slot_unhovered()
# Bắn tín hiệu khi người chơi muốn vứt đồ ra đất
signal drop_item_requested(item_data: ItemData, quantity: int, durability: int)

signal chest_opened(chest_inventory: Inventory, player_inventory: Inventory)
signal chest_closed()

signal crafting_station_opened(station_type: int)
