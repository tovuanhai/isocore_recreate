extends Node

var hub: Node2D

# ============================================================
# 1. NHÓM NOISE ĐỘ CAO (ELEVATION)
# ============================================================
var continental_noise: FastNoiseLite
var erosion_noise: FastNoiseLite
var weirdness_noise: FastNoiseLite
var micro_noise: FastNoiseLite
var lake_noise: FastNoiseLite

# ============================================================
# 2. NHÓM NOISE KHÍ HẬU (BIOMES & VEGETATION)
# ============================================================
var temperature_noise: FastNoiseLite
var humidity_noise: FastNoiseLite
var density_noise: FastNoiseLite


func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func setup_noises() -> void:
	var cfg = hub.config

	continental_noise = FastNoiseLite.new()
	continental_noise.seed = randi()
	continental_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continental_noise.frequency = 0.001

	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = randi() + 123
	erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion_noise.frequency = 0.01 # Trả lại 0.01 để đồi núi uốn lượn đẹp như cũ

	# =========================================================
	# 🎯 ĐÃ THÊM: Nhiễu ĐỘC LẬP dành riêng cho Hồ Nước
	# =========================================================
	lake_noise = FastNoiseLite.new()
	lake_noise.seed = randi() + 888
	lake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lake_noise.frequency = 0.02
	lake_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	
	weirdness_noise = FastNoiseLite.new()
	weirdness_noise.seed = randi() + 456
	weirdness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	weirdness_noise.frequency = 0.005 

	micro_noise = FastNoiseLite.new()
	micro_noise.seed = randi() + 789
	micro_noise.frequency = 0.005

	# =========================================================
	# 🎯 ĐÃ SỬA: Ép Frequency SIÊU NHỎ (0.003) để mảng Biome siêu to
	# =========================================================
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = randi() + 1011
	temperature_noise.frequency = 0.003 # Giảm từ 0.02 xuống 0.003

	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = randi() + 1213
	humidity_noise.frequency = 0.003 # Giảm từ 0.02 xuống 0.003

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


