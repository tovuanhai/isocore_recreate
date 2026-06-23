extends Node2D

signal chunk_update_requested(center: Vector2i)
signal hover_update_requested
signal world_ready

@onready var base_ground: TileMapLayer = $Layer0
@onready var base_object: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

@onready var world_generator = $WorldGenerator
@onready var chunk_manager = $ChunkManager
@onready var spawner = $Spawner
@onready var hover_manager = $HoverManager

var current_chunk: Vector2i:
	get: return chunk_manager.current_chunk
var is_generating: bool:
	get: return chunk_manager.is_generating
var loaded_chunks: Dictionary:
	get: return chunk_manager.loaded_chunks

@export var config: WorldConfig

# --- ĐỌC TỪ CONFIG ---
var chunk_size: int:
	get: return config.chunk_size
var render_distance: int:
	get: return config.render_distance
var cliff_height: int:
	get: return config.cliff_height
var max_elevation: int:
	get: return config.max_elevation
var water_level: int:
	get: return config.water_level
var deep_water_color: Color:
	get: return config.deep_water_color
var water_tile: Vector2i:
	get: return config.water_tile
var biomes: Dictionary:
	get: return config.get_biomes()
var object_scenes: Array[String]:
	get: return config.object_scenes

# --- RUNTIME DATA ---
var ground_layers: Array[TileMapLayer] = []
var object_layers: Array[TileMapLayer] = []
var water_layers: Array[TileMapLayer] = []
var spawned_objects: Dictionary = {}
var world_data: Dictionary = {}
var ground_durability: Dictionary = {} 

func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()

	world_generator.initialize(self)
	chunk_manager.initialize(self)
	spawner.initialize(self)
	hover_manager.initialize(self)

	world_generator.setup_noises()
	hover_manager.setup_hover_effect()
	if player:
		spawner.setup_safe_spawn()

	world_ready.emit()
	GameEvents.tile_hit.connect(_on_player_interact)

func setup_elevation_layers() -> void:
	y_sort_enabled = true
	ground_layers.clear()
	object_layers.clear()
	water_layers.clear()

	for i in range(max_elevation + 1):
		var g_layer: TileMapLayer
		var o_layer: TileMapLayer
		var w_layer: TileMapLayer

		if i == 0:
			g_layer = base_ground
			o_layer = base_object
			o_layer.clear()

			w_layer = base_ground.duplicate()
			w_layer.clear()
			w_layer.name = "WaterLayer_0"
			add_child(w_layer)
		else:
			g_layer = base_ground.duplicate()
			g_layer.clear()
			g_layer.name = "GroundLayer_" + str(i)
			add_child(g_layer)

			w_layer = base_ground.duplicate()
			w_layer.clear()
			w_layer.name = "WaterLayer_" + str(i)
			add_child(w_layer)

			o_layer = base_object.duplicate()
			o_layer.clear()
			o_layer.name = "ObjectLayer_" + str(i)
			add_child(o_layer)

		var elev_shift = cliff_height * i

		g_layer.position.y = -elev_shift
		w_layer.position.y = -elev_shift
		o_layer.position.y = -elev_shift

		g_layer.y_sort_origin = elev_shift
		w_layer.y_sort_origin = elev_shift
		o_layer.y_sort_origin = elev_shift

		g_layer.z_index = 0
		w_layer.z_index = 0
		o_layer.z_index = 0

		g_layer.y_sort_enabled = true
		w_layer.y_sort_enabled = true
		o_layer.y_sort_enabled = true

		# 🎯 1. ĐẤT TRÊN BỜ VÀ DƯỚI ĐÁY ĐỀU SÁNG ĐẸP (Không bị bùn đen)
		g_layer.self_modulate = Color(1.0, 1.0, 1.0, 1.0) 

		# =================================================================
		# 🎯 CHUẨN JOHNBRX: LẤY MÀU NƯỚC CỦA CHÍNH ÔNG VÀ CHỈNH LẠI ĐỘ TRONG
		# =================================================================
		if i <= water_level:
			# 1. Tính toán độ sâu (4 block là chạm mốc tối đa)
			var blocks_deep = water_level - i
			var max_dark_depth = 4.0
			var depth_ratio = clampf(float(blocks_deep) / max_dark_depth, 0.0, 1.0)
			
			# 2. ĐẤT: Nhuộm dần sang màu deep_water_color (Màu ông cấu hình trong WorldConfig)
			g_layer.self_modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(deep_water_color, depth_ratio)
			
			# 3. NƯỚC: Mở khóa độ trong suốt!
			if i == water_level:
				# Vì file ảnh của ông đã ĐẶC 100%, ta PHẢI bóp Alpha xuống 0.45 ở đây
				# Lúc này nó mới biến thành kính trong suốt để ông nhìn thấu xuống đáy!
				w_layer.self_modulate = Color(1.0, 1.0, 1.0, 0.45)
			else:
				w_layer.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
		else:
			g_layer.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			w_layer.self_modulate = Color(1.0, 1.0, 1.0, 0.0)

		ground_layers.append(g_layer)
		water_layers.append(w_layer)
		object_layers.append(o_layer)

		move_child(w_layer, g_layer.get_index() + 1)
		move_child(base_object, -1)


