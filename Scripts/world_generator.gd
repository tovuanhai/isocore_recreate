extends Node


var biome_noise: FastNoiseLite
var elevation_noise: FastNoiseLite
var density_noise: FastNoiseLite # 🌿 Lớp Bản đồ nhiệt quản lý Cụm

var hub: Node2D  # ← Thay @onready var hub = get_parent()

func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func setup_noises() -> void:
	var cfg = hub.config

	# ✅ new() TRƯỚC, set properties SAU
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = cfg.biome_noise_frequency

	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi() + 777
	elevation_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	elevation_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	elevation_noise.frequency = cfg.elevation_noise_frequency
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_PING_PONG

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM

func generate_chunk_data_and_render(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size
	
	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var pos_2d = Vector2i(global_x, global_y)
			
			if not hub.world_data.has(pos_2d):
				var e_val = elevation_noise.get_noise_2d(global_x, global_y)
				var normalized_e = pow((e_val + 1.0) / 2.0, 1.5)
				var elevation = clampi(int(normalized_e * (hub.max_elevation + 1)), 0, hub.max_elevation)
				
				var biome_name = "grass"
				var spawn_obj = "none"
				var is_water = false
				
				# 🌊 NẾU LÀ ĐÁY BIỂN
				if elevation <= hub.water_level:
					is_water = true
					biome_name = "dirt"
				
				# 🏔️ NẾU LÀ ĐẤT LIỀN
				else:
					var b_val = biome_noise.get_noise_2d(global_x, global_y)
					if b_val < 0.0: biome_name = "snow"
					else: biome_name = "grass"
					
					# ===================================================
					# 🌲 LOGIC MỌC CỤM (ÁP DỤNG CHO CẢ CỎ VÀ TUYẾT)
					# ===================================================
					if biome_name == "grass" or biome_name == "snow": 
						# Tự động chọn loại cây theo Biome
						var tree_type = "Grass_Tree"
						if biome_name == "snow":
							tree_type = "Snow_Tree"
							
						# Quét bản đồ nhiệt
						var d_val = density_noise.get_noise_2d(global_x, global_y)
						var rand = randf()
						
						# 1. VÙNG RỪNG RẬM (Màu mỡ: Noise > 0.25)
						if d_val > 0.25:
							if rand < 0.35: 
								spawn_obj = tree_type
								
						# 2. VÙNG BÃI ĐÁ (Cằn cỗi: Noise < -0.25)
						elif d_val < -0.25:
							if rand < 0.20: 
								spawn_obj = "rock1"
								
						# 3. ĐỒNG BẰNG (Bình thường: Nằm ở giữa)
						else:
							if rand < 0.02: 
								spawn_obj = tree_type
							elif rand < 0.03:
								spawn_obj = "rock1"
						
				hub.world_data[pos_2d] = {
					"type": "ground", 
					"biome": biome_name, 
					"z": elevation,
					"object": spawn_obj,
					"is_water": is_water
				}
			
			# Ném cho Spawner vẽ
			hub.spawner.render_voxel_column(pos_2d)
