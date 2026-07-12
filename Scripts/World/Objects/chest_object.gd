extends StaticBody2D

@export var chest_item_id: String = "wooden_chest" 

func _ready() -> void:
	y_sort_enabled = true
	
	# Mắt thần (Interact) chỉ dùng để mở UI
	var interact_comp = get_node_or_null("InteractComponent")
	if interact_comp:
		interact_comp.interacted.connect(_on_chest_interacted)

func init(z: int, cliff_h: int) -> void:
	var elev_shift = z * cliff_h
	var main_sprite = get_node_or_null("Sprite2D2")
	if main_sprite:
		main_sprite.offset.y -= elev_shift
		main_sprite.show()
	var shadow_sprite = get_node_or_null("Sprite2D")
	if shadow_sprite: 
		shadow_sprite.offset.y -= elev_shift

# ==============================================================================
# 🎯 CHỈ LÀM NHIỆM VỤ MỞ UI, VIỆC RỚT ĐỒ & MÁU ĐÃ CÓ COMPONENT LO!
# ==============================================================================
func _on_chest_interacted() -> void:
	var my_inv_comp = get_node_or_null("ObjectInventoryComponent")
	if not my_inv_comp: return
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player_inv_comp = players[0].get_node_or_null("PlayerInventoryComponent")
		if player_inv_comp:
			# Đảm bảo ObjectInventoryComponent đã khởi tạo Inventory
			if my_inv_comp.inventory == null:
				my_inv_comp._ready() 
			GameEvents.chest_opened.emit(my_inv_comp.inventory, player_inv_comp.inventory)
