# world_config.gd
class_name WorldConfig
extends Resource

# --- CHUNK & WORLD ---
@export var chunk_size: int = 16
@export var render_distance: int = 2
@export var max_elevation: int = 20

# --- TERRAIN ---
@export var cliff_height: int = 6
@export var water_level: int = 10
@export var deep_water_color: Color = Color("#1a4d7c")
@export var hover_face_height: int = 3

# --- BIOMES (tile coords) ---
@export var biome_grass: Array[Vector2i] = [Vector2i(2,3), Vector2i(2,0), Vector2i(3,0)]
@export var biome_snow: Array[Vector2i]  = [Vector2i(7,3), Vector2i(9,3)]
@export var biome_dirt: Array[Vector2i]  = [Vector2i(5,0), Vector2i(5,3), Vector2i(9,0)]
@export var water_tile: Vector2i = Vector2i(1, 1)

# --- OBJECTS ---
@export var object_scenes: Array[String] = ["Grass_Tree", "rock1", "Snow_Tree"]

# --- WORLD GENERATOR (octave frequencies được set cứng trong code) ---
@export var biome_noise_frequency: float = 0.015
@export var density_noise_frequency: float = 0.035

# --- SPAWN DENSITY ---
@export var dense_forest_threshold: float = 0.25  # Noise > threshold → rừng rậm
@export var dense_forest_chance: float = 0.35
@export var sparse_rock_chance: float = 0.20
@export var plain_tree_chance: float = 0.02
@export var plain_rock_chance: float = 0.03

# --- MOVEMENT ---
@export var move_snap_threshold: float = 0.5

# --- WORLD GENERATION ---
@export var cliff_step_tolerance: int = 1

# --- SPAWN ---
@export var safe_spawn_search_range: int = 32
@export var safe_spawn_elev_weight: int = 120
@export var safe_spawn_flat_bonus: int = 25

# Helper để dùng như Dictionary cũ
func get_biomes() -> Dictionary:
	return {
		"grass": biome_grass,
		"snow": biome_snow,
		"dirt": biome_dirt
	}
