extends State

var player: Player

@export var jump_power: float = 120.0  
@export var gravity: float = 600.0     

var z_velocity: float = 0.0
# 🎯 BIẾN LƯU ĐỘ CAO GỐC LÚC BẮT ĐẦU NHẢY
var jump_start_z: int = 0 

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	z_velocity = jump_power
	jump_start_z = player.current_elevation # Lưu lại độ cao dưới mặt đất
	
	if player.col_shape:
		player.col_shape.set_deferred("disabled", true)

func exit() -> void:
	if player.col_shape:
		player.col_shape.set_deferred("disabled", false)

func physics_update(delta: float) -> void:
	# 1. TRỤC Z (LÊN XUỐNG)
	z_velocity -= gravity * delta
	player.current_jump_z += z_velocity * delta
	
	if player.current_jump_z <= 0.0:
		player.current_jump_z = 0.0
		var input_vector = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if input_vector != Vector2.ZERO or not player.current_path.is_empty():
			transition_requested.emit("Move")
		else:
			transition_requested.emit("Idle")
		return

	# 2. TRỤC X/Y (TRÊN KHÔNG TRUNG)
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector != Vector2.ZERO:
		player.current_path.clear() 
		var raw_dir = input_vector.normalized()
		var iso_dir = Vector2(raw_dir.x, raw_dir.y * 0.5).normalized()
		
		# =======================================================
		# 🚨 RADAR CHỐNG PHÓNG TÊN LỬA (TRẠM KIỂM SOÁT TRÊN KHÔNG)
		# =======================================================
		var tile_map = player.tile_map_node
		var look_ahead = (player.speed * 0.7) * delta * 2.5
		var next_pos = player.global_position + (iso_dir * look_ahead)
		var next_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(next_pos))
		var current_cell = player.get_current_cell()

		if next_cell != current_cell and tile_map.world_data.has(next_cell):
			var next_z = MovementUtils._get_walkable_elevation(tile_map, next_cell)
			# Chỉ cho phép bay vào bậc thang cao hơn TỐI ĐA 1 BLOCK so với lúc dậm nhảy!
			if (next_z - jump_start_z) > 1:
				iso_dir = Vector2.ZERO # Khóa cứng trục ngang, rớt xuống đất!
		# =======================================================
		
		player.velocity = iso_dir * (player.speed * 0.7)
		player.move_and_slide()
		
		var angle_deg = rad_to_deg(iso_dir.angle())
		player.last_dir = MovementUtils._get_8_way_dir_string(angle_deg)
		
	elif not player.current_path.is_empty():
		# CHỌN Ô (A*) TRÊN KHÔNG
		var target = player.current_path[0]
		var tile_map = player.tile_map_node
		var next_cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
		
		# Tương tự, nếu đường đi A* lọt vào ô cao hơn 2 bậc, ép rớt xuống đất
		if tile_map.world_data.has(next_cell):
			var next_z = MovementUtils._get_walkable_elevation(tile_map, next_cell)
			if (next_z - jump_start_z) > 1:
				return # Hủy lướt theo mục tiêu
				
		var dir = (target - player.global_position).normalized()
		player.global_position = player.global_position.move_toward(target, (player.speed * 0.7) * delta)
		
		var snap_threshold = tile_map.config.move_snap_threshold if tile_map.get("config") else 2.0
		if player.global_position.distance_to(target) <= snap_threshold + ((player.speed * 0.7) * delta):
			player.current_path.remove_at(0)
			
		player.last_dir = MovementUtils._get_8_way_dir_string(rad_to_deg(dir.angle()))
