# occlusion_manager.gd
extends Node

@onready var player: Player = get_parent()

@export var min_opacity: float = 0.5
@export var fade_speed: float = 8.0
@export var check_radius: int = 3

# { Node -> target_opacity } — chỉ track spawned objects
var _fading_objects: Dictionary = {}

# { Vector2i -> Polygon2D } — overlay polygon cho từng tile đang bị fade
var _tile_overlays: Dictionary = {}

# Màu overlay che tile (đen trong suốt)
const TILE_SIZE_HALF = Vector2(8, 4)  # half-size của 1 iso tile, chỉnh theo tileset


func _process(delta: float) -> void:
	if not player.tile_map_node: return

	var occluders = _find_occluders()

	_process_objects(occluders.get("objects", {}), delta)
	_process_tiles(occluders.get("tiles", {}), delta)


# ============================================================
# OBJECTS — fade node trực tiếp
# ============================================================

func _process_objects(occluding_objects: Dictionary, delta: float) -> void:
	# Object không còn che → fade về 1.0
	for node in _fading_objects.keys():
		if not is_instance_valid(node):
			_fading_objects.erase(node)
			continue
		if not occluding_objects.has(node):
			_fading_objects[node] = 1.0

	for node in occluding_objects.keys():
		_fading_objects[node] = occluding_objects[node]

	var to_remove = []
	for node in _fading_objects.keys():
		if not is_instance_valid(node):
			to_remove.append(node)
			continue
		var target: float = _fading_objects[node]
		node.modulate.a = lerp(node.modulate.a, target, fade_speed * delta)
		if abs(node.modulate.a - 1.0) < 0.01 and target == 1.0:
			node.modulate.a = 1.0
			to_remove.append(node)

	for node in to_remove:
		_fading_objects.erase(node)


# ============================================================
# TILES — dùng Polygon2D overlay vì không có per-cell modulate
# ============================================================

func _process_tiles(occluding_tiles: Dictionary, delta: float) -> void:
	var tile_map = player.tile_map_node

	# Tile không còn che → fade overlay về alpha 0 rồi xóa
	for cell in _tile_overlays.keys():
		if not occluding_tiles.has(cell):
			var poly = _tile_overlays[cell]
			if is_instance_valid(poly):
				var new_a = lerp(poly.color.a, 0.0, fade_speed * delta)
				poly.color.a = new_a
				if new_a < 0.01:
					poly.queue_free()
					_tile_overlays.erase(cell)

	# Tile đang che → tạo hoặc update overlay
	for cell in occluding_tiles.keys():
		var target_opacity: float = occluding_tiles[cell]
		# alpha của overlay = 1.0 - target_opacity
		# (target_opacity=0.5 → overlay alpha=0.5 → che 50%)
		var target_alpha = 1.0 - target_opacity

		if not _tile_overlays.has(cell):
			_tile_overlays[cell] = _create_tile_overlay(cell, tile_map)

		var poly = _tile_overlays[cell]
		if is_instance_valid(poly):
			var new_a = lerp(poly.color.a, target_alpha, fade_speed * delta)
			poly.color = Color(0, 0, 0, new_a)


func _create_tile_overlay(cell: Vector2i, tile_map) -> Polygon2D:
	var poly = Polygon2D.new()
	# Hình thoi iso tile chuẩn
	poly.polygon = PackedVector2Array([
		Vector2(0, -TILE_SIZE_HALF.y),
		Vector2(TILE_SIZE_HALF.x, 0),
		Vector2(0, TILE_SIZE_HALF.y),
		Vector2(-TILE_SIZE_HALF.x, 0)
	])
	poly.color = Color(0, 0, 0, 0)
	poly.top_level = true
	poly.z_index = 200

	# Đặt vị trí đúng tile trên đúng layer
	var cell_elev = tile_map.world_data[cell].get("z", 0)
	var layer = tile_map.ground_layers[cell_elev]
	poly.global_position = layer.to_global(layer.map_to_local(cell))

	tile_map.add_child(poly)
	return poly


# ============================================================
# TÌM OCCLUDERS
# ============================================================

func _find_occluders() -> Dictionary:
	var objects: Dictionary = {}
	var tiles: Dictionary = {}
	var tile_map = player.tile_map_node
	var player_cell = player.get_current_cell()
	var player_elev = player.current_elevation

	for x in range(-check_radius, check_radius + 1):
		for y in range(-check_radius, check_radius + 1):
			var cell = player_cell + Vector2i(x, y)
			if not tile_map.world_data.has(cell): continue

			var data = tile_map.world_data[cell]
			var cell_elev = data.get("z", 0)

			if not _is_occluding(cell, player_cell, player_elev, cell_elev): continue

			var dist = Vector2(float(x), float(y)).length()
			var normalized = clampf(dist / float(check_radius), 0.0, 1.0)
			var target_opacity = lerp(min_opacity, 1.0, normalized)

			# Objects
			if tile_map.spawned_objects.has(cell):
				var obj = tile_map.spawned_objects[cell]
				if is_instance_valid(obj):
					if objects.has(obj):
						objects[obj] = min(objects[obj], target_opacity)
					else:
						objects[obj] = target_opacity

			# Tiles — chỉ các tầng cao hơn player
			for h in range(player_elev + 1, cell_elev + 1):
				if h >= tile_map.ground_layers.size(): break
				var layer = tile_map.ground_layers[h]
				if layer.get_cell_source_id(cell) != -1:
					var tile_key = cell  # 1 overlay per cell (lấy tầng cao nhất)
					if tiles.has(tile_key):
						tiles[tile_key] = min(tiles[tile_key], target_opacity)
					else:
						tiles[tile_key] = target_opacity

	return {"objects": objects, "tiles": tiles}


func _is_occluding(cell: Vector2i, player_cell: Vector2i, player_elev: int, cell_elev: int) -> bool:
	# Phải cao hơn player
	if cell_elev <= player_elev: return false

	var dy = cell.y - player_cell.y
	var dx = cell.x - player_cell.x

	# Phải nằm phía trên player trên màn hình (dy <= 0)
	if dy > 0: return false
	# Không lệch ngang quá nhiều
	if abs(dx) > abs(dy) + 1: return false

	return true
