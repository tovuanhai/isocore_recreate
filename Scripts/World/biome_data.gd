class_name BiomeData
extends Resource

@export var id: String = "grass" # Tên định danh (VD: grass, snow, sand)
@export var tiles: Array[Vector2i] = [] # Danh sách tọa độ gạch trên TileSet

@export_group("Tọa Độ Khí Hậu Mục Tiêu (Kiểu Minecraft)")
@export_range(-1.0, 1.0) var target_temp: float = 0.0  # -1 là siêu lạnh, 1 là siêu nóng
@export_range(-1.0, 1.0) var target_hum: float = 0.0   # -1 là siêu khô, 1 là siêu ẩm

@export_group("Điều kiện Độ cao")
@export var min_z: int = 0
@export var max_z: int = 99

@export_group("Thực Vật & Đất Đá")
@export var main_plants: Array[String] = []
@export var main_rocks: Array[String] = []

# Dùng cờ (flag) để kích hoạt các thuật toán sinh đồ đặc biệt
@export var use_shore_logic: bool = false
@export var use_desert_spacing: bool = false