func _get_terrain_data(gx: int, gy: int) -> Dictionary:
	var cont = (continental_noise.get_noise_2d(gx, gy) + 1.0) / 2.0 
	var temp = temperature_noise.get_noise_2d(gx, gy) 
	var hum = humidity_noise.get_noise_2d(gx, gy)
	var micro = micro_noise.get_noise_2d(gx, gy)
	
	var ero = (erosion_noise.get_noise_2d(gx, gy) + 1.0) / 2.0
	
	# 🎯 ĐÃ THÊM: Tính toán giá trị Hồ độc lập
	var lake_val = (lake_noise.get_noise_2d(gx, gy) + 1.0) / 2.0

	var wl = float(hub.water_level)
	var max_e = float(hub.max_elevation)

	var biome = "grass"
	var final_z = 0.0

	# ----------------------------------------------------
	# 1. ĐẠI DƯƠNG & HỒ NỘI ĐỊA
	# ----------------------------------------------------
	if cont < 0.35:
		var depth_curve = cont / 0.35
		final_z = lerpf(0.0, wl - 1.0, pow(depth_curve, 1.5)) + (micro * 1.5)
		return { "z": clampi(roundi(final_z), 0, hub.max_elevation), "biome": "dirt", "is_water": true, "is_lake_zone": false }

	# 🎯 ĐÃ SỬA: Dùng lake_val để tạo hồ thay vì ero
	if lake_val > 0.75:
		# Nhớ sửa số 0.75 và 0.25 (vì 1.0 - 0.75 = 0.25)
		var lake_depth = (lake_val - 0.75) / 0.25
		final_z = lerpf(wl - 1.0, 2.0, pow(lake_depth, 0.8)) + (micro * 1.5)
		return { "z": clampi(roundi(final_z), 0, hub.max_elevation), "biome": "dirt", "is_water": true, "is_lake_zone": true, "ero": lake_val }

	# ----------------------------------------------------
	# 2. TÍNH TOÁN 3 LOẠI ĐỊA HÌNH ĐỘC LẬP
	# ----------------------------------------------------
	var base_land_z = wl + 1.0 

	var w = weirdness_noise.get_noise_2d(gx, gy)
	var sharp = pow(clampf((1.0 - abs(w)) + micro * 0.3, 0.0, 1.0), 2.5)
	var h_snow = base_land_z + 3.0 + (sharp * (max_e - base_land_z - 3.0))
	if h_snow > base_land_z + 2.0:
		h_snow = lerpf(h_snow, roundf(h_snow / 3.0) * 3.0, 0.8)

	var rolling = (erosion_noise.get_noise_2d(gx * 1.5, gy * 1.5) + 1.0) / 2.0
	var h_grass = base_land_z + (rolling * 6.0) + (micro * 1.5)
	h_grass = lerpf(h_grass, roundf(h_grass / 2.0) * 2.0, 0.4)

	var dune = sin(gx * 0.1 + micro * 5.0) * 0.5 + 0.5
	var h_sand = base_land_z + (dune * 2.0)

	# ----------------------------------------------------
	# 3. TRỘN (BLEND) GIỮA CÁC BIOME
	# ----------------------------------------------------
	var snow_weight = 1.0 - smoothstep(-0.35, -0.15, temp)
	var sand_weight = smoothstep(0.05, 0.25, temp) * (1.0 - smoothstep(-0.2, 0.1, hum))
		
	var grass_weight = clampf(1.0 - snow_weight - sand_weight, 0.0, 1.0)
	var blended_h = (h_snow * snow_weight) + (h_grass * grass_weight) + (h_sand * sand_weight)

	if snow_weight > 0.5: biome = "snow"
	elif sand_weight > 0.4: biome = "sand" 
	else: biome = "grass"

	# ----------------------------------------------------
	# 4. MẶT NẠ BỜ NƯỚC (WATER SHORE MASK)
	# ----------------------------------------------------
	var coast_mask = smoothstep(0.35, 0.45, cont)
	
	# 🎯 ĐÃ SỬA: Viền bờ hồ giờ nằm trong khoảng 0.65 đến 0.75
	var lake_shore_mask = smoothstep(0.65, 0.75, lake_val)
	final_z = lerpf(base_land_z, blended_h, coast_mask)
	final_z = lerpf(final_z, base_land_z, lake_shore_mask)

	# 🎯 ĐÃ SỬA: Cờ hiệu vùng ven hồ (Mốc 0.65 là bắt đầu có đất nâu)
	var is_lake_flag = lake_val > 0.65
	
	if final_z <= wl + 1.5:
		if is_lake_flag:
			biome = "dirt" 
		else:
			biome = "snow" if temp < -0.25 else "sand" 

	return {
		"z": clampi(roundi(final_z), 0, hub.max_elevation),
		"biome": biome,
		"is_water": false,
		"is_lake_zone": is_lake_flag,
		"ero": lake_val # Vẫn return "ero" để tương thích ngược với code sinh cỏ
	}

