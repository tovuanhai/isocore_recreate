extends Node

@onready var hub = get_parent()
var biome_noise: FastNoiseLite
var elevation_noise: FastNoiseLite

func setup_noises() -> void:
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = 0.015
	
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = randi() + 777
	elevation_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	elevation_noise.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	elevation_noise.frequency = 0.025 
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_PING_PONG

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
					biome_name = "dirt" # Dưới nước auto là Đất
				
				# 🏔️ NẾU LÀ ĐẤT LIỀN
				else:
					var b_val = biome_noise.get_noise_2d(global_x, global_y)
					# Tùy chỉnh tỉ lệ: Âm là tuyết, Dương là cỏ
					if b_val < 0.0: biome_name = "snow"
					else: biome_name = "grass"
					
					# Chỉ cho mọc Đèn/Đá trên bãi Cỏ (Không mọc trên tuyết và nước)
					if biome_name == "grass": 
						var rand = randf()
						if rand < 0.05: spawn_obj = "LightBulb"
						elif rand < 0.12: spawn_obj = "rock1"
						
				hub.world_data[pos_2d] = {
					"type": "ground", 
					"biome": biome_name, 
					"z": elevation,
					"object": spawn_obj,
					"is_water": is_water # <--- Lưu lại cái tick xem ô này có ngập nước không
				}
			
			# Tính toán xong thì quăng cho Spawner vẽ
			hub.spawner.render_voxel_column(pos_2d)
