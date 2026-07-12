extends State

var player: Player

func initialize(p: Player) -> void:
	player = p

func physics_update(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		transition_requested.emit("Jump")
		return
		
	var next_state = _execute_movement(delta, player.speed, false)
	if next_state != "":
		transition_requested.emit(next_state)

# 🎯 ĐÃ GỘP TẤT CẢ LOGIC VẬT LÝ VÀO ĐÚNG STATE CỦA PLAYER
func _execute_movement(delta: float, speed: float, is_swimming: bool) -> String:
	var tile_map = player.tile_map_node
	
	# ----------------------------------------------------
	# 1. QUÉT WASD BÀN PHÍM (ĐÃ FIX CHUẨN)
	# ----------------------------------------------------
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector != Vector2.ZERO:
		player.current_path.clear() 
		
		# 🎯 ĐÚNG Ý ÔNG 100%: D=Sang Phải, A=Sang Trái, W=Đi Lên.
		# Khi nhấn W+D, trục Y tự động ép xéo 50% tạo thành đường đi bám sát mép viền gạch!
		var iso_dir = Vector2(input_vector.x, input_vector.y * 0.5).normalized()
		
		# 🎯 XÓA BỨC TƯỜNG ẢO LẰNG NHẰNG: Trả lại sự mượt mà tuyệt đối cho hàm vật lý Godot
		player.velocity = iso_dir * speed
		player.move_and_slide()
		
		_update_player_cell_and_animation(tile_map, iso_dir, is_swimming)
		return "Move" if not is_swimming else "Swim"

	# ----------------------------------------------------
	# 2. VẬN HÀNH CHẠY TỰ ĐỘNG BÁM THEO ĐƯỜNG A*
	# ----------------------------------------------------
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if not is_swimming and player.interact_type != "":
			return "Interact"
		_play_anim("idle_", player.last_dir)
		return "Idle"

	var target = player.current_path[0]
	var cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var is_water_cell = tile_map.world_data.get(cell, {}).get("is_water", false)

	if not is_swimming and is_water_cell: return "Swim"
	if is_swimming and not is_water_cell: return "Move"

	var dir = (target - player.global_position).normalized()
	
	# Dùng lướt mượt toán học để khỏi cọ xát góc cây/đá gây tụt FPS
	player.global_position = player.global_position.move_toward(target, speed * delta)

	var snap_threshold = tile_map.config.move_snap_threshold if tile_map.get("config") else 2.0
	if player.global_position.distance_to(target) <= snap_threshold + (speed * delta):
		player.current_path.remove_at(0)
		GameEvents.player_moved.emit(player, cell, MovementUtils._get_walkable_elevation(tile_map, cell))

	_update_animation_from_dir(dir, is_swimming)
	return "Swim" if is_water_cell else "Move"

# ==========================================
# CÁC HÀM TIỆN ÍCH HOẠT ẢNH
# ==========================================
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
