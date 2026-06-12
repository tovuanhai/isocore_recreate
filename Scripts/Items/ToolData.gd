# ToolData.gd
# Dữ liệu dành riêng cho công cụ. Extend ItemData.
# Tạo file .tres với class này để định nghĩa: wooden_pickaxe, stone_axe, v.v.
class_name ToolData
extends ItemData

enum ToolCategory {
	PICKAXE,  # Đập đá
	SHOVEL,   # Đào đất
	AXE,      # Chặt gỗ
	HOE,      # Cày ruộng
	FISHING,  # Cần câu
}

@export var tool_category: ToolCategory = ToolCategory.PICKAXE

# Sát thương cơ bản của tool (tile/entity nhận giá trị này)
@export var base_damage: int = 1

# Tốc độ swing: 1.0 = bình thường, 0.5 = chậm 2x, 2.0 = nhanh 2x
@export var swing_speed: float = 1.0

# Tier: 0=Wood, 1=Stone, 2=Iron, 3=Gold, 4=Diamond...
@export var tier: int = 0

# Độ bền
@export var max_durability: int = 60
