extends State

@onready var player: Player = get_parent().get_parent() as Player


func physics_update(_delta: float):
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		if player.has_pending_mine: transition_requested.emit("mine")
		else: transition_requested.emit("idle")
		return

	var target = player.current_path[0]
	var dir = player.global_position.direction_to(target)
	
	# Di chuyển tịnh tiến chuẩn xác
	player.global_position = player.global_position.move_toward(target, player.speed * _delta)

	# 🎯 FIX LỆCH Ô (SUB-PIXEL SNAP):
	# Thu hẹp khoảng cách check và ÉP tọa độ con mèo vào đúng tâm ô để tránh sai số thập phân
	if player.global_position.distance_to(target) < 0.5:
		player.global_position = target # 🔒 Khóa chặt vị trí
		player.current_path.remove_at(0)

	player.last_dir = player.get_4_way_dir(rad_to_deg(dir.angle()))
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
