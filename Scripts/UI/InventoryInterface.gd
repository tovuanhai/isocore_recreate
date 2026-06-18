extends CanvasLayer

@onready var hotbar_grid: InventoryGridUI = $HotbarGridUI
@onready var main_inventory_panel: Control = $MainInventoryPanel
@onready var main_inventory_grid: InventoryGridUI = $MainInventoryPanel/MainInventoryGridUI

# 🎯 ĐÃ SỬA: Móc nối trực tiếp với cái Scene Tooltip ông vừa kéo vào
@onready var item_tooltip: PanelContainer = $ItemTooltip

@onready var chest_interface = $ChestInterface
@onready var chest_grid = %ChestGrid
@onready var player_grid_in_chest = %PlayerGridInChest

# 🎯 ĐÃ THÊM: Biến lưu trữ dữ liệu của Hòm đồ và trạng thái mở hòm
var _active_chest_inventory: Inventory = null
var is_chest_open: bool = false

var _cached_inventory: Inventory = null
var _player_component: Node = null

var floating_slot: InventorySlot = InventorySlot.new()
var floating_cursor_node: Control
var floating_icon: TextureRect
var floating_label: Label


func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	hotbar_grid.initialize_grid()
	main_inventory_grid.initialize_grid()

	GameEvents.ui_slot_clicked.connect(_on_ui_slot_clicked)
	GameEvents.ui_slot_hovered.connect(_on_ui_slot_hovered)
	GameEvents.ui_slot_unhovered.connect(_on_ui_slot_unhovered)
	GameEvents.inventory_changed.connect(_on_global_inventory_changed)
	GameEvents.chest_opened.connect(_on_chest_opened)
	
	_setup_floating_cursor()
	_find_player_and_bind()


func _process(_delta: float) -> void:
	if floating_cursor_node and floating_cursor_node.visible:
		floating_cursor_node.global_position = get_viewport().get_mouse_position()


func _input(event: InputEvent) -> void:
	var is_toggle_pressed = event.is_action_pressed("toggle_inventory")
	var is_tab_pressed = event is InputEventKey and event.keycode == KEY_TAB and event.pressed
	
	if is_toggle_pressed or is_tab_pressed:
		
		# 🎯 BƯỚC 1: Nếu Hòm đang mở, phím Tab sẽ Đóng Hòm và thoát luôn!
		if is_chest_open:
			close_chest() # Hàm ông viết hôm trước
			get_viewport().set_input_as_handled()
			return
			
		if main_inventory_panel.visible:
			main_inventory_panel.hide()
			item_tooltip.hide() # Tắt hòm đồ thì giấu Tooltip
		else:
			if _cached_inventory:
				main_inventory_grid.refresh_all(_cached_inventory)
				main_inventory_panel.show()


# ---------------------------------------------------------------------------
# XỬ LÝ TOOLTIP BẰNG SCENE NGOẠI VI
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# XỬ LÝ TOOLTIP BẰNG SCENE NGOẠI VI
# ---------------------------------------------------------------------------
func _on_ui_slot_hovered(inventory: Inventory, slot_idx: int) -> void:
	if not floating_slot.is_empty():
		item_tooltip.hide()
		return

	# 🎯 BƯỚC 2: Cấp phép hiện Tooltip nếu Túi Chính MỞ **HOẶC** Hòm Đồ MỞ
	if not main_inventory_panel.visible and not is_chest_open:
		item_tooltip.hide()
		return

	var slot = inventory.get_slot(slot_idx)
	if slot and not slot.is_empty() and slot.item:
		# Bắn dữ liệu sang cho Scene Tooltip tự lo việc vẽ chữ
		item_tooltip.display_info(slot.item, slot.durability)
		
		# 🎯 BƯỚC 3: Ép Tooltip luôn nổi lên trên cùng (Để không bị khung Hòm đè)
		item_tooltip.z_index = 100 
	else:
		item_tooltip.hide()


func _on_ui_slot_unhovered() -> void:
	if item_tooltip:
		item_tooltip.hide()


