extends State

@onready var player: Player = get_parent().get_parent() as Player

func physics_update(delta: float) -> void:
	var next_state = MovementUtils.move_along_path(
		player, 
		player.tile_map_node,  # ← Lấy từ Player, không cần tự giữ
		delta, 
		player.speed, 
		false
	)
	if next_state != "":
		transition_requested.emit(next_state)
