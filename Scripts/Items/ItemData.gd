# ItemData.gd
# Resource gốc cho mọi loại item trong game.
# Tạo file .tres từ resource này trong Godot Editor để định nghĩa từng item.
# Extend class này cho ToolData, ArmorData, ConsumableData, v.v.
class_name ItemData
extends Resource

enum ItemType {
	RESOURCE,     # Nguyên liệu thô: đá, gỗ, đất
	CONSUMABLE,   # Đồ ăn, thuốc
	TOOL,         # Cuốc, xẻng, rìu — extend sang ToolData
	WEAPON,       # Vũ khí — extend sang WeaponData
	ARMOR,        # Giáp — extend sang ArmorData
	PLACEABLE,    # Block có thể đặt xuống đất
	MISC,         # Vật phẩm khác
}

# --- Định danh & Hiển thị ---
@export var id: StringName = ""            # Unique ID: "stone", "wooden_pickaxe"
@export var display_name: String = ""      # Tên hiển thị: "Stone", "Wooden Pickaxe"
@export var description: String = ""
@export var icon: Texture2D = null

# --- Phân loại ---
@export var type: ItemType = ItemType.RESOURCE

# --- Stack ---
@export var max_stack: int = 64           # Tool/Armor thường để 1
@export var is_stackable: bool = true

# --- Loại này dùng cho các Block/Hòm có thể đặt xuống đất ---
# Trỏ thẳng tới cái Scene vật lý sẽ sinh ra ngoài Map (Ví dụ: Chest.tscn, Torch.tscn)
@export var object_scene: PackedScene = null

# Kích thước mặc định luôn là 1x1 để các món đồ cũ không bị lỗi
@export var build_size: Vector2i = Vector2i(1, 1)
@export var ghost_offset: Vector2 = Vector2.ZERO

# Dùng để so sánh nhanh
func equals(other: ItemData) -> bool:
	return id == other.id
