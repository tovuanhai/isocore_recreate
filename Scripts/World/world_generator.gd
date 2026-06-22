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

	# Tần số siêu nhỏ = Bản đồ siêu to khổng lồ
	continental_noise = FastNoiseLite.new()
	continental_noise.seed = randi()
	continental_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continental_noise.frequency = 0.001 

	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = randi() + 123
	erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion_noise.frequency = 0.01

	weirdness_noise = FastNoiseLite.new()
	weirdness_noise.seed = randi() + 456
	weirdness_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	weirdness_noise.frequency = 0.005 # Tần số đồi núi vấp váp hơn nền móng một chút

	micro_noise = FastNoiseLite.new()
	micro_noise.seed = randi() + 789
	micro_noise.frequency = 0.03

	# --- NOISE KHÍ HẬU VÀ THỰC VẬT ---
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = randi() + 1011
	temperature_noise.frequency = cfg.biome_noise_frequency 

	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = randi() + 1213
	humidity_noise.frequency = cfg.biome_noise_frequency

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


# ============================================================
# 🎯 TÍNH TOÁN ĐỘ CAO (ĐỒNG NHẤT BẬC THANG CHO CẢ BIỂN VÀ LỤC ĐỊA)
# ============================================================
func _sample_elevation(gx: int, gy: int) -> int:
	var cont = (continental_noise.get_noise_2d(gx, gy) + 1.0) / 2.0 
	var ero = (erosion_noise.get_noise_2d(gx, gy) + 1.0) / 2.0     
	var w = weirdness_noise.get_noise_2d(gx, gy) 
	var micro = micro_noise.get_noise_2d(gx, gy)

	var wl = float(hub.water_level)
	var max_e = float(hub.max_elevation)

	# 1. 🌍 ĐỊA HÌNH CƠ SỞ (BASE ELEVATION)
	var base_z = 0.0
	if cont < 0.4:
		# Đại dương: Lõm sâu từ 0.0 lên đến mặt nước
		var ocean_frac = cont / 0.4
		base_z = lerpf(0.0, wl, pow(ocean_frac, 1.5))
	else:
		# Lục địa: Nhô cao từ mặt nước trở lên
		var land_frac = (cont - 0.4) / 0.6
		base_z = lerpf(wl + 1.0, wl + 3.0, pow(land_frac, 1.2))

	# 2. ⛰️ TẠO ĐỒI NÚI & RẶNG NGẦM (Áp dụng chung)
	var m_intensity = 1.0 - ero
	var mountain_multiplier = smoothstep(0.2, 0.7, m_intensity)
	
	var raw_peak = 1.0 - abs(w) 
	var jagged_peak = clampf(raw_peak + (micro * 0.3), 0.0, 1.0)
	var sharp_peak = pow(jagged_peak, 3.0)
	
	# Tính toán độ cao tối đa mà núi có thể mọc lên
	var height_potential = (max_e - base_z - 2.0)
	if cont < 0.4:
		# Nếu là núi dưới đáy biển, ép nó không được cao vượt quá mực nước
		height_potential = wl * 0.8 
		
	var added_height = sharp_peak * mountain_multiplier * height_potential

	# 3. 🧱 TẠO VÁCH ĐÁ BẬC THANG (Khấu trừ cho cả Biển và Đất)
	# Hạ mốc xuống > 1.0 để các đụn cát nhỏ dưới biển cũng đóng thành bậc thang
	if added_height > 1.0:
		added_height += micro * 6.0 * mountain_multiplier
		var terrace = roundf(added_height / 4.0) * 4.0
		var cliff_noise = micro_noise.get_noise_2d(gx + 50, gy + 50)
		var rock_cliff_chance = smoothstep(-0.2, 0.6, cliff_noise)
		added_height = lerpf(added_height, terrace, rock_cliff_chance)

	# 4. 🌊 KIỂM SOÁT ĐẶC THÙ (Bãi tắm & Hồ lún)
	var lake_carve = 0.0
	if cont >= 0.4:
		# TRÊN BỜ: Gọt phẳng bờ biển (Coast Mask) & Khoét hồ nước (Sinkholes)
		var coast_mask = smoothstep(0.4, 0.45, cont)
		added_height *= coast_mask
		
		var lake_chance = smoothstep(0.65, 0.95, ero) 
		lake_carve = lake_chance * (wl + 4.0) 
	else:
		# DƯỚI BIỂN: Dọn dẹp rặng san hô sát bờ để chừa chỗ cho Cát vàng bãi biển
		var ocean_frac = cont / 0.4
		var beach_blend = smoothstep(0.85, 1.0, ocean_frac)
		added_height *= (1.0 - beach_blend)

	# 5. 🧮 TỔNG HỢP (Base + Núi - Hồ)
	var final_z = base_z + added_height - lake_carve

	# Thêm gợn lăn tăn cho đồng bằng trên cạn
	if added_height <= 2.0 and lake_carve < 0.1 and cont >= 0.4:
		final_z += micro * 1.0

	return clampi(roundi(final_z), 0, hub.max_elevation)


