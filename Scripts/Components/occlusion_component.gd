class_name OcclusionComponent
extends Node

# 🎯 Cho phép kéo thả Sprite chính của Object vào đây để lấy tọa độ chuẩn xác nhất
@export var target_sprite: Sprite2D 

# 🛡️ BỘ ĐẾM TĨNH (STATIC): Chia sẻ dữ liệu giữa TẤT CẢ các Component trong game
# Giúp đếm xem có bao nhiêu vật thể đang cùng yêu cầu làm mờ ô gạch/vật thể đó
static var global_tile_refs: Dictionary = {}   # { cell_coords: count }
static var global_object_refs: Dictionary = {} # { object_node: count }

var local_occluded_cells: Array[Vector2i] = []
var local_occluded_objects: Array[Node2D] = []

func _ready() -> void:
	# Tự động tìm Sprite nếu ông quên không kéo thả trong Inspector
	if target_sprite == null:
		target_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
		if target_sprite == null:
			target_sprite = get_parent().get_node_or_null("Sprite2D2") as Sprite2D

func _process(_delta: float) -> void:
	var tile_map_node = get_tree().current_scene.get_node_or_null("TileMap")
	if not is_instance_valid(tile_map_node): return
	
	var parent = get_parent() as Node2D
	if not is_instance_valid(parent): return
	
	# 🎯 TỌA ĐỘ PHÉP MÀU: Lấy vị trí tâm thực tế từ Sprite chính của vật thể
	var current_pos = target_sprite.global_position if is_instance_valid(target_sprite) else parent.global_position
	
	var base_ground = tile_map_node.base_ground
	var current_cell = base_ground.local_to_map(base_ground.to_local(parent.global_position))
	
	# Động não tìm Độ Cao (Elevation): Nếu là Player thì có sẵn, nếu là GroundItem thì tra từ lưới
	var current_elevation = parent.get("current_elevation")
	if current_elevation == null:
		current_elevation = MovementUtils._get_walkable_elevation(tile_map_node, current_cell)

	# ==========================================
	# 1. RADAR XÉT TILEMAP (VÁCH NÚI)
	# ==========================================
	var current_occluding_cells: Array[Vector2i] = []
	var front_cells = [
		current_cell + Vector2i(1, 0), 
		current_cell + Vector2i(0, 1), 
		current_cell + Vector2i(1, 1)  
	]
	
	for test_cell in front_cells:
		if not tile_map_node.world_data.has(test_cell): continue
		var cell_z = MovementUtils._get_walkable_elevation(tile_map_node, test_cell)
		
		if cell_z > current_elevation:
			var height_diff = cell_z - current_elevation
			for i in range(height_diff + 1):
				var cliff_body = test_cell + Vector2i(i, i)
				if cliff_body != current_cell:
					current_occluding_cells.append(cliff_body)

	# Cập nhật ô gạch dựa trên Bộ Đếm Tĩnh
	for cell in local_occluded_cells:
		if not current_occluding_cells.has(cell):
			global_tile_refs[cell] = global_tile_refs.get(cell, 1) - 1
			if global_tile_refs[cell] <= 0:
				global_tile_refs.erase(cell)
				_set_tile_transparent(tile_map_node, cell, false, current_elevation)

	for cell in current_occluding_cells:
		if not local_occluded_cells.has(cell):
			global_tile_refs[cell] = global_tile_refs.get(cell, 0) + 1
			if global_tile_refs[cell] == 1:
				_set_tile_transparent(tile_map_node, cell, true, current_elevation)
				
	local_occluded_cells = current_occluding_cells

	# ==========================================
	# 2. RADAR XÉT VẬT THỂ (CÂY, ĐÁ)
	# ==========================================
	var current_occluding_objs: Array[Node2D] = []
	var all_occluders = get_tree().get_nodes_in_group("occluders")
	
	for obj in all_occluders:
		if not is_instance_valid(obj) or obj == parent: continue
		
		if obj.global_position.y > current_pos.y:
			var sprites = []
			if obj is Sprite2D: sprites.append(obj)
			for child in obj.get_children():
				if child is Sprite2D: sprites.append(child)
				
			var is_occluding = false
			for sprite in sprites:
				if sprite.texture:
					var local_rect = sprite.get_rect()
					var local_center = sprite.to_local(current_pos)
					if local_rect.grow(-4.0).has_point(local_center):
						is_occluding = true
						break 
			
			if is_occluding: current_occluding_objs.append(obj)
				
	# Cập nhật Cây/Đá dựa trên Bộ Đếm Tĩnh
	for obj in local_occluded_objects:
		if not current_occluding_objs.has(obj):
			if is_instance_valid(obj):
				global_object_refs[obj] = global_object_refs.get(obj, 1) - 1
				if global_object_refs[obj] <= 0:
					global_object_refs.erase(obj)
					_fade_object(obj, false)

	for obj in current_occluding_objs:
		if not local_occluded_objects.has(obj):
			global_object_refs[obj] = global_object_refs.get(obj, 0) + 1
			if global_object_refs[obj] == 1:
				_fade_object(obj, true)
				
	local_occluded_objects = current_occluding_objs

# Khôi phục đồ họa an toàn khi Node bị xóa khỏi bộ nhớ (Mèo dịch chuyển hoặc Item được nhặt lên)
func _exit_tree() -> void:
	var tile_map_node = get_tree().current_scene.get_node_or_null("TileMap")
	var parent = get_parent()
	var current_elev = parent.get("current_elevation") if is_instance_valid(parent) else 0
	if current_elev == null: current_elev = 0

	for cell in local_occluded_cells:
		global_tile_refs[cell] = global_tile_refs.get(cell, 1) - 1
		if global_tile_refs[cell] <= 0 and is_instance_valid(tile_map_node):
			global_tile_refs.erase(cell)
			_set_tile_transparent(tile_map_node, cell, false, current_elev)
			
	for obj in local_occluded_objects:
		if is_instance_valid(obj):
			global_object_refs[obj] = global_object_refs.get(obj, 1) - 1
			if global_object_refs[obj] <= 0:
				global_object_refs.erase(obj)
				_fade_object(obj, false)

# ==========================================
# CÁC HÀM ĐỒ HỌA TRUNG GIAN
# ==========================================
func _set_tile_transparent(tile_map_node, cell: Vector2i, is_transparent: bool, current_elev: int) -> void:
	var layers: Array[TileMapLayer] = []
	for child in tile_map_node.get_children():
		if child is TileMapLayer: layers.append(child)
	if layers.is_empty() and "base_ground" in tile_map_node: layers.append(tile_map_node.base_ground)
			
	for i in range(layers.size()):
		if i <= current_elev: continue
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
		if is_instance_valid(old_tween) and old_tween.is_valid(): old_tween.kill()
	var tween = get_tree().create_tween()
	obj.set_meta("fade_tween", tween)
	tween.tween_property(obj, "modulate:a", target_alpha, 0.2).set_trans(Tween.TRANS_SINE)
