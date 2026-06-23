extends Node

var hub: Node2D

# ============================================================
# 1. NHÓM NOISE ĐỘ CAO (ELEVATION)
# ============================================================
var continental_noise: FastNoiseLite
var erosion_noise: FastNoiseLite
var weirdness_noise: FastNoiseLite
var micro_noise: FastNoiseLite

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
	continental_noise.frequency = 0.008 

	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = randi() + 123
	erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion_noise.frequency = 0.01

	weirdness_noise = FastNoiseLite.new()
	weirdness_noise.seed = randi() + 456
	weirdness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	weirdness_noise.frequency = 0.005 

	micro_noise = FastNoiseLite.new()
	micro_noise.seed = randi() + 789
	micro_noise.frequency = 0.005

	# =========================================================
	# 🎯 ĐÃ SỬA: Ép Frequency siêu nhỏ để mảng Biome khổng lồ
	# =========================================================
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = randi() + 1011
	temperature_noise.frequency = 0.02 # Số càng nhỏ, mảng Cỏ/Tuyết càng to

	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = randi() + 1213
	humidity_noise.frequency = 0.02 

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


# ============================================================
# 🎯 HỆ THỐNG ĐỊA HÌNH PHA TRỘN MƯỢT MÀ (FULL BLEND)
# Đã tích hợp Vuốt mượt Bờ Biển và Bờ Hồ
# ============================================================
func _get_terrain_data(gx: int, gy: int) -> Dictionary:
	var cont = (continental_noise.get_noise_2d(gx, gy) + 1.0) / 2.0 
	var temp = temperature_noise.get_noise_2d(gx, gy) 
	var hum = humidity_noise.get_noise_2d(gx, gy)
	var micro = micro_noise.get_noise_2d(gx, gy)
	
	# Lấy thêm giá trị Xói mòn (Erosion) để tính Hồ
	var ero = (erosion_noise.get_noise_2d(gx, gy) + 1.0) / 2.0

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
		return { "z": clampi(roundi(final_z), 0, hub.max_elevation), "biome": "dirt", "is_water": true }

	if ero > 0.75:
		var lake_depth = (ero - 0.75) / 0.25
		final_z = lerpf(wl - 1.0, 2.0, pow(lake_depth, 0.8)) + (micro * 1.5)
		return { "z": clampi(roundi(final_z), 0, hub.max_elevation), "biome": "dirt", "is_water": true }

	# ----------------------------------------------------
	# 2. TÍNH TOÁN 3 LOẠI ĐỊA HÌNH ĐỘC LẬP
	# ----------------------------------------------------
	var base_land_z = wl + 1.0 

	# 🏔️ Địa hình Tuyết 
	var w = weirdness_noise.get_noise_2d(gx, gy)
	var sharp = pow(clampf((1.0 - abs(w)) + micro * 0.3, 0.0, 1.0), 2.5)
	var h_snow = base_land_z + 3.0 + (sharp * (max_e - base_land_z - 3.0))
	if h_snow > base_land_z + 4.0:
		h_snow = lerpf(h_snow, roundf(h_snow / 3.0) * 3.0, 0.8)

	# 🌿 Địa hình Cỏ 
	var rolling = (erosion_noise.get_noise_2d(gx * 1.5, gy * 1.5) + 1.0) / 2.0
	var h_grass = base_land_z + (rolling * 6.0) + (micro * 1.5)
	h_grass = lerpf(h_grass, roundf(h_grass / 2.0) * 2.0, 0.4)

	# 🏜️ Địa hình Cát 
	var dune = sin(gx * 0.1 + micro * 5.0) * 0.5 + 0.5
	var h_sand = base_land_z + (dune * 2.0)

	# ----------------------------------------------------
	# 3. TRỘN (BLEND) GIỮA CÁC BIOME
	# ----------------------------------------------------
	var snow_weight = 1.0 - smoothstep(-0.35, -0.15, temp)
	
	var sand_weight = 0.0
	if hum < 0.2:
		sand_weight = smoothstep(0.2, 0.4, temp) * (1.0 - smoothstep(0.05, 0.2, hum))
		
	var grass_weight = clampf(1.0 - snow_weight - sand_weight, 0.0, 1.0)
	var blended_h = (h_snow * snow_weight) + (h_grass * grass_weight) + (h_sand * sand_weight)

	if snow_weight > 0.5: biome = "snow"
	elif sand_weight > 0.5: biome = "sand"
	else: biome = "grass"

	# ----------------------------------------------------
	# 4. MẶT NẠ BỜ NƯỚC (WATER SHORE MASK) - ÉP PHẲNG VÁCH ĐÁ
	# ----------------------------------------------------
	# Tạo dải chuyển tiếp (Transition Zone) rộng hơn để đồi núi từ từ hạ thấp
	var coast_mask = smoothstep(0.35, 0.45, cont)      # 0 ở mép biển, 1 ở tít đất liền
	var lake_shore_mask = smoothstep(0.65, 0.75, ero)  # 0 ở đất liền, 1 ở sát mép hồ

	# Càng gần mép biển (coast_mask -> 0), núi bị ép lùn xuống sát mặt nước
	final_z = lerpf(base_land_z, blended_h, coast_mask)

	# Càng gần mép hồ (lake_shore_mask -> 1), núi cũng bị ép lùn xuống sát mặt nước
	final_z = lerpf(final_z, base_land_z, lake_shore_mask)

	# Nhuộm Cát Vàng (Hoặc Băng) cho các dải đất ven bờ
	if final_z <= wl + 1.5:
		biome = "snow" if temp < -0.25 else "sand"

	return {
		"z": clampi(roundi(final_z), 0, hub.max_elevation),
		"biome": biome,
		"is_water": false
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
			var spawn_obj = "none"

			# Phân bổ Cây và Đá theo Mật độ
			if not terrain_data["is_water"] and (biome_name == "grass" or biome_name == "snow"):
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

			# Chỉ Đóng gói Data, không vẽ gì cả
			chunk_data_result[pos_2d] = {
				"type": "ground",
				"biome": biome_name,
				"z": terrain_data["z"],
				"object": spawn_obj,
				"is_water": terrain_data["is_water"]
			}
			
	return chunk_data_result
