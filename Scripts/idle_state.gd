extends State

# Tìm ngược lên 2 bậc để lấy thân xác con mèo
@onready var player: Player = get_parent().get_parent() as Player

func enter() -> void:
	player.velocity = Vector2.ZERO

func update(_delta: float) -> void:
	# Cứ đứng rảnh rỗi là đầu ngoe nguẩy theo chuột
	var mouse_angle = rad_to_deg(player.get_local_mouse_position().angle())
	player.last_dir = player.get_4_way_dir(mouse_angle)
	
	var anim_name = "idle_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
		
	# Mở mắt thấy có đường đi -> Sang trạng thái Move
	if player.current_path.size() > 0:
		transition_requested.emit("move")
	# Hoặc thấy có cục đá ở ngay sát cạnh -> Sang trạng thái Mine
	elif player.has_pending_mine:
		transition_requested.emit("mine")
