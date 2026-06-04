extends State

@onready var player: Player = get_parent().get_parent() as Player

func physics_update(delta: float) -> void:
	# Nếu đi hết mảng đường đi
	if player.current_path.size() == 0:
		if player.has_pending_mine:
			transition_requested.emit("mine")
		else:
			transition_requested.emit("idle")
		return

	var target_pos = player.current_path[0]
	var distance = player.global_position.distance_to(target_pos)
	var actual_move_vector = player.global_position.direction_to(target_pos)

	if distance <= player.speed * delta:
		player.global_position = target_pos
		player.current_path.pop_front()
		player.velocity = Vector2.ZERO
	else:
		player.velocity = actual_move_vector * player.speed
		player.move_and_slide()

	# Cập nhật mặt mũi lúc chạy
	var move_angle = rad_to_deg(actual_move_vector.angle())
	player.last_dir = player.get_4_way_dir(move_angle)
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
