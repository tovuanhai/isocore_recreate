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
var spawned_objects: Dictionary = {}
var world_data: Dictionary = {}
var tile_durability: Dictionary = {}
var block_max_health = {
	"rock1": 3,
	"Grass_Tree": 4,
	"Snow_Tree": 4,
	"ground": 2
}

# Map object_id -> item_id trong ItemRegistry
# Muốn thêm drop mới: chỉ cần thêm 1 dòng vào đây
const OBJECT_DROP_TABLE: Dictionary = {
	"rock1":      "stone",
	"Grass_Tree": "wood",
	"Snow_Tree":  "wood",
}


func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()

	world_generator.initialize(self)
	chunk_manager.initialize(self)
	spawner.initialize(self)
	hover_manager.initialize(self)

	world_generator.setup_noises()
	hover_manager.setup_hover_polygon()
	if player:
		spawner.setup_safe_spawn()

	world_ready.emit()
	GameEvents.tile_hit.connect(_on_player_interact)

func setup_elevation_layers() -> void:
	y_sort_enabled = true
	ground_layers.clear()
	object_layers.clear()

	for i in range(max_elevation + 1):
		var g_layer: TileMapLayer
		var o_layer: TileMapLayer

		if i == 0:
			g_layer = base_ground
			o_layer = base_object
			o_layer.clear()
		else:
			g_layer = base_ground.duplicate()
			g_layer.clear()
			g_layer.name = "GroundLayer_" + str(i)
			add_child(g_layer)

			o_layer = base_object.duplicate()
			o_layer.clear()
			o_layer.name = "ObjectLayer_" + str(i)
			add_child(o_layer)

		var elev_shift = cliff_height * i
		g_layer.position.y = -elev_shift
		o_layer.position.y = -elev_shift
		g_layer.y_sort_origin = elev_shift
		o_layer.y_sort_origin = elev_shift
		g_layer.z_index = 0
		o_layer.z_index = 0
		g_layer.y_sort_enabled = true
		o_layer.y_sort_enabled = true

		var t: float = float(i) / max_elevation
		var brightness: float = lerp(0.58, 1.0, t)
		var mod_color := Color(brightness, brightness * 0.97, brightness * 0.93, 1.0)

		if i < water_level:
			var layer_color_increase: float = 1.0 - (float(i) / float(water_level))
			mod_color = mod_color.lerp(deep_water_color, layer_color_increase)

		g_layer.self_modulate = mod_color
		ground_layers.append(g_layer)
		object_layers.append(o_layer)
		move_child(base_object, -1)

# ============================================================
# PUBLIC API
# ============================================================

func get_hovered_tile() -> Vector2i:
	return hover_manager.get_hovered_tile()

func get_cell_elevation(cell: Vector2i) -> int:
	if world_data.has(cell):
		return world_data[cell]["z"]
	return -1

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	return hover_manager.has_obstacle(cell, elevation)

# ============================================================
# A*
# ============================================================

func _refresh_astar(cell: Vector2i) -> void:
	if not MovementUtils: return
	MovementUtils.update_cell_pathfinding(self, cell)
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		MovementUtils.update_cell_pathfinding(self, cell + dir)


# ============================================================
# INTERACT HANDLER
# ============================================================

# Nhận từ GameEvents.tile_hit(player, cell, action_type, damage)
func _on_player_interact(_player: Node2D, cell: Vector2i, action_type: String, damage: int) -> void:
	if not world_data.has(cell): return

	var cell_local = base_ground.map_to_local(cell)
	var cell_global = base_ground.to_global(cell_local)
	cell_global.y -= (world_data[cell]["z"] * cliff_height)

	if action_type == "build_ground":
		var data = world_data[cell]
		if data["z"] >= max_elevation or data.get("object", "none") != "none": return

		data["z"] += 1
		var new_z = data["z"]

		var tile_to_set = biomes["dirt"][0]
		if biomes.has(data.get("biome", "dirt")):
			tile_to_set = biomes[data.get("biome", "dirt")][0]

		ground_layers[new_z].set_cell(cell, 0, tile_to_set)

		# VFX cho build
		GameEvents.tile_hit_vfx.emit(cell_global, "mine_ground", null)
		_refresh_astar(cell)
		return

	var hp_key = str(cell) + action_type

	if not tile_durability.has(hp_key):
		var default_hp = 3
		if action_type == "mine_object":
			default_hp = block_max_health.get(world_data[cell].get("object", "none"), 3)
		elif action_type == "mine_ground":
			default_hp = block_max_health.get("ground", 2)
		tile_durability[hp_key] = default_hp

	tile_durability[hp_key] -= damage

	# Lấy node vật thể để VFX shake
	var hit_node: Node2D = null
	if action_type == "mine_object" and spawned_objects.has(cell):
		hit_node = spawned_objects[cell]

	# Bắn VFX signal — vfx_manager lắng nghe cái này
	GameEvents.tile_hit_vfx.emit(cell_global, action_type, hit_node)

	if tile_durability[hp_key] <= 0:
		tile_durability.erase(hp_key)
		if action_type == "mine_object":
			_destroy_object_at_cell(cell)
		elif action_type == "mine_ground":
			_destroy_ground_at_cell(cell)


# ============================================================
# DESTROY HANDLERS
# ============================================================

func _destroy_object_at_cell(cell: Vector2i) -> void:
	if world_data.has(cell):
		var obj_id = world_data[cell].get("object", "none")

		var cell_local = base_ground.map_to_local(cell)
		var cell_global = base_ground.to_global(cell_local)
		cell_global.y -= (world_data[cell]["z"] * cliff_height)

		if OBJECT_DROP_TABLE.has(obj_id):
			var drop_count = randi_range(1, 3)
			for _i in drop_count:
				LootSpawner.spawn_item(OBJECT_DROP_TABLE[obj_id], 1, cell_global)

		world_data[cell]["object"] = "none"

	if spawned_objects.has(cell):
		if is_instance_valid(spawned_objects[cell]):
			spawned_objects[cell].queue_free()
		spawned_objects.erase(cell)

	for h in range(max_elevation + 1):
		if h < object_layers.size():
			object_layers[h].set_cell(cell, -1)

	_refresh_astar(cell)


func _destroy_ground_at_cell(cell: Vector2i) -> void:
	var data = world_data[cell]
	var current_z = data["z"]

	if current_z <= water_level: return

	var cell_local = base_ground.map_to_local(cell)
	var cell_global = base_ground.to_global(cell_local)
	cell_global.y -= (current_z * cliff_height)

	var drop_count = randi_range(1, 3)
	for _i in drop_count:
		LootSpawner.spawn_item("dirt", 1, cell_global)

	ground_layers[current_z].set_cell(cell, -1)
	data["z"] -= 1

	if data["z"] <= water_level:
		data["is_water"] = true
		data["biome"] = "dirt"
		ground_layers[water_level].set_cell(cell, 0, water_tile)

	_refresh_astar(cell)
