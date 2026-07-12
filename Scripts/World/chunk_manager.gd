extends Node

var hub: Node2D
var loaded_chunks: Dictionary = {}
var current_chunk: Vector2i = Vector2i(9999, 9999)

# Biến lưu trữ các chunk đang được gửi đi tính toán
var generating_tasks: Dictionary = {} 

func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func _process(_delta: float) -> void:
	if not hub or not hub.player:
		return

	var player_cell = hub.base_ground.local_to_map(hub.base_ground.to_local(hub.player.global_position))
	var player_chunk = Vector2i(
		floor(float(player_cell.x) / hub.chunk_size),
		floor(float(player_cell.y) / hub.chunk_size)
	)

	if player_chunk != current_chunk:
		current_chunk = player_chunk
		update_chunks_async(current_chunk)

	hub.hover_manager.handle_hover_effect()

func update_chunks_async(center: Vector2i) -> void:
	var chunks_needed: Dictionary = {}
	for x in range(-hub.render_distance, hub.render_distance + 1):
		for y in range(-hub.render_distance, hub.render_distance + 1):
			chunks_needed[center + Vector2i(x, y)] = true

	# --- DỌN RÁC CHUNK CŨ (Làm ngay lập tức trên Main Thread) ---
	var chunks_to_remove: Array = []
	for loaded_pos in loaded_chunks.keys():
		if not chunks_needed.has(loaded_pos):
			hub.spawner.unload_chunk_visuals(loaded_pos)
			chunks_to_remove.append(loaded_pos)

	for pos in chunks_to_remove:
		loaded_chunks.erase(pos)

	# --- LOAD CHUNK MỚI (Đẩy sang Thread Phụ) ---
	for chunk_pos in chunks_needed.keys():
		if not loaded_chunks.has(chunk_pos) and not generating_tasks.has(chunk_pos):
			generating_tasks[chunk_pos] = true # Đánh dấu để không tạo trùng lặp
			
			# 🎯 Đỉnh cao Multithreading: Đẩy tác vụ tính toán sang Core CPU khác
			WorkerThreadPool.add_task(_thread_calculate_chunk.bind(chunk_pos), true, "GenChunk_" + str(chunk_pos))

# ==============================================================================
# HÀM CHẠY TRÊN THREAD NGẦM (BACKGROUND)
# ==============================================================================
func _thread_calculate_chunk(chunk_pos: Vector2i) -> void:
	# Não bộ tính toán 100% bằng toán học, không đụng vào đồ họa
	var chunk_data = hub.world_generator.generate_chunk_data(chunk_pos)
	
	# Tính xong, gọi "call_deferred" để gửi hàng về cho Main Thread xử lý một cách an toàn
	call_deferred("_on_chunk_data_ready", chunk_pos, chunk_data)

# ==============================================================================
# HÀM CHẠY TRÊN MAIN THREAD (Nhận hàng từ Thread ngầm gửi về)
# ==============================================================================
func _on_chunk_data_ready(chunk_pos: Vector2i, chunk_data: Dictionary) -> void:
	generating_tasks.erase(chunk_pos)

	# 🎯 FIX GHOST CHUNK: Kiểm tra xem lúc nhận hàng, Player đã chạy đi quá xa chưa?
	var dist_x = abs(chunk_pos.x - current_chunk.x)
	var dist_y = abs(chunk_pos.y - current_chunk.y)
	
	# Nếu khoảng cách vượt quá render_distance, lập tức hủy bỏ không vẽ nữa!
	if dist_x > hub.render_distance or dist_y > hub.render_distance:
		return 

	loaded_chunks[chunk_pos] = true

	# 1. Merge dữ liệu vào bộ nhớ tổng của Game
	for pos in chunk_data:
		if not hub.world_data.has(pos):
			hub.world_data[pos] = chunk_data[pos]

	# 2. Quăng danh sách tọa độ sang Hàng Đợi (Queue) cho Thợ Xây vẽ dần
	hub.spawner.enqueue_chunk_render(chunk_data.keys())

	# Cập nhật thuật toán tìm đường (A*)
	if MovementUtils and MovementUtils.has_method("update_chunk"):
		MovementUtils.update_chunk(hub, chunk_pos)
