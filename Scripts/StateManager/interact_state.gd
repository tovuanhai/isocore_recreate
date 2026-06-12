extends State

var player: Player

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	player.velocity = Vector2.ZERO
	var tile_map = player.tile_map_node
	var base_layer = tile_map.base_ground

	# Đồng bộ góc nhìn
	var block_flat_pos = base_layer.to_global(base_layer.map_to_local(player.interact_tile))
	var dir_vector = player.global_position.direction_to(block_flat_pos)
	player.last_dir = player.get_4_way_dir(rad_to_deg(dir_vector.angle()))

	# Hoạt ảnh
	var anim_name = "hit_" + player.last_dir
	if player.interact_type == "build_ground":
		anim_name = "build_" + player.last_dir
	elif player.interact_type == "mine_ground":
		anim_name = "dig_" + player.last_dir

	if player.anim_player.has_animation(anim_name):
		player.anim_player.play(anim_name)
	elif player.anim_player.has_animation("hit_" + player.last_dir):
		player.anim_player.play("hit_" + player.last_dir)
	else:
		player.anim_player.play("walk_" + player.last_dir)

	await get_tree().create_timer(0.35).timeout

	if current_state_active():
		execute_interaction()

func execute_interaction() -> void:
	# Tính damage dựa vào tool đang cầm
	# Sau này thay "wooden_shovel" bằng player.get_equipped_item()
	var damage = 1
	var current_tool = "wooden_shovel"

	if player.interact_type == "mine_ground":
		if current_tool == "wooden_shovel": damage = 2
		elif current_tool == "wooden_pickaxe": damage = 1
	elif player.interact_type == "mine_object":
		if current_tool == "wooden_pickaxe": damage = 2
		elif current_tool == "wooden_shovel": damage = 1

	# Emit đúng format: (player: Node2D, cell: Vector2i, action_type: String, damage: int)
	GameEvents.tile_hit.emit(player, player.interact_tile, player.interact_type, damage)

	await get_tree().create_timer(0.15).timeout
	if current_state_active():
		player.interact_type = ""
		transition_requested.emit("Idle")

func current_state_active() -> bool:
	var fsm = player.get_node_or_null("StateMachine")
	return fsm and fsm.get("current_state") == self
