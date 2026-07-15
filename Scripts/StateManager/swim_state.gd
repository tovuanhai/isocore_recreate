extends State

var player: Player
var auto_jump_cd: float = 0.0

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	auto_jump_cd = 0.15 

func physics_update(delta: float) -> void:
	if auto_jump_cd > 0.0:
		auto_jump_cd -= delta
		
	if Input.is_action_just_pressed("jump"):
		transition_requested.emit("Jump")
		return
		
	var next_state = _execute_movement(delta, player.speed, false)
	if next_state != "":
		transition_requested.emit(next_state)

func _execute_movement(delta: float, speed: float, is_swimming: bool) -> String:
	var tile_map = player.tile_map_node
	
	# ----------------------------------------------------
	# 1. QUÉT WASD BÀN PHÍM
	# ----------------------------------------------------
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector != Vector2.ZERO:
		player.current_path.clear() 
		var raw_dir = input_vector.normalized()
		var iso_dir = Vector2(raw_dir.x, raw_dir.y * 0.5).normalized()
		
		var look_ahead = speed * delta * 2.5 
		var next_pos = player.global_position + (iso_dir * look_ahead)
		var next_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(next_pos))
		var current_cell = player.get_current_cell()
		
		if next_cell != current_cell and tile_map.world_data.has(next_cell):
			var curr_z = MovementUtils._get_walkable_elevation(tile_map, current_cell)
			var next_z = MovementUtils._get_walkable_elevation(tile_map, next_cell)
			var has_obstacle = not MovementUtils._is_walkable(tile_map, next_cell)
			var z_diff = next_z - curr_z
			
			if z_diff > 1:
				iso_dir = Vector2.ZERO 
			elif has_obstacle or z_diff != 0:
				if auto_jump_cd <= 0.0: return "Jump" 
				else: iso_dir = Vector2.ZERO 
		
		player.velocity = iso_dir * speed
		player.move_and_slide()
		
		_update_player_cell_and_animation(tile_map, iso_dir, is_swimming)
		return "Move" if not is_swimming else "Swim"

	# ----------------------------------------------------
	# 2. CHẠY TỰ ĐỘNG BẰNG CHUỘT (CHỌN Ô)
	# ----------------------------------------------------
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if not is_swimming and player.interact_type != "":
			return "Interact"
		_play_anim("idle_", player.last_dir)
		return "Idle"

	var target = player.current_path[0]
	var next_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var current_cell = player.get_current_cell()

	# 🎯 TRẠM KIỂM SOÁT ĐỊA HÌNH DÀNH CHO "CHỌN Ô"
	if next_cell != current_cell and tile_map.world_data.has(next_cell):
		var curr_z = MovementUtils._get_walkable_elevation(tile_map, current_cell)
		var next_z = MovementUtils._get_walkable_elevation(tile_map, next_cell)
		var z_diff = next_z - curr_z
		
		# Chênh lệch độ cao (bước lên đồi hoặc lọt hố)
		if z_diff != 0:
			if auto_jump_cd <= 0.0:
				return "Jump" # Kích hoạt nhảy tự động
			else:
				# Nếu chưa lấy lại thăng bằng (0.15s), nhân vật sẽ đứng đợi ở mép vực
				player.velocity = Vector2.ZERO
				_play_anim("idle_", player.last_dir)
				return "Move" 

	var is_water_cell = tile_map.world_data.get(next_cell, {}).get("is_water", false)

	if not is_swimming and is_water_cell: return "Swim"
	if is_swimming and not is_water_cell: return "Move"

	var dir = (target - player.global_position).normalized()
	player.global_position = player.global_position.move_toward(target, speed * delta)

	var snap_threshold = tile_map.config.move_snap_threshold if tile_map.get("config") else 2.0
	if player.global_position.distance_to(target) <= snap_threshold + (speed * delta):
		player.current_path.remove_at(0)
		GameEvents.player_moved.emit(player, next_cell, MovementUtils._get_walkable_elevation(tile_map, next_cell))

	_update_animation_from_dir(dir, is_swimming)
	return "Swim" if is_water_cell else "Move"

func _update_player_cell_and_animation(tile_map, iso_dir: Vector2, is_swimming: bool) -> void:
	var p_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(player.global_position))
	if not player.has_meta("last_grid_cell") or player.get_meta("last_grid_cell") != p_cell:
		player.set_meta("last_grid_cell", p_cell)
		GameEvents.player_moved.emit(player, p_cell, MovementUtils._get_walkable_elevation(tile_map, p_cell))
	_update_animation_from_dir(iso_dir, is_swimming)

func _update_animation_from_dir(dir: Vector2, is_swimming: bool) -> void:
	var angle_deg = rad_to_deg(dir.angle())
	player.last_dir = MovementUtils._get_8_way_dir_string(angle_deg)
	_play_anim("swim_" if is_swimming else "walk_", player.last_dir)

func _play_anim(prefix: String, dir_suffix: String) -> void:
	MovementUtils._play_directional_animation(player, prefix, dir_suffix)
