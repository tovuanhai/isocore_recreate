extends State

@onready var player: Player = get_parent().get_parent() as Player

func enter() -> void:
	mine_block()

func mine_block() -> void:
	player.velocity = Vector2.ZERO
	
	# Ép góc nhìn vào cục đá
	var tile_pos = player.pending_mine_tile
	var block_global_pos = player.tilemap_layer.map_to_local(tile_pos)
	var dir_vector = player.global_position.direction_to(block_global_pos)
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir_vector.angle()))
	
	var anim_name = "hit_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
	
	# Chờ cuốc bổ xuống
	await get_tree().create_timer(0.4).timeout
	
	# Tính toán máu
	if player.blocked_layer.get_cell_source_id(tile_pos) != -1:
		var alt_id = player.blocked_layer.get_cell_alternative_tile(tile_pos)
		if alt_id == player.indestructible_alternative_id:
			print("-> Khối bất tử, gãy cuốc!")
		else:
			if not player.tile_durability.has(tile_pos):
				player.tile_durability[tile_pos] = player.default_max_hits
				
			player.tile_durability[tile_pos] -= 1
			print("-> Máu cục đá còn: ", player.tile_durability[tile_pos])
			
			if player.tile_durability[tile_pos] <= 0:
				player.blocked_layer.set_cell(tile_pos, -1)
				player.tile_durability.erase(tile_pos)
				
	# Xong việc, reset và quay về Idle
	player.has_pending_mine = false
	transition_requested.emit("idle")
