extends State

var player: Player

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	player.velocity = Vector2.ZERO
	var tile_map = player.tile_map_node
	if not tile_map: return
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

	if inv_comp:
		var slot = inv_comp.get_equipped_slot()
		
		# Kiểm tra Tool và tính toán Sát thương
		if slot and not slot.is_empty() and slot.item is ToolData:
			var tool = slot.item as ToolData

			# ĐỐI CHIẾU CÔNG CỤ & ĐỊA HÌNH
			if player.interact_type == "mine_ground" and tool.tool_category == ToolData.ToolCategory.SHOVEL:
				damage = tool.base_damage
			elif player.interact_type == "mine_object" and tool.tool_category == ToolData.ToolCategory.PICKAXE:
				damage = tool.base_damage
			else:
				# 🎯 Cầm sai Tool (Ví dụ cầm Xẻng đi đập Đá) -> Không trừ máu!
				damage = 1 

			# TRỪ ĐỘ BỀN (Chỉ trừ khi đập đúng đồ và sinh ra damage)
			if slot.durability > 0 and damage > 0:
				slot.durability -= 1
				if slot.durability <= 0:
					slot.clear()
				inv_comp.inventory.changed.emit(inv_comp.equipped_slot_index)
		else:
			# 🎯 Tay không -> Không có sát thương đào đất hay đập đá
			damage = 1

	# Chỉ gọi hàm phá hủy nếu thực sự tạo ra Sát thương
	if damage > 0:
		_perform_hit(player.interact_tile, damage)

	await get_tree().create_timer(0.15).timeout
	if current_state_active():
		player.interact_type = ""
		transition_requested.emit("Idle")

# ==============================================================================
# 🎯 TRẠM PHÂN LUỒNG (INTERCEPT LAYER)
# ==============================================================================
func _perform_hit(target_cell: Vector2i, tool_damage: int) -> void:
	var tile_map = player.tile_map_node
	if not tile_map: return

	# 1. TỌA ĐỘ TOÁN HỌC (Nằm sát đất, dùng để đẻ item hít Y-Sort chuẩn xác)
	var pure_cell_global = tile_map.base_ground.to_global(tile_map.base_ground.map_to_local(target_cell))
	
	# 2. TỌA ĐỘ HIỂN THỊ (Cộng thêm độ cao núi, dùng để bắn hạt bụi VFX)
	var vfx_global = pure_cell_global
	if tile_map.world_data.has(target_cell):
		vfx_global.y -= (tile_map.world_data[target_cell]["z"] * tile_map.cliff_height)

	# KIỂM TRA THỰC THỂ: (Hòm, Lò nung, Cây, Đá đã gắn Component)
	if tile_map.get("spawned_objects") and tile_map.spawned_objects.has(target_cell):
		var obj_node = tile_map.spawned_objects[target_cell]
		var health_comp = obj_node.get_node_or_null("HealthDropComponent")
		
		if health_comp:
			# Bắn VFX theo mắt nhìn, nhưng Đẻ đồ theo tọa độ gốc!
			GameEvents.tile_hit_vfx.emit(vfx_global, player.interact_type, obj_node)
			health_comp.take_damage(tool_damage, pure_cell_global)
			return 
			
		elif obj_node.has_method("break_object"):
			GameEvents.tile_hit_vfx.emit(vfx_global, player.interact_type, obj_node)
			obj_node.break_object(pure_cell_global)
			return 

	# VẬT THỂ MẶT ĐẤT (Đào đất trống lấy Dirt)
	GameEvents.tile_hit.emit(player, target_cell, player.interact_type, tool_damage)

func current_state_active() -> bool:
	var fsm = player.get_node_or_null("StateMachine")
	return fsm and fsm.get("current_state") == self
