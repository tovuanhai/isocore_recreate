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
	continental_noise.frequency = 0.0015 

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
# 🎯 TÍNH TOÁN ĐỘ CAO (ĐỈNH NHỌN JAGGED PEAKS & VÁCH CLIFF)
# ============================================================
func _sample_elevation(gx: int, gy: int) -> int:
	var cont = (continental_noise.get_noise_2d(gx, gy) + 1.0) / 2.0 
	var ero = (erosion_noise.get_noise_2d(gx, gy) + 1.0) / 2.0     
	var w = weirdness_noise.get_noise_2d(gx, gy) # Giữ nguyên gốc từ -1.0 đến 1.0
	var micro = micro_noise.get_noise_2d(gx, gy)

	var wl = float(hub.water_level)
	var max_e = float(hub.max_elevation)
	var final_z := 0.0

	if cont < 0.4:
		# ==========================================
		# 🌊 ĐẠI DƯƠNG (Giữ nguyên độ mượt)
		# ==========================================
		var shore_dist = cont / 0.4 
		var base_floor = lerpf(0.0, wl - 1.0, pow(shore_dist, 1.2))
		
		var mountain_shape = (w + 1.0) / 2.0
		var seabed_noise = (mountain_shape + ero) / 2.0
		
		var current_depth = (wl - 1.0) - base_floor 
		var max_hill_height = minf(8.0, current_depth) 
		var underwater_roughness = lerpf(-4.0, max_hill_height, seabed_noise)
		
		final_z = base_floor + underwater_roughness + (micro * 1.5)
		final_z = maxf(final_z, 0.0)

	else:
		# ==========================================
		# 🏔️ LỤC ĐỊA: Chóp nhọn vút & Vách đứt gãy
		# ==========================================
		var land_frac = (cont - 0.4) / 0.6
		var base_z = lerpf(wl, wl + 3.0, pow(land_frac, 1.2))
		
		var m_intensity = 1.0 - ero
		var mountain_multiplier = smoothstep(0.2, 0.7, m_intensity)
		
		# 1. 🎯 SỬA ĐỈNH NÚI SẮC NHỌN (JAGGED PEAKS)
		var raw_peak = 1.0 - abs(weirdness_noise.get_noise_2d(gx, gy)) 
		
		# Bơm trực tiếp nhiễu (micro) vào sườn núi để bẻ gãy sự hoàn hảo của hình nón
		var jagged_peak = clampf(raw_peak + (micro * 0.3), 0.0, 1.0)
		
		# Mũ 3.0 đẩy lực vút lên trời: Chân núi thì trải rộng, nhưng đỉnh thì xé mây!
		var sharp_peak = pow(jagged_peak, 3.0)
		
		var added_height = sharp_peak * mountain_multiplier * (max_e - base_z - 2.0)
		
		# 2. 🎯 TẠO VÁCH NÚI TỰ NHIÊN (TERRACE BLENDING)
		if added_height > 2.0:
			# Làm méo mó sườn dốc bằng nhiễu biên độ lớn
			added_height += micro * 6.0 * mountain_multiplier
			
			# TÍNH TOÁN BẬC THANG (Độ cao nếu bị giật cấp vách đá)
			var terrace = roundf(added_height / 4.0) * 4.0
			
			# Lấy một lớp nhiễu độc lập (cộng thêm offset 50) để làm Mặt nạ Trộn.
			var cliff_noise = micro_noise.get_noise_2d(gx + 50, gy + 50)
			
			# MỘT NỬA là sườn dốc (added_height), MỘT NỬA là vách đá dựng đứng (terrace)
			var rock_cliff_chance = smoothstep(-0.2, 0.6, cliff_noise)
			
			# Thuật toán lai tạo: Tạo ra các mỏm đá gồ ghề cực kỳ tự nhiên
			added_height = lerpf(added_height, terrace, rock_cliff_chance)
			
		var coast_mask = smoothstep(0.4, 0.45, cont)
		final_z = base_z + (added_height * coast_mask)
		
		# Trả lại gồ ghề nhẹ cho đồng bằng
		if added_height <= 2.0 and cont > 0.4:
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
	elif actual_temp > 0.4 and hum < -0.2:
		# Phải rất nóng VÀ rất khô mới ra Sa mạc/Đất cằn
		return "dirt" 
	else:
		# Phần lớn diện tích (-0.35 đến 0.25, bất chấp độ ẩm) sẽ là ĐỒNG CỎ
		return "grass"


# ============================================================
# 🎯 VẼ BẢN ĐỒ
# ============================================================
func generate_chunk_data_and_render(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size

	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var pos_2d = Vector2i(global_x, global_y)

			if not hub.world_data.has(pos_2d):
				# 1. Lấy độ cao
				var elevation = _sample_elevation(global_x, global_y)
				var is_water = (elevation <= hub.water_level)
				
				var biome_name = "dirt"
				var spawn_obj = "none"

				if is_water:
					biome_name = "dirt" # Đáy biển
				else:
					# 2. Trộn Nhiệt độ & Độ ẩm để lấy Biome
					var temp = temperature_noise.get_noise_2d(global_x, global_y)
					var hum = humidity_noise.get_noise_2d(global_x, global_y)
					biome_name = _determine_biome(temp, hum, elevation, hub.water_level)

					# 3. Phân bổ Cây và Đá theo Mật độ
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

				# 4. Ghi data
				hub.world_data[pos_2d] = {
					"type": "ground",
					"biome": biome_name,
					"z": elevation,
					"object": spawn_obj,
					"is_water": is_water
				}
			
			hub.spawner.render_voxel_column(pos_2d)
