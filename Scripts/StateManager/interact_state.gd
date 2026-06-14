extends State

var player: Player

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	player.velocity = Vector2.ZERO
	var tile_map = player.tile_map_node
	var base_layer = tile_map.base_ground

	# Đồng bộ góc nhìn
	var block_flat_pos = base_layer.to_global(base_layer.map_to_local(player.interact_tile))
	var dir_vector = player.global_position.direction_to(block_flat_pos)
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir_vector.angle()))

	# Hoạt ảnh
	var anim_name = "hit_" + player.last_dir
	if player.interact_type == "build_ground":
		anim_name = "build_" + player.last_dir
	elif player.interact_type == "mine_ground":
		anim_name = "dig_" + player.last_dir

	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
	elif player.anim_player.has_animation("hit_" + player.last_dir):
		player.anim_player.play("hit_" + player.last_dir)
	else:
		player.anim_player.play("walk_" + player.last_dir)

	await get_tree().create_timer(0.35).timeout

	if current_state_active():
		execute_interaction()

func execute_interaction() -> void:
	var damage = 1
	var inv_comp = player.get_node_or_null("PlayerInventoryComponent")

	# 🎯 NÂNG CẤP DỮ LIỆU ĐỘNG: Bốc đồ thật từ tay Mèo ra để tính toán
	if inv_comp:
		var slot = inv_comp.get_equipped_slot()
		
		# Kiểm tra xem tay có đang cầm đồ không, và đồ đó có phải là Công Cụ (ToolData) không
		if slot and not slot.is_empty() and slot.item is ToolData:
			var tool = slot.item as ToolData

			# 1. ĐỐI CHIẾU CÔNG CỤ & ĐỊA HÌNH
			# Đào đất -> Cần Xẻng
			if player.interact_type == "mine_ground" and tool.tool_category == ToolData.ToolCategory.SHOVEL:
				damage = tool.base_damage
			# Đập đá -> Cần Cuốc
			elif player.interact_type == "mine_object" and tool.tool_category == ToolData.ToolCategory.PICKAXE:
				damage = tool.base_damage
			else:
				# Dùng sai dụng cụ (VD: Lấy xẻng đi đập đá) -> Phạt sát thương về 1
				damage = 1

			# 2. TRỪ ĐỘ BỀN VÀ XỬ LÝ GÃY ĐỒ
			# Công cụ nào có độ bền (durability > 0) thì mới trừ
			if slot.durability > 0:
				slot.durability -= 1
				
				# Nếu trừ xong mà bằng 0 tức là cuốc đã gãy
				if slot.durability <= 0:
					slot.clear() # Xóa sạch item khỏi ô Hotbar này
				
				# 3. KÍCH HOẠT UI TỰ ĐỘNG CẬP NHẬT
				# Bắn loa báo cho UI biết cái ô này vừa bị đổi máu/gãy để nó vẽ lại
				inv_comp.inventory.changed.emit(inv_comp.equipped_slot_index)


	# Emit đúng format: (player: Node2D, cell: Vector2i, action_type: String, damage: int)
	GameEvents.tile_hit.emit(player, player.interact_tile, player.interact_type, damage)

	await get_tree().create_timer(0.15).timeout
	if current_state_active():
		player.interact_type = ""
		transition_requested.emit("Idle")

func current_state_active() -> bool:
	var fsm = player.get_node_or_null("StateMachine")
	return fsm and fsm.get("current_state") == self
