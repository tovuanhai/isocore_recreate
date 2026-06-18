extends StaticBody2D

func _ready() -> void:
	y_sort_enabled = true
	
	# 🎯 ĐỒNG BỘ TỰ ĐỘNG: Tìm Mắt thần bấm E và tự động nối dây tín hiệu
	var interact_comp = get_node_or_null("InteractComponent")
	if interact_comp:
		interact_comp.interacted.connect(_on_chest_interacted)

# TileMap gọi hàm này khi sinh ra để nâng đồi núi
func init(z: int, cliff_h: int) -> void:
	var elev_shift = z * cliff_h
	
	# Quét tìm ảnh và tự động nâng Offset
	for child in get_children():
		if child is Sprite2D:
			child.offset.y -= elev_shift
			child.show()

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
