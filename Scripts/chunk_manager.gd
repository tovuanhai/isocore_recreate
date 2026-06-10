extends Node

var hub: Node2D
var loaded_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i(9999, 9999)
var is_generating: bool = false

func initialize(p_hub: Node2D) -> void:
	hub = p_hub


func _process(_delta: float) -> void:
	if not hub or not hub.player or is_generating: return
	
	var player_cell = hub.base_ground.local_to_map(hub.base_ground.to_local(hub.player.global_position))
	var player_chunk = Vector2i(floor(float(player_cell.x) / hub.chunk_size), floor(float(player_cell.y) / hub.chunk_size))
	
	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks_async(current_chunk)
		
	# Giao việc update Hover cho HoverManager
	hub.hover_manager.handle_hover_effect()

func update_chunks_async(center: Vector2i) -> void:
	is_generating = true
	var chunks_needed: Dictionary = {}
	for x in range(-hub.render_distance, hub.render_distance + 1):
		for y in range(-hub.render_distance, hub.render_distance + 1):
			chunks_needed[center + Vector2i(x, y)] = true
	
	var chunks_to_remove: Array = []
	for loaded_pos in loaded_chunks.keys():
		if not chunks_needed.has(loaded_pos):
			# Gọi Spawner ra dọn rác
			hub.spawner.unload_chunk_visuals(loaded_pos)
			chunks_to_remove.append(loaded_pos)
			
	await get_tree().process_frame
	for pos in chunks_to_remove: loaded_chunks.erase(pos)
	
	for chunk_pos in chunks_needed.keys():
		if not loaded_chunks.has(chunk_pos):
			# Gọi Generator tính toán và vẽ
			hub.world_generator.generate_chunk_data_and_render(chunk_pos)
			loaded_chunks[chunk_pos] = true
			await get_tree().process_frame
			
	if MovementUtils and MovementUtils.has_method("update_grid"):
		MovementUtils.update_grid(hub)
		
	is_generating = false