func get_hovered_tile() -> Vector2i:
	return hover_manager.get_hovered_tile(get_global_mouse_position())

func get_cell_elevation(cell: Vector2i) -> int:
	if world_data.has(cell):
		return world_data[cell]["z"]
	return -1

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	return hover_manager.has_obstacle(cell, elevation)

func _refresh_astar(cell: Vector2i) -> void:
	if not MovementUtils: return
	MovementUtils.update_cell_pathfinding(self, cell)
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		MovementUtils.update_cell_pathfinding(self, cell + dir)

func _on_player_interact(_player: Node2D, cell: Vector2i, action_type: String, damage: int) -> void:
	if not world_data.has(cell): return

	var cell_local = base_ground.map_to_local(cell)
	var vfx_global = base_ground.to_global(cell_local)
	vfx_global.y -= (world_data[cell]["z"] * cliff_height)

	if action_type == "build_ground":
		var data = world_data[cell]
		if data["z"] >= max_elevation or data.get("object", "none") != "none": return

		data["z"] += 1
		var new_z = data["z"]

		var tile_to_set = biomes["dirt"][0]
		if biomes.has(data.get("biome", "dirt")):
			tile_to_set = biomes[data.get("biome", "dirt")][0]

		ground_layers[new_z].set_cell(cell, 0, tile_to_set)

		GameEvents.tile_hit_vfx.emit(vfx_global, "mine_ground", null)
		_refresh_astar(cell)
		
		# 🎯 Cập nhật lại khung viền ngay lập tức
		hover_manager.force_update_hover()
		return

	if action_type == "mine_ground":
		var hp_key = str(cell)
		if not ground_durability.has(hp_key):
			ground_durability[hp_key] = 2 
			
		ground_durability[hp_key] -= damage
		GameEvents.tile_hit_vfx.emit(vfx_global, action_type, null)

		if ground_durability[hp_key] <= 0:
			ground_durability.erase(hp_key)
			_destroy_ground_at_cell(cell)

func _destroy_ground_at_cell(cell: Vector2i) -> void:
	var data = world_data[cell]
	var current_z = data["z"]

	if current_z <= water_level: return

	var pure_cell_global = base_ground.to_global(base_ground.map_to_local(cell))
	var drop_count = randi_range(1, 3)
	for _i in drop_count:
		LootSpawner.spawn_item("dirt", 1, pure_cell_global)

	ground_layers[current_z].set_cell(cell, -1)
	data["z"] -= 1

	if data["z"] <= water_level:
		data["is_water"] = true
		data["biome"] = "dirt"
		# 🎯 Đập lủng rớt xuống nước thì vẽ mặt nước vào Water Layer
		water_layers[water_level].set_cell(cell, 0, water_tile)

	_refresh_astar(cell)
	hover_manager.force_update_hover()
