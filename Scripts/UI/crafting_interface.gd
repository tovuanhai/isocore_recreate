extends Control 

@export var all_recipes: Array[RecipeData] = []
@onready var recipe_list = %RecipeList

var player_crafting_comp: Node

func _ready() -> void:
	hide()

func setup(p_crafting_comp: Node) -> void:
	player_crafting_comp = p_crafting_comp
	if player_crafting_comp and player_crafting_comp.inventory_comp:
		player_crafting_comp.inventory_comp.inventory.changed.connect(_on_inventory_changed)

func open_menu(station_type: int = 0) -> void:
	if player_crafting_comp:
		player_crafting_comp.active_station = station_type
	show()
	refresh_menu()

func close_menu() -> void:
	hide()

func toggle_menu(station_type: int = 0) -> void:
	if visible: close_menu()
	else: open_menu(station_type)

func _on_inventory_changed(_slot_index: int) -> void:
	if visible: refresh_menu()

func refresh_menu() -> void:
	if not player_crafting_comp: return
	for child in recipe_list.get_children():
		child.queue_free()
		
	var active_station = player_crafting_comp.active_station
	var inventory_comp = player_crafting_comp.inventory_comp
	
	for recipe in all_recipes:
		if recipe.required_station == 0 or recipe.required_station == active_station:
			_create_recipe_slot(recipe, inventory_comp)

# ====================================================================
# 🎨 HÀM VẼ UI MỚI: ĐẸP, SẠCH, CHUẨN PIXEL SURVIVAL
# ====================================================================
func _create_recipe_slot(recipe: RecipeData, inventory_comp: Node) -> void:
	# 1. KHUNG CHỨA (MARGIN & BACKGROUND TỐI MÀU BO GÓC)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)

	var bg_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#2a2626") # Màu nâu đen vintage
	style.border_width_bottom = 3
	style.border_color = Color("#181515") # Viền dưới đậm tạo độ nổi 3D
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	bg_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(bg_panel)

	# Lót đệm bên trong
	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 8)
	inner_margin.add_theme_constant_override("margin_right", 8)
	inner_margin.add_theme_constant_override("margin_top", 8)
	inner_margin.add_theme_constant_override("margin_bottom", 8)
	bg_panel.add_child(inner_margin)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inner_margin.add_child(row)

	# 2. KHU VỰC 1: ICON THÀNH PHẨM TO ĐÙNG BÊN TRÁI
	var icon_bg = PanelContainer.new()
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color("#1a1717") # Ô vuông chứa icon đen hơn nền 1 chút
	icon_style.corner_radius_top_left = 4
	icon_style.corner_radius_bottom_right = 4
	icon_bg.add_theme_stylebox_override("panel", icon_style)

	var icon = TextureRect.new()
	icon.texture = recipe.output_item.icon
	icon.custom_minimum_size = Vector2(48, 48) # Kích thước icon bự
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_bg.add_child(icon)
	row.add_child(icon_bg)

	# 3. KHU VỰC 2: TÊN VÀ NGUYÊN LIỆU Ở GIỮA
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# --- Tên món đồ ---
	var name_label = Label.new()
	# Ưu tiên lấy display_name viết hoa chữ cái đầu, thay vì lấy ID viết thường
	var display_name = recipe.output_item.display_name if recipe.output_item.display_name != "" else recipe.output_item.id
	name_label.text = display_name + " (x" + str(recipe.output_amount) + ")"
	name_label.add_theme_color_override("font_color", Color("#e8d6b4")) # Chữ vàng kem sang trọng
	name_label.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_label)

	# --- Hàng ngang chứa các nguyên liệu ---
	var ing_hbox = HBoxContainer.new()
	ing_hbox.add_theme_constant_override("separation", 16)

	for item_id in recipe.ingredients.keys():
		var req = recipe.ingredients[item_id]
		var cur = inventory_comp.inventory.get_total_item_count_by_id(item_id) if inventory_comp else 0

		var ing_item = HBoxContainer.new()
		ing_item.add_theme_constant_override("separation", 4)

		# 🎯 Ma thuật ở đây: Mượn ItemRegistry để moi cái Icon của nguyên liệu ra!
		var ing_data = ItemRegistry.get_item(item_id)
		if ing_data and ing_data.icon:
			var ing_icon = TextureRect.new()
			ing_icon.texture = ing_data.icon
			ing_icon.custom_minimum_size = Vector2(16, 16) # Icon nhỏ cho nguyên liệu
			ing_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ing_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ing_item.add_child(ing_icon)

		var ing_label = Label.new()
		ing_label.text = str(cur) + "/" + str(req)
		
		# Tô màu Xanh/Đỏ
		if cur >= req:
			ing_label.add_theme_color_override("font_color", Color("#a1e069")) # Xanh lá mạ
		else:
			ing_label.add_theme_color_override("font_color", Color("#e06969")) # Đỏ nhạt
			
		ing_label.add_theme_font_size_override("font_size", 14)
		ing_item.add_child(ing_label)
		ing_hbox.add_child(ing_item)

	info_vbox.add_child(ing_hbox)
	row.add_child(info_vbox)

	# 4. KHU VỰC 3: NÚT CRAFT BÊN PHẢI
	var btn_container = VBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var craft_btn = Button.new()
	craft_btn.text = " Craft "
	craft_btn.custom_minimum_size = Vector2(65, 35)
	
	var can_craft = player_crafting_comp.can_craft(recipe)
	craft_btn.disabled = not can_craft
	
	# Trỏ chuột biến thành bàn tay khi hover vào nút
	craft_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	craft_btn.pressed.connect(func():
		player_crafting_comp.craft(recipe)
	)
	
	btn_container.add_child(craft_btn)
	row.add_child(btn_container)

	recipe_list.add_child(margin)
