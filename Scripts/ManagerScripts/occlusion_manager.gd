extends Node

@onready var player: Player = get_parent()

var occluded_cells: Array[Vector2i] = []
var occluded_objects: Array[Node2D] = [] 

func _process(_delta: float) -> void:
	if not is_instance_valid(player.tile_map_node): return
	
	var p_pos = player.sprite2.global_position 
	var player_cell = player.get_current_cell()
	
	# ==========================================
	# 1. RADAR QUÉT TILEMAP (BẢO VỆ CÙNG TẦNG KHÔNG BỊ MỜ)
	# ==========================================
	var current_occluding_cells: Array[Vector2i] = []
	
	var front_cells = [
		player_cell + Vector2i(1, 0), 
		player_cell + Vector2i(0, 1), 
		player_cell + Vector2i(1, 1)  
	]
	
	for test_cell in front_cells:
		if not player.tile_map_node.world_data.has(test_cell): continue
		
		var cell_z = MovementUtils._get_walkable_elevation(player.tile_map_node, test_cell)
		
		# 🎯 LUẬT THÉP CỦA ÔNG: Chỉ những ô CAO HƠN con mèo mới được phép xét làm mờ!
		# Cùng tầng (cell_z == current_elevation) hoặc thấp hơn -> Lơ đi luôn!
		if cell_z > player.current_elevation:
			
			# Nếu là vách núi che khuất, làm mờ nó và các block dọc xuống dưới màn hình
			var height_diff = cell_z - player.current_elevation
			for i in range(height_diff + 1):
				var cliff_body = test_cell + Vector2i(i, i)
				
				# Chống mờ nhầm cái nền đất mèo đang dẫm lên
				if cliff_body != player_cell:
					current_occluding_cells.append(cliff_body)

	# Hoàn trả & Đổi màu Tile
	for cell in occluded_cells:
		if not current_occluding_cells.has(cell): _set_tile_transparent(cell, false)
	for cell in current_occluding_cells:
		if not occluded_cells.has(cell): _set_tile_transparent(cell, true)
	occluded_cells = current_occluding_cells


	# ==========================================
	# 2. RADAR QUÉT VẬT THỂ RỜI (BẤT TỬ VỚI REGION VÀ OFFSET SPRITE)
	# ==========================================
	var current_occluding_objs: Array[Node2D] = []
	var all_occluders = get_tree().get_nodes_in_group("occluders")
	
	# Nhấc tâm quét lên ngực mèo
	var cat_center = p_pos
	#var cat_center = p_pos + Vector2(0, -12) 

	for obj in all_occluders:
		if not is_instance_valid(obj): continue
		
		# 🎯 Y-SORT CHUẨN XÁC: So sánh thẳng bằng Tọa độ gốc của Object
		# (Vì ông nhấc Sprite lên, nên gốc obj.global_position.y chính là chân thật của nó)
		if obj.global_position.y > p_pos.y:
			
			# Lục tìm Sprite2D bên trong
			var sprites = []
			if obj is Sprite2D: sprites.append(obj)
			for child in obj.get_children():
				if child is Sprite2D: sprites.append(child)
				
			var is_occluding = false
			for sprite in sprites:
				if sprite.texture:
					# 🎯 Lấy Khung hình nguyên bản của ảnh 
					# (Hàm này TỰ ĐỘNG nhận diện Region cắt, Offset, và Centered!)
					var local_rect = sprite.get_rect()
					
					# Phép thuật: Kéo tọa độ ngực mèo vào chung "Không gian của bức ảnh"
					var local_cat_center = sprite.to_local(cat_center)
					
					# Xét xem ngực mèo có lọt vào bên trong bức ảnh đã bị cắt Region không?
					if local_rect.grow(-4.0).has_point(local_cat_center):
						is_occluding = true
						break 
			
			if is_occluding: current_occluding_objs.append(obj)
				
	# Hoàn trả & Đổi màu Object
	for obj in occluded_objects:
		if not current_occluding_objs.has(obj): _fade_object(obj, false)
	for obj in current_occluding_objs:
		if not occluded_objects.has(obj): _fade_object(obj, true)
	occluded_objects = current_occluding_objs

# ==========================================
# HÀM XỬ LÝ ĐỒ HỌA
# ==========================================
func _set_tile_transparent(cell: Vector2i, is_transparent: bool) -> void:
	var layers: Array[TileMapLayer] = []
	if player.tile_map_node:
		for child in player.tile_map_node.get_children():
			if child is TileMapLayer: layers.append(child)
			
	if layers.is_empty() and "base_ground" in player.tile_map_node: 
		layers.append(player.tile_map_node.base_ground)
			
	for i in range(layers.size()):
		# Lớp bọc thép thứ 2: Tuyệt đối không làm mờ layer cùng tầng hoặc thấp hơn
		if i <= player.current_elevation:
			continue

		var layer = layers[i]
		var source_id = layer.get_cell_source_id(cell)
		if source_id != -1: 
			var atlas_coords = layer.get_cell_atlas_coords(cell)
			var alt_id = 1 if is_transparent else 0
			layer.set_cell(cell, source_id, atlas_coords, alt_id)

func _fade_object(obj: Node2D, is_fading: bool) -> void:
	var target_alpha = 0.3 if is_fading else 1.0
	if obj.has_meta("fade_tween"):
		var old_tween = obj.get_meta("fade_tween")
		if is_instance_valid(old_tween) and old_tween.is_valid():
			old_tween.kill()
	var tween = get_tree().create_tween()
	obj.set_meta("fade_tween", tween)
	tween.tween_property(obj, "modulate:a", target_alpha, 0.2).set_trans(Tween.TRANS_SINE)
