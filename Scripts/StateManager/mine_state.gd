extends State

@onready var player: Player = get_parent().get_parent() as Player

func enter():
	var tile_pos = player.pending_mine_tile
	var tile_map = player.tile_map_node
	var base_layer = tile_map.base_ground
	
	var block_global_pos = base_layer.to_global(base_layer.map_to_local(tile_pos))
	var rock_elev = tile_map.get_cell_elevation(tile_pos)
	if rock_elev != -1:
		block_global_pos.y -= (player.cliff_height * rock_elev)

	var dir_vector = player.global_position.direction_to(block_global_pos)
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir_vector.angle()))

	var anim_name = "hit_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)

	await get_tree().create_timer(0.4).timeout
	mine_block()

func mine_block():
	var tile_pos = player.pending_mine_tile
	var tile_map = player.tile_map_node
	var z = tile_map.get_cell_elevation(tile_pos)

	if z != -1 and tile_map.has_obstacle(tile_pos, z):
		var voxel_pos = Vector3i(tile_pos.x, tile_pos.y, z)
		var obj_id = tile_map.world_data[voxel_pos]["object"]

		if obj_id == player.indestructible_alternative_id:
			print("-> Khối bất tử, gãy cuốc!")
		else:
			if not player.tile_durability.has(tile_pos):
				player.tile_durability[tile_pos] = player.default_max_hits

			player.tile_durability[tile_pos] -= 1
			print("Keng! Máu đá còn: ", player.tile_durability[tile_pos])

			if player.tile_durability[tile_pos] <= 0:
				tile_map.world_data[voxel_pos].erase("object")
				tile_map.base_object.set_cell(tile_pos, -1)
				player.tile_durability.erase(tile_pos)
				print("-> Cục đá đã bốc hơi!")
				
				if MovementUtils and MovementUtils.has_method("update_grid"):
					MovementUtils.update_grid(tile_map)

	player.has_pending_mine = false
	transition_requested.emit("idle")
