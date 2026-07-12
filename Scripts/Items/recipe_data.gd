class_name RecipeData
extends Resource

# 🎯 ĐỊNH NGHĨA CÁC CẤP ĐỘ BÀN CHẾ TẠO
enum Station {
	HAND,           # 0: Chế bằng tay (Mặc định: Đuốc, Rương, Cuốc gỗ)
	BASIC_BENCH,    # 1: Bàn chế tạo gỗ (Kiếm, Giáp da, Đồ đá)
	COPPER_ANVIL,   # 2: Đe đồng (Đồ đồng, Máy móc cơ bản)
	IRON_ANVIL      # 3: Đe sắt (Vũ khí xịn, Máy bơm nước)
}

@export var recipe_id: String = ""

# Công thức này yêu cầu đứng ở bàn nào? Mặc định là chế tay.
@export var required_station: Station = Station.HAND

@export var ingredients: Dictionary = {}
@export var output_item: ItemData
@export var output_amount: int = 1
