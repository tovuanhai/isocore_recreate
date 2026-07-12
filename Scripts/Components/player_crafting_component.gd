extends Node

@onready var inventory_comp = get_parent().get_node_or_null("PlayerInventoryComponent")

# 🎯 Biến lưu trữ Bàn chế tạo mà Player đang tương tác
# Mặc định bằng 0 (tức là Station.HAND)
var active_station: int = 0 

# 🎯 BIẾN DÙNG ĐỂ TEST
@export var test_recipe_hand: RecipeData
@export var test_recipe_bench: RecipeData

signal craft_success(recipe: RecipeData)
signal craft_failed(reason: String)

func can_craft(recipe: RecipeData) -> bool:
	if inventory_comp == null or inventory_comp.inventory == null:
		return false
		
	# =========================================================
	# 1. KIỂM TRA BÀN CHẾ TẠO TRƯỚC
	# Nếu công thức không phải chế tay, VÀ player đang không dùng đúng bàn -> TỪ CHỐI!
	# =========================================================
	if recipe.required_station != RecipeData.Station.HAND and recipe.required_station != active_station:
		return false 
		
	# 2. KIỂM TRA NGUYÊN LIỆU (Giữ nguyên như cũ)
	var inv = inventory_comp.inventory
	for item_id in recipe.ingredients.keys():
		var required_amount = recipe.ingredients[item_id]
		var current_amount = inv.get_total_item_count_by_id(item_id)
		if current_amount < required_amount:
			return false 
			
	return true

func craft(recipe: RecipeData) -> void:
	if not can_craft(recipe):
		craft_failed.emit("Không đủ điều kiện (Thiếu đồ hoặc sai Bàn)!")
		print("❌ LỖI: Thằng Mèo chưa đủ đồ hoặc đang không đứng ở đúng Bàn Chế Tạo!")
		return
		
	var inv = inventory_comp.inventory
	
	for item_id in recipe.ingredients.keys():
		var required_amount = recipe.ingredients[item_id]
		inv.consume_item_by_id(item_id, required_amount)
		
	var leftovers = inventory_comp.inventory.add_item(recipe.output_item, recipe.output_amount)
	
	if leftovers > 0:
		var drop_pos = get_parent().global_position
		LootSpawner.spawn_item(recipe.output_item.id, leftovers, drop_pos)
		
	craft_success.emit(recipe)
	print("✅ THÀNH CÔNG: Đã chế tạo ", recipe.output_amount, " ", recipe.output_item.id)

## ==========================================
## 🎯 HÀM TEST BÀN CHẾ TẠO (Sẽ xóa sau khi có UI)
## ==========================================
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventKey and event.pressed:
		#
		## Phím C: Test chế đồ bằng TAY KHÔNG
		#if event.keycode == KEY_C:
			#print("\n--- BẤM C: Chế Đuốc bằng TAY KHÔNG ---")
			#active_station = 0 # Báo hiệu đang đứng xa bàn
			#if test_recipe_hand:
				#craft(test_recipe_hand)
				#
		## Phím V: Test chế đồ Bàn Gỗ nhưng ĐỨNG Ở XA
		#elif event.keycode == KEY_V:
			#print("\n--- BẤM V: Chế Cuốc bằng BÀN GỖ (Nhưng đang đứng xa bàn) ---")
			#active_station = 0 # Đứng bơ vơ giữa đồng
			#if test_recipe_bench:
				#craft(test_recipe_bench)
				#
		## Phím B: Test chế đồ Bàn Gỗ và ĐÃ LẠI GẦN BÀN
		#elif event.keycode == KEY_B:
			#print("\n--- BẤM B: Chế Cuốc bằng BÀN GỖ (Đã đi lại gần chạm vào bàn) ---")
			#active_station = 1 # Giả lập tương tác với Bàn Gỗ (BASIC_BENCH)
			#if test_recipe_bench:
				#craft(test_recipe_bench)