# ---------------------------------------------------------------------------
# THUẬT TOÁN KÉO THẢ & SETUP ICON ẢO
# ---------------------------------------------------------------------------
func _on_ui_slot_clicked(inventory: Inventory, slot_idx: int) -> void:
	var clicked_slot = inventory.get_slot(slot_idx)
	if clicked_slot == null: return
	
	# ===========================================================================
	# 🎯 BẮT ĐẦU: LOGIC CỦA QUICK TRANSFER (SHIFT + CLICK CHUỘT TRÁI)
	# ===========================================================================
	if Input.is_key_pressed(KEY_SHIFT):
		# Chỉ cho phép chuyển nhanh nếu hòm đồ thực sự đang mở
		if not is_chest_open or _active_chest_inventory == null or _cached_inventory == null:
			return
		
		if clicked_slot.is_empty(): 
			return
			
		# 1. Xác định Túi đồ Đích (Target) dựa trên Túi đồ Nguồn (Source) vừa click
		var target_inv: Inventory = null
		if inventory == _cached_inventory:
			target_inv = _active_chest_inventory # Bấm vào túi người -> Đích là Hòm
		else:
			target_inv = _cached_inventory       # Bấm vào hòm -> Đích là túi người
			
		# 2. Lấy thông số món đồ chuẩn bị chuyển đi
		var item = clicked_slot.item
		var qty = clicked_slot.quantity
		var dur = clicked_slot.durability
		
		# 3. Thử bắn món đồ sang túi đích bằng hàm add_item thần thánh đã viết sẵn
		# Hàm này sẽ tự động tìm ô trống, tự gom cụm, và tự update UI của túi đích luôn!
		var remainder = target_inv.add_item(item, qty, dur)
		
		# 4. Cập nhật lại số lượng ở túi nguồn dựa trên số lượng còn dư (remainder)
		if remainder <= 0:
			clicked_slot.clear() # Đã chuyển đi thành công 100%
		else:
			clicked_slot.quantity = remainder # Túi đích bị đầy, chỉ chuyển được một phần
			
		# 5. Phát tín hiệu bắt túi nguồn tự vẽ lại ô UI của nó
		inventory.changed.emit(slot_idx)
		
		# Kết thúc xử lý, không chạy xuống phần logic kéo thả ở dưới nữa
		return
	# ===========================================================================
	# 🎯 KẾT THÚC: LOGIC QUICK TRANSFER
	# ===========================================================================

	if not floating_slot.is_empty() and not clicked_slot.is_empty() \
	and floating_slot.item.id == clicked_slot.item.id and clicked_slot.item.is_stackable:
		var max_stack = clicked_slot.item.max_stack
		var space = max_stack - clicked_slot.quantity
		if space > 0:
			var amount_to_add = min(space, floating_slot.quantity)
			clicked_slot.quantity += amount_to_add
			floating_slot.quantity -= amount_to_add
			if floating_slot.quantity <= 0: floating_slot.clear()
			inventory.changed.emit(slot_idx)
			_update_floating_cursor_visual()
			_on_ui_slot_hovered(inventory, slot_idx) 
			return

	var temp_item = floating_slot.item
	var temp_qty = floating_slot.quantity
	var temp_dur = floating_slot.durability

	floating_slot.item = clicked_slot.item
	floating_slot.quantity = clicked_slot.quantity
	floating_slot.durability = clicked_slot.durability

	clicked_slot.item = temp_item
	clicked_slot.quantity = temp_qty
	clicked_slot.durability = temp_dur

	inventory.changed.emit(slot_idx)
	_update_floating_cursor_visual()
	_on_ui_slot_hovered(inventory, slot_idx) 


func _setup_floating_cursor() -> void:
	floating_cursor_node = Control.new()
	floating_cursor_node.name = "FloatingCursor"
	floating_cursor_node.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	floating_cursor_node.z_index = 100 
	add_child(floating_cursor_node)
	
	floating_icon = TextureRect.new()
	floating_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floating_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	floating_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var icon_size = Vector2(48, 48)
	floating_icon.custom_minimum_size = icon_size
	floating_icon.size = icon_size
	floating_icon.position = -icon_size / 2
	floating_cursor_node.add_child(floating_icon)
	
	floating_label = Label.new()
	floating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_label.position = Vector2(12, 12) 
	floating_cursor_node.add_child(floating_label)
	
	_update_floating_cursor_visual()