# ============================================================
# 🎯 TÍNH TOÁN DỮ LIỆU THUẦN TÚY (Dành cho Multithreading/Time Slicing)
# ============================================================
func generate_chunk_data(chunk_pos: Vector2i) -> Dictionary:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size
	var chunk_data_result = {}

	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var pos_2d = Vector2i(global_x, global_y)

			# Lấy trọn gói toàn bộ dữ liệu từ 1 hàm duy nhất
			var terrain_data = _get_terrain_data(global_x, global_y)
			var biome_name = terrain_data["biome"]
			var is_water = terrain_data["is_water"]
			var is_lake_zone = terrain_data.get("is_lake_zone", false) # Lấy mác Vùng Hồ ra
			var z = terrain_data["z"]
			var spawn_obj = "none"
			var ero = terrain_data.get("ero", 0.0)
			
			# =========================================================
			# 🎯 PHÂN BỔ THỰC VẬT VEN HỒ & MẶT NƯỚC
			# =========================================================
			if is_water:
				# Nước hồ thì mọc bèo (GIỮ NGUYÊN)
				if is_lake_zone:
					var d_val = density_noise.get_noise_2d(global_x * 3.0, global_y * 3.0)
					if d_val > 0.25 and randf() < 0.7:
						spawn_obj = "duckweed" 
			else:
				# 🎯 ĐÃ SỬA: Logic Cỏ đuôi mèo ven hồ
				if is_lake_zone and z == hub.water_level + 1 and biome_name == "dirt":
					
					var dist_to_water = 0.75 - ero

					if dist_to_water <= 0.03:
						if randf() < 0.3: 
							spawn_obj = "cattail"
							
					elif dist_to_water <= 0.08:
						if randf() < 0.08: 
							spawn_obj = "cattail"
				
				# Rừng / Núi bình thường (GIỮ NGUYÊN CODE CŨ CỦA ÔNG)
				elif biome_name == "grass" or biome_name == "snow":
					var tree_type = "Snow_Tree" if biome_name == "snow" else "Grass_Tree"
					var d_val = density_noise.get_noise_2d(global_x, global_y)
					var rand = randf()

					if d_val > hub.config.dense_forest_threshold:
						if rand < hub.config.dense_forest_chance:
							spawn_obj = tree_type
					elif d_val < -hub.config.dense_forest_threshold:
						if rand < hub.config.sparse_rock_chance:
							spawn_obj = "rock1"
					else:
						if rand < hub.config.plain_tree_chance:
							spawn_obj = tree_type
						elif rand < hub.config.plain_tree_chance + hub.config.plain_rock_chance:
							spawn_obj = "rock1"
							
				# 🎯 ĐÃ SỬA: Thực vật cho Sa mạc (Cách ly Xương rồng bằng Jitter Grid)
				elif biome_name == "sand" and z > hub.water_level + 1:
					
					# 1. Khởi tạo Lưới ảo 4x4
					var grid_step = 4
					var cell_x = floor(global_x / float(grid_step))
					var cell_y = floor(global_y / float(grid_step))
					
					# 2. Tạo một ID cố định nhưng ngẫu nhiên cho mỗi ô lưới
					var cell_hash = hash(Vector2(cell_x, cell_y))
					
					# 3. Chọn 1 điểm mọc xương rồng duy nhất trong ô lưới 4x4.
					# Phép tính "1 + (hash % 2)" ép tọa độ mọc luôn rơi vào lõi (1 hoặc 2),
					# cách xa viền ngoài cùng (0 và 3). Đảm bảo 100% không bao giờ mọc dính nhau!
					var target_x = 1 + (cell_hash % 2)
					var target_y = 1 + ((cell_hash / 2) % 2)
					
					# 4. Nếu block hiện tại trùng đúng với điểm đã được chọn
					if posmod(global_x, grid_step) == target_x and posmod(global_y, grid_step) == target_y:
						# Có 65% tỷ lệ ô lưới này được quyền sinh xương rồng
						# (Tăng giảm con số 0.65 này để chỉnh độ Dày/Thưa tổng thể của sa mạc)
						if randf() < 0.4: 
							spawn_obj = "cactus"
					
					# 5. Rải thêm vài viên đá vụn rải rác (2% cơ hội)
					elif randf() < 0.05:
						spawn_obj = "rock1"

			# Chỉ Đóng gói Data
			chunk_data_result[pos_2d] = {
				"type": "ground",
				"biome": biome_name,
				"z": z,
				"object": spawn_obj,
				"is_water": is_water,
				"is_lake_zone": is_lake_zone
			}
			
	return chunk_data_result
