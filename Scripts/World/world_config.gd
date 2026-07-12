class_name WorldConfig
extends Resource

# --- CHUNK & WORLD ---
@export var chunk_size: int = 16
@export var render_distance: int = 2
@export var max_elevation: int = 40

# --- TERRAIN ---
@export var cliff_height: int = 6
@export var water_level: int = 10
@export var deep_water_color: Color = Color("#1a4d7c")
@export var hover_face_height: int = 3
@export var water_tile: Vector2i = Vector2i(1, 1)

# =========================================================
# 🎯 MẢNG DATA-DRIVEN CHỨA CÁC BIOME
# =========================================================
@export var available_biomes: Array[BiomeData] = []

# --- OBJECTS ---
@export var object_scenes: Array[String] = ["Grass_Tree", "rock1", "Snow_Tree", "cattail", "duckweed", "cactus"]

# --- WORLD GENERATOR ---
@export var density_noise_frequency: float = 0.035
@export var dense_forest_threshold: float = 0.25 
@export var dense_forest_chance: float = 0.35
@export var sparse_rock_chance: float = 0.20
@export var plain_tree_chance: float = 0.02
@export var plain_rock_chance: float = 0.03
@export var safe_spawn_elev_weight: int = 120
@export var safe_spawn_flat_bonus: int = 25
@export var cliff_step_tolerance: int = 1

@export var safe_spawn_search_range: int = 32
@export var biome_noise_frequency: float = 0.002

# --- MOVEMENT ---
@export var move_snap_threshold: float = 0.5

# =========================================================
# 🎯 HÀM DỊCH NGƯỢC (Tương thích với Spawner cũ)
# =========================================================
func get_biomes() -> Dictionary:
	var dict = {}
	for b in available_biomes:
		dict[b.id] = b.tiles
	
	# Đề phòng lỗi nếu Inspector chưa nạp Biome Dirt
	if not dict.has("dirt"): 
		dict["dirt"] = [Vector2i(5,0), Vector2i(5,3), Vector2i(9,0)]
		
	return dict
