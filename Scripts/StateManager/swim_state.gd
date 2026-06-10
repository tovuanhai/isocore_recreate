extends State

@onready var player: Player = get_parent().get_parent() as Player
@onready var tile_map = player.get_parent().get_node("TileMap")

@export var swim_speed_multiplier: float = 0.5 
var original_sprite_y: float = 0.0

func enter(_msg := {}) -> void:
	# Lấy đúng Sprite2D qua VisualRoot
	var sprite = player.get_node("VisualRoot/Sprite2D") 
	original_sprite_y = sprite.position.y 
	
	# Tụt nhẹ người xuống 6px và đổi màu cả cụm bằng self_modulate gốc
	sprite.position.y = original_sprite_y + 6.0
	sprite.self_modulate = Color(0.6, 0.8, 1.0) 

func exit() -> void:
	# Trả lại nguyên trạng khi lên bờ
	var sprite = player.get_node("VisualRoot/Sprite2D")
	sprite.position.y = original_sprite_y
	sprite.self_modulate = Color.WHITE

func physics_update(_delta: float) -> void:
	if player.current_path.is_empty():
		player.velocity = Vector2.ZERO
		transition_requested.emit("Idle")
		return

	var target = player.current_path[0]

	# Check địa hình ô tiếp theo
	var cell = tile_map.base_ground.local_to_map(tile_map.base_ground.to_local(target))
	var elev = tile_map.get_cell_elevation(cell)
	
	# Nếu ô tiếp theo cao hơn mực nước biển -> Nhảy về Move (Lên bờ)
	if elev != -1 and elev > tile_map.water_level:
		transition_requested.emit("Move") 
		return

	var dir = player.global_position.direction_to(target)
	
	# Đi chậm lại theo hệ số tốc độ bơi
	var current_speed = player.speed * swim_speed_multiplier
	player.global_position = player.global_position.move_toward(target, current_speed * _delta)

	# FIX LỆCH Ô
	if player.global_position.distance_to(target) < 0.5:
		player.global_position = target
		player.current_path.remove_at(0)

	player.last_dir = player.get_4_way_dir(rad_to_deg(dir.angle()))
	var anim_name = "walk_" + player.last_dir
	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
