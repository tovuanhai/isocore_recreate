extends Node2D

@onready var base_ground: TileMapLayer = $Layer0
@onready var base_object: TileMapLayer = $Layer1
@onready var player: CharacterBody2D = $"../Player"

# 🎯 Nhận diện 4 Trưởng phòng
@onready var world_generator = $WorldGenerator
@onready var chunk_manager = $ChunkManager
@onready var spawner = $Spawner
@onready var hover_manager = $HoverManager

# 📦 KHO DỮ LIỆU DÙNG CHUNG (Giữ nguyên 100% thông số của ông)
var world_data: Dictionary = {}
@export var chunk_size: int = 16
@export var render_distance: int = 2
@export var cliff_height: int = 6
@export var max_elevation: int = 13
@export var hover_face_height: int = 3

var ground_layers: Array[TileMapLayer] = []
var object_layers: Array[TileMapLayer] = []
var spawned_objects: Dictionary = {}

var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)],
	"sand": [Vector2i(7, 3), Vector2i(9, 3)],
	"dirt": [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]
}

var object_scenes = {
	"LightBulb": {"source_id": 4, "alt_id": 1},
	"rock1": {"source_id": 2, "alt_id": 1}
}

func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()
	
	# Gọi các trưởng phòng khởi động
	world_generator.setup_noises()
	hover_manager.setup_hover_polygon()
	if player:
		spawner.setup_safe_spawn()

# Hàm này tạo các Layer vật lý, thuộc về Giám Đốc là chuẩn nhất
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
			g_layer = base_ground.duplicate(); g_layer.clear(); g_layer.name = "GroundLayer_" + str(i); add_child(g_layer)
			o_layer = base_object.duplicate(); o_layer.clear(); o_layer.name = "ObjectLayer_" + str(i); add_child(o_layer)
		
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
		g_layer.self_modulate = mod_color
		o_layer.self_modulate = mod_color
		
		ground_layers.append(g_layer)
		object_layers.append(o_layer)
		
		move_child(base_object, -1)

# ====================================================================
# 🌉 CÁC HÀM CẦU NỐI (BRIDGE FUNCTIONS) DÀNH CHO CÁC HỆ THỐNG BÊN NGOÀI
# (UI, Player, Minimap... gọi vào đây, Giám Đốc sẽ tự động điều phối)
# ====================================================================

func get_hovered_tile() -> Vector2i:
	return hover_manager.get_hovered_tile()

func get_cell_elevation(cell: Vector2i) -> int:
	if world_data.has(cell): 
		return world_data[cell]["z"]
	return -1

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	return hover_manager.has_obstacle(cell, elevation)


# ====================================================================
# 🌉 CÁC BIẾN CẦU NỐI (BRIDGE PROPERTIES) DÀNH CHO BÊN NGOÀI ĐỌC DỮ LIỆU
# ====================================================================

var current_chunk: Vector2i:
	get: return chunk_manager.current_chunk

var is_generating: bool:
	get: return chunk_manager.is_generating

var loaded_chunks: Dictionary:
	get: return chunk_manager.loaded_chunks
