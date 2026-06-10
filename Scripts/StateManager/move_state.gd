extends State

@onready var player: Player = get_parent().get_parent() as Player
@onready var tile_map = player.get_parent().get_node("TileMap") 

func physics_update(_delta: float):
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if player.has_pending_mine: 
			transition_requested.emit("Mine")
		else: 
			transition_requested.emit("Idle")
		return

	var target = player.current_path[0]

	# Check địa hình ô tiếp theo
	var cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var elev = tile_map.get_cell_elevation(cell)
	
	# Nếu ô tiếp theo thấp hơn hoặc bằng mực nước biển -> Nhảy sang Swim
	if elev != -1 and elev <= tile_map.water_level:
		transition_requested.emit("Swim")
		return

	var dir = player.global_position.direction_to(target)
	
	# Di chuyển tịnh tiến chuẩn xác
	player.global_position = player.global_position.move_toward(target, player.speed * _delta)

	# FIX LỆCH Ô
	if player.global_position.distance_to(target) < 0.5:
		player.global_position = target
		player.current_path.remove_at(0)

	player.last_dir = player.get_4_way_dir(rad_to_deg(dir.angle()))
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
