extends Node2D


signal chunk_update_requested(center: Vector2i)
signal hover_update_requested
signal world_ready

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

@export var water_level: int = 7
var water_tile: Vector2i = Vector2i(1, 1)
@export var deep_water_color: Color = Color("#1a4d7c")

var cloud_material: ShaderMaterial
var cloud_noise_tex: NoiseTexture2D

var biomes = {
	"grass": [Vector2i(2, 3), Vector2i(2, 0), Vector2i(3, 0)],
	"snow": [Vector2i(7, 3), Vector2i(9, 3)],
	"dirt": [Vector2i(5, 0), Vector2i(5, 3), Vector2i(9, 0)]
}

var object_scenes: Array[String] = ["Grass_Tree", "rock1", "Snow_Tree"]

func _ready() -> void:
	y_sort_enabled = true
	setup_elevation_layers()
	
	# INJECT: Truyền reference Hub vào các con thay vì chúng tự get_parent()
	world_generator.initialize(self)
	chunk_manager.initialize(self)
	spawner.initialize(self)
	hover_manager.initialize(self)

	world_generator.setup_noises()
	hover_manager.setup_hover_polygon()
	if player:
		spawner.setup_safe_spawn()

	if player and player.has_node("Sprite2D"):
		var p_mat = cloud_material.duplicate()
		player.get_node("Sprite2D").material = p_mat

	world_ready.emit()

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
		
		# --- TÍNH TOÁN ĐỘ SÁNG MẶC ĐỊNH (CÀNG CAO CÀNG SÁNG) ---
		var t: float = float(i) / max_elevation
		var brightness: float = lerp(0.58, 1.0, t)
		var mod_color := Color(brightness, brightness * 0.97, brightness * 0.93, 1.0)
		
		# =========================================================
		# 🌊 THUẬT TOÁN NHUỘM MÀU ĐỘ SÂU (JOHN BRX ALGORITHM)
		# =========================================================
		if i < water_level:
			# Công thức gốc: layerColorIncrease = 1 - (cell.z / seaLevel)
			var layer_color_increase: float = 1.0 - (float(i) / float(water_level))
			
			# Lấy màu gốc trộn với màu vực sâu theo tỉ lệ độ sâu
			# (Nhân thêm 0.85 để vẫn nhìn thấy mờ mờ vân gạch đất dưới đáy)
			mod_color = mod_color.lerp(deep_water_color, layer_color_increase * 0.85)
		
		g_layer.self_modulate = mod_color 
		
		
		ground_layers.append(g_layer)
		object_layers.append(o_layer)
		
		move_child(base_object, -1)

func get_hovered_tile() -> Vector2i:
	return hover_manager.get_hovered_tile()

func get_cell_elevation(cell: Vector2i) -> int:
	if world_data.has(cell): 
		return world_data[cell]["z"]
	return -1

func has_obstacle(cell: Vector2i, elevation: int) -> bool:
	return hover_manager.has_obstacle(cell, elevation)
	
var current_chunk: Vector2i:
	get: return chunk_manager.current_chunk

var is_generating: bool:
	get: return chunk_manager.is_generating

var loaded_chunks: Dictionary:
	get: return chunk_manager.loaded_chunks
