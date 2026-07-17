extends StaticBody2D

func _ready() -> void:
	y_sort_enabled = true
	
	# 🎯 ĐỒNG BỘ TỰ ĐỘNG: Tìm Mắt thần bấm E và tự động nối dây tín hiệu
	var interact_comp = get_node_or_null("InteractComponent")
	if interact_comp:
		interact_comp.interacted.connect(_on_chest_interacted)
	
	# =========================================================
	# 🎯 BẬT CHẾ ĐỘ NGỦ ĐÔNG KHI KHUẤT TẦM NHÌN
	# =========================================================
	var notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier:
		# Phóng to vùng nhận diện ra to đùng: (-100, -150) là kéo lên trên sang trái, 
		# (200, 200) là kích thước rộng dài. Nó sẽ đánh thức cái cây TRƯỚC KHI camera kịp lia tới!
		notifier.rect = Rect2(-100, -150, 200, 200)
		
		notifier.screen_entered.connect(_on_screen_entered)
		notifier.screen_exited.connect(_on_screen_exited)

# TileMap gọi hàm này khi sinh ra để nâng đồi núi
func init(z: int, cliff_h: int) -> void:
	var elev_shift = z * cliff_h
	
	# Quét tìm ảnh và tự động nâng Offset
	for child in get_children():
		if child is Sprite2D:
			child.offset.y -= elev_shift
			child.show()
			
			if child.is_in_group("isometric_shadows") and child.material is ShaderMaterial:
				child.material = child.material.duplicate()
				var tex_h = child.region_rect.size.y if child.region_enabled else child.texture.get_size().y
				var bottom_y = child.offset.y + (tex_h / 2.0) if child.centered else child.offset.y + tex_h
				
				# 🎯 CHỈNH SỐ NÀY ĐỂ KÉO CHÂN BÓNG KHỚP VỚI VẬT THỂ
				# Số càng lớn, điểm neo càng trượt lên cao, bóng sẽ càng dính sâu vào trong gầm bàn/rương
				var pivot_offset = 6.0 
				
				child.material.set_shader_parameter("base_y", bottom_y - pivot_offset)
				child.material.set_shader_parameter("obj_height", tex_h)
		elif child is VisibleOnScreenNotifier2D:
			child.position.y -= elev_shift
			
# Bật hiển thị -> Y-Sort hoạt động lại
func _on_screen_entered() -> void:
	var main_sprite = get_node_or_null("Sprite2D2")
	var shadow_sprite = get_node_or_null("Sprite2D")
	if main_sprite: main_sprite.show()
	if shadow_sprite: shadow_sprite.show()

# Tắt hiển thị -> Rút phích cắm Y-Sort, siêu nhẹ máy
func _on_screen_exited() -> void:
	var main_sprite = get_node_or_null("Sprite2D2")
	var shadow_sprite = get_node_or_null("Sprite2D")
	if main_sprite: main_sprite.hide()
	if shadow_sprite: shadow_sprite.hide()

# ==============================================================================
# 🎯 TRẠM TIẾP NHẬN TÍN HIỆU TỪ COMPONENT
# ==============================================================================
func _on_chest_interacted() -> void:
	var chest_inv_comp = get_node_or_null("ObjectInventoryComponent")
	# Tìm con Mèo để lấy túi đồ của nó ra đối chiếu
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and chest_inv_comp:
		var player_inv_comp = players[0].get_node_or_null("PlayerInventoryComponent")
		if player_inv_comp:
			# 🎯 Bắn loa gọi UI: "Ê, mở hòm ra và mang theo data của 2 cái túi này nhé!"
			GameEvents.chest_opened.emit(chest_inv_comp.inventory, player_inv_comp.inventory)