# ============================================================
# 🎯 PHÂN LOẠI BIOME 3D (ĐỒNG CỎ LÀ ĐẠI TRÀ)
# ============================================================
func _determine_biome(temp: float, hum: float, elevation: int, water_level: int) -> String:
	# 1. MẶT NẠ BÃI BIỂN (Bảo vệ mép nước)
	if elevation <= water_level + 1:
		if temp < -0.6: # Phải cực kỳ lạnh mới đóng băng bờ biển
			return "snow"
		return "dirt" # Mặc định bãi biển là cát vàng
		
	# 2. KHÍ HẬU THEO ĐỘ CAO (Hiệu ứng Lapse Rate)
	# 🎯 ĐÃ SỬA: Chia cho 20.0 thay vì 8.0. 
	# Nghĩa là núi phải THỰC SỰ CAO thì mới đủ lạnh để có tuyết ở chóp, đồi thấp vẫn xanh mướt!
	var altitude_factor = maxf(0.0, float(elevation - water_level - 3)) / 20.0
	var actual_temp = temp - altitude_factor 

	# 3. BẢN ĐỒ KHÍ HẬU NỘI ĐỊA & ĐỈNH NÚI
	# 🎯 ĐÃ SỬA: Ép các mốc nhiệt độ ra sát hai biên để chừa không gian khổng lồ ở giữa cho Grass
	if actual_temp < -0.35:
		# Phải âm sâu (< -0.35) mới ra Tuyết
		return "snow" 
	elif actual_temp > 0.4 and hum < -0.75:
		# Phải rất nóng VÀ rất khô mới ra Sa mạc/Đất cằn
		return "dirt" 
	else:
		# Phần lớn diện tích (-0.35 đến 0.25, bất chấp độ ẩm) sẽ là ĐỒNG CỎ
		return "grass"


# ============================================================
# 🎯 TÍNH TOÁN DỮ LIỆU THUẦN (CHẠY TRÊN THREAD NGẦM)
# Khong gọi hàm render hay đụng vào Scene Tree ở đây!
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

			# Tính toán y hệt code cũ của ông
			var elevation = _sample_elevation(global_x, global_y)
			var is_water = (elevation <= hub.water_level)
			var biome_name = "dirt"
			var spawn_obj = "none"

			if is_water:
				biome_name = "dirt" 
			else:
				var temp = temperature_noise.get_noise_2d(global_x, global_y)
				var hum = humidity_noise.get_noise_2d(global_x, global_y)
				biome_name = _determine_biome(temp, hum, elevation, hub.water_level)

				if biome_name == "grass" or biome_name == "snow":
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
				"z": elevation,
				"object": spawn_obj,
				"is_water": is_water
			}
			
	return chunk_data_result
