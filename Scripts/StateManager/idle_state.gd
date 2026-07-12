extends State

var player: Player

func initialize(p: Player) -> void:
	player = p

func enter() -> void:
	player.velocity = Vector2.ZERO

func update(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"): # Thay bằng phím của ông
		transition_requested.emit("Jump")
		return
		
	# Quét xem có nhận phím điều hướng WASD hay không
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# 🎯 CHUYỂN TRẠNG THÁI WASD: Nếu phát hiện có bấm nút di chuyển -> Chuyển ngay sang trạng thái Move
	if input_vector != Vector2.ZERO:
		transition_requested.emit("Move")
		return

	# Cứ đứng rảnh rỗi là đầu ngoe nguẩy theo chuột
	var mouse_angle = rad_to_deg(player.get_local_mouse_position().angle())
	player.last_dir = player.get_4_way_dir(mouse_angle)
	
	var anim_name = "idle_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
		
	# Mở mắt thấy có đường đi A* -> Sang trạng thái Move
	if player.current_path.size() > 0:
		transition_requested.emit("Move")
	# Hoặc thấy có cục đá ở ngay sát cạnh -> Sang trạng thái Interact
	elif player.interact_type != "":
		transition_requested.emit("Interact")