func _update_floating_cursor_visual() -> void:
	if floating_slot == null or floating_slot.is_empty():
		floating_cursor_node.hide()
		return
	floating_icon.texture = floating_slot.item.icon
	if floating_slot.quantity > 1:
		floating_label.text = str(floating_slot.quantity)
		floating_label.show()
	else:
		floating_label.hide()
	floating_cursor_node.show()


func _on_global_inventory_changed(inventory: Inventory, slot_idx: int) -> void:
	_cached_inventory = inventory
	hotbar_grid.update_single_slot(inventory, slot_idx)
	main_inventory_grid.update_single_slot(inventory, slot_idx)

	# 🎯 ĐÃ THÊM: Vẽ lại khung Highlight ngay sau khi ô đồ bị làm mới
	if _player_component:
		_on_hotbar_selection_changed(_player_component.equipped_slot_index)


func _on_hotbar_selection_changed(new_active_idx: int) -> void:
	# 🎯 ĐÃ SỬA: Quét qua cả 10 ô Hotbar thay vì 9 ô như trước
	for i in range(10): 
		var slot_ui = hotbar_grid.get_slot_ui_by_global_index(i)
		if slot_ui:
			slot_ui.set_highlight(i == new_active_idx)


func _find_player_and_bind() -> void:
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): return
	var player_node = players[0]
	_player_component = player_node.get_node_or_null("PlayerInventoryComponent")
	if _player_component:
		_cached_inventory = _player_component.get_inventory()
		hotbar_grid.refresh_all(_cached_inventory)
		_on_hotbar_selection_changed(_player_component.equipped_slot_index)
		_player_component.hotbar_selection_changed.connect(_on_hotbar_selection_changed)

# Hàm này tự động bắt các cú click chuột trượt ra ngoài giao diện UI
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Nếu click ra ngoài VÀ đang cầm đồ trên chuột
		if not floating_slot.is_empty():
			
			# 1. Bắn loa gọi hệ thống sinh ra đồ vật ở ngoài thế giới
			GameEvents.drop_item_requested.emit(floating_slot.item, floating_slot.quantity, floating_slot.durability)
			
			# 2. Xóa sạch đồ đang dính trên trỏ chuột
			floating_slot.clear()
			_update_floating_cursor_visual()
			
			# 3. Giấu Tooltip đi cho đỡ lỗi
			_on_ui_slot_unhovered()
			# Báo cho Godot biết cú click này đã bị UI tiêu thụ, không cho lọt xuống con Mèo nữa
			get_viewport().set_input_as_handled()
	if is_chest_open and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
			close_chest()
			get_viewport().set_input_as_handled()
			
func _on_chest_opened(chest_inv: Inventory, player_inv: Inventory) -> void:
	# Hiển thị cái CenterContainer lên giữa màn hình
	chest_interface.show()
	is_chest_open = true
	
	#🎯 Nạp Data vào 2 cái lưới UI
	#LƯU Ý: Thay hàm "set_inventory" bằng đúng tên hàm mà ông đang dùng 
	#trong file InventoryGridUI.gd để truyền data nhé!
	if chest_grid.has_method("set_inventory"):
		chest_grid.set_inventory(chest_inv)
		
	if player_grid_in_chest.has_method("set_inventory"):
		player_grid_in_chest.set_inventory(player_inv)
	
	# 🎯 ĐÃ THÊM: Lưu lại cục dữ liệu hòm để dùng cho Shift + Click
	_active_chest_inventory = chest_inv
	is_chest_open = true
	# Khóa nhân vật không cho di chuyển/đập đá lúc đang lúi húi mở hòm
	get_tree().paused = true

func close_chest() -> void:
	chest_interface.hide()
	is_chest_open = false
	
	_active_chest_inventory = null
	is_chest_open = false
	
	get_tree().paused = false # Mở khóa cho game chạy tiếp
