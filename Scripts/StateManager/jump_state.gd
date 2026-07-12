extends State

var player: Player

# Thông số vật lý của cú nhảy (Ông có thể tinh chỉnh cho vừa tay)
@export var jump_power: float = 160.0  # Lực nảy ban đầu
@export var gravity: float = 600.0     # Trọng lực kéo xuống

var z_velocity: float = 0.0

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	z_velocity = jump_power
	
	# 🎯 MA THUẬT: TẮT VA CHẠM KHI NHẢY LÊN
	if player.col_shape:
		player.col_shape.set_deferred("disabled", true)

func exit() -> void:
	# 🎯 BẬT LẠI VA CHẠM KHI ĐÁP XUỐNG ĐẤT
	if player.col_shape:
		player.col_shape.set_deferred("disabled", false)

func physics_update(delta: float) -> void:
	# ==========================================
	# 1. XỬ LÝ VẬT LÝ TRỤC Z (LÊN XUỐNG)
	# ==========================================
	z_velocity -= gravity * delta
	player.current_jump_z += z_velocity * delta
	
	# 🎯 CHẠM ĐẤT
	if player.current_jump_z <= 0.0:
		player.current_jump_z = 0.0
		
		# Quyết định xem chạm đất xong thì Đứng im hay Chạy tiếp
		var input_vector = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
		if input_vector != Vector2.ZERO:
			transition_requested.emit("Move")
		else:
			transition_requested.emit("Idle")
		return

	# ==========================================
	# 2. XỬ LÝ DI CHUYỂN TRỤC X/Y (TRÊN KHÔNG TRUNG)
	# ==========================================
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector != Vector2.ZERO:
		
		# 🎯 ĐÃ FIX LỖI ĐI LỆCH: Đồng bộ 100% công thức từ move_state
		var iso_dir = Vector2(input_vector.x, input_vector.y * 0.5).normalized()
		
		player.velocity = iso_dir * player.speed
		
		# Vẫn gọi move_and_slide, nhưng vì col_shape đang bị TẮT, 
		# con mèo sẽ bay xuyên qua mọi hòn đá và thân cây dưới đất!
		player.move_and_slide()
		
		var angle_deg = rad_to_deg(iso_dir.angle())
		player.last_dir = MovementUtils._get_8_way_dir_string(angle_deg)
		
		# (Tùy chọn) Chạy hoạt ảnh nhảy nếu ông có vẽ
		# player.anim_player.play("jump_" + player.last_dir)
