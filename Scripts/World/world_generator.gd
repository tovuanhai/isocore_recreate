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
var world_rotation_offset: float = 0.0 # 🎯 Thêm biến này

func initialize(p_hub: Node2D) -> void:
	hub = p_hub

func setup_noises() -> void:
	var cfg = hub.config

	continental_noise = FastNoiseLite.new()
	continental_noise.seed = randi()
	continental_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	continental_noise.frequency = 0.002 # Làm bờ biển lượn sóng to hơn

	erosion_noise = FastNoiseLite.new()
	erosion_noise.seed = randi() + 123
	erosion_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion_noise.frequency = 0.01 

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

	# Tần số siêu nhỏ để tạo các vùng Biome mảng lớn như Lightborn68
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = randi() + 1011
	temperature_noise.frequency = 0.001 

	humidity_noise = FastNoiseLite.new()
	humidity_noise.seed = randi() + 1213
	humidity_noise.frequency = 0.001 

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	
	# 🎯 Quay trục tọa độ ngẫu nhiên mỗi hạt giống (Seed)
	world_rotation_offset = randf() * PI * 2.0


func _get_terrain_data(gx: int, gy: int) -> Dictionary:
	# =========================================================
	# 🎯 BỘ NÃO CỦA HÒN ĐẢO (ISLAND DISTANCE MASK)
	# =========================================================
	var dist_from_center = Vector2(gx, gy).length()
	var ISLAND_RADIUS = 600.0 # 🎯 ĐÃ TĂNG: Nới đảo rộng gấp đôi để Sa mạc mênh mông
	
	# 🎯 ĐÃ SỬA: Đổi 0.5 thành 0.75. Giúp lục địa bằng phẳng rộng hơn, 
	# chỉ bắt đầu chìm xuống biển khi ra tít sát mép ngoài!
	var island_falloff = smoothstep(ISLAND_RADIUS * 0.75, ISLAND_RADIUS, dist_from_center)
	var raw_cont = (continental_noise.get_noise_2d(gx, gy) + 1.0) / 2.0 
	var cont = raw_cont - (island_falloff * 1.5) + 0.2
	
	var micro = micro_noise.get_noise_2d(gx, gy)
	var lake_val = (lake_noise.get_noise_2d(gx, gy) + 1.0) / 2.0

	# =========================================================
	# 🎯 LÕI CORE KEEPER: ÉP KHUÔN HÌNH TRÒN & CẮT ĐÔI BẢN ĐỒ
	# =========================================================
	var angle = atan2(gy, gx) + world_rotation_offset
	
	# 1. Bơm nhiễu để các đường ranh giới Nóng/Lạnh uốn lượn
	var border_wobble = weirdness_noise.get_noise_2d(gx, gy) * 1.5 
	
	# 🎯 NÂNG CẤP BÓP MÉO: Dùng Erosion Noise để vặn vẹo hình tròn kịch liệt!
	# macro_wobble: Tạo ra những mảng cỏ khổng lồ thò ra hoặc các vịnh sa mạc thụt sâu vào trong.
	# micro_wobble: Tạo viền răng cưa nhỏ lẻ ở mép.
	var macro_wobble = erosion_noise.get_noise_2d(gx * 0.8, gy * 0.8) * 60.0 
	var micro_wobble = micro_noise.get_noise_2d(gx, gy) * 15.0 
	var wobbled_dist = dist_from_center + macro_wobble + micro_wobble
	
	# 2. CHIA ĐÔI BẢN ĐỒ (Nóng - Lạnh)
	var split_val = clamp(sin(angle + border_wobble) * 10.0, -1.0, 1.0)
	
	var base_temp = split_val 
	var base_hum = -split_val 
	
	var temp = lerpf(base_temp, temperature_noise.get_noise_2d(gx, gy), 0.15)
	var hum = lerpf(base_hum, humidity_noise.get_noise_2d(gx, gy), 0.15)

	# 3. TẠO VÙNG TÂM LÀ ĐỒNG CỎ (The Core)
	var CORE_RADIUS = 150.0 # 🎯 Đã tăng bán kính theo ý ông!
	
	# 🎯 NỚI LỎNG BLENDING: Tăng dải chuyển tiếp từ 10.0 lên 45.0.
	# Điều này giúp khu vực giao thoa giữa Cỏ và Cát/Tuyết có độ chuyển mượt mà,
	# tạo ra các mảng đốm đan xen nhau cực kỳ tự nhiên thay vì một đường kẻ rạch ròi.
	var core_mask = 1.0 - smoothstep(CORE_RADIUS - 45.0, CORE_RADIUS + 45.0, wobbled_dist)
	
	temp = lerpf(temp, 0.1, core_mask)     
	hum = lerpf(hum, 0.1, core_mask)       
	lake_val = lerpf(lake_val, 0.0, core_mask)

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

	# ----------------------------------------------------
	# TÍNH TOÁN 3 LOẠI ĐỊA HÌNH ĐỘC LẬP
	# ----------------------------------------------------
	var base_land_z = wl + 1.0 

	# 🏔️ Vùng Tuyết: Cao vút và dốc đứng (Sharp Mountains)
	var w = weirdness_noise.get_noise_2d(gx, gy)
	var sharp = pow(clampf((1.0 - abs(w)) + micro * 0.3, 0.0, 1.0), 3.0) # Mũ 3.0 cho sắc nhọn
	var h_snow = base_land_z + 3.0 + (sharp * 18.0) # Nhân 18.0 để núi tuyết cao chót vót
	if h_snow > base_land_z + 2.0:
		h_snow = lerpf(h_snow, roundf(h_snow / 3.0) * 3.0, 0.8)

	# 🌲 Vùng Cỏ: Đồi thoải mượt mà (Rolling Hills)
	var rolling = (erosion_noise.get_noise_2d(gx * 1.5, gy * 1.5) + 1.0) / 2.0
	var h_grass = base_land_z + (rolling * 5.0) + (micro * 1.5)
	h_grass = lerpf(h_grass, roundf(h_grass / 2.0) * 2.0, 0.4)

	# 🏜️ Vùng Cát: Bằng phẳng, lượn sóng nhẹ thênh thang (Vast Dunes)
	var dune = sin(gx * 0.05 + micro * 3.0) * 0.5 + 0.5 
	var h_sand = base_land_z + (dune * 3.0) # 🎯 ĐÃ TĂNG: Nâng từ 1.5 lên 3.0 để cồn cát nổi rõ hơn

	# ----------------------------------------------------
	# 3. QUÉT MULTI-NOISE (TOÁN HỌC MINECRAFT)
	# ----------------------------------------------------
	var snow_weight = 1.0 - smoothstep(-0.35, -0.15, temp)
	var sand_weight = smoothstep(0.05, 0.25, temp) * (1.0 - smoothstep(-0.2, 0.1, hum))
	var grass_weight = clampf(1.0 - snow_weight - sand_weight, 0.0, 1.0)
	var blended_h = (h_snow * snow_weight) + (h_grass * grass_weight) + (h_sand * sand_weight)

	# 🎯 ĐÃ XÓA TẬN GỐC: Hệ thống bơm độ ẩm ven hồ.
	# Trả lại sự khô cằn tuyệt đối cho sa mạc để không bị mọc nhầm Grass!

	var closest_biome_id = "grass"
	var shortest_distance = 99999.0

	for b in hub.config.available_biomes:
		if b.id == "dirt" or b.id == "beach":
			continue
		var diff_temp = temp - b.target_temp
		var diff_hum = hum - b.target_hum
		var distance = (diff_temp * diff_temp) + (diff_hum * diff_hum)
		
		if distance < shortest_distance:
			shortest_distance = distance
			closest_biome_id = b.id

	biome = closest_biome_id

	# ----------------------------------------------------
	# 4. MẶT NẠ BỜ NƯỚC, ĐÀO LÒNG HỒ & ỐC ĐẢO (LAKE BOWL, BORDERS & OASIS)
	# ----------------------------------------------------
	var coast_mask = smoothstep(0.35, 0.45, cont)

	var beach_z = base_land_z + (dune * 2.0) + max(0.0, micro * 1.5)
	var dirt_shore_z = base_land_z + (rolling * 2.5) + (micro * 1.0)
	final_z = lerpf(beach_z, blended_h, coast_mask)

	# 🎯 1. ĐÀO LÒNG HỒ
	var lake_depth_mask = smoothstep(0.60, 0.80, lake_val)
	var lake_bottom_z = (wl - 2.0) + (micro * 2.5) 
	final_z = lerpf(final_z, lake_bottom_z, lake_depth_mask)

	# 🏝️ 2. THUẬT TOÁN ỐC ĐẢO (OASIS GENERATOR)
	# Tìm vùng lõi cực sâu của các hồ lớn (lake_val > 0.85)
	# Bơm thêm nhiễu (weirdness) để ốc đảo không nằm chính giữa hoàn hảo mà bị méo mó, lệch trục tự nhiên
	var oasis_noise = weirdness_noise.get_noise_2d(gx * 3.0, gy * 3.0) * 0.15
	var oasis_mask = smoothstep(0.85, 0.92, lake_val + oasis_noise)
	
	# Nâng đất trồi ngược lên khỏi mặt nước (Cao hơn mực nước từ 1-2 block)
	var oasis_z = base_land_z + (micro * 1.5) 
	final_z = lerpf(final_z, oasis_z, oasis_mask)

	# 🎯 3. ĐỘ DÀY VIỀN ĐẤT & ĐẤT VĂNG
	var border_thickness_mod = weirdness_noise.get_noise_2d(gx * 1.5, gy * 1.5) * 0.12
	var effective_lake_val = lake_val + border_thickness_mod
	
	var is_lake_flag = false
	
	if effective_lake_val > 0.65:
		is_lake_flag = true 
	elif effective_lake_val > 0.58:
		if micro_noise.get_noise_2d(gx * 15.0, gy * 15.0) > 0.45:
			is_lake_flag = true

	# 🎯 4. GÁN BIOME (QUYẾT ĐỊNH MÀU ĐẤT)
	if final_z <= wl + 3.0:
		# Nếu là đất trồi lên do thuật toán Ốc đảo -> Biến thành Đồng Cỏ!
		if oasis_mask > 0.5 and final_z >= wl + 1.0:
			biome = "grass" 
			is_lake_flag = false # Tắt cờ bùn để tránh mọc bèo duckweed trên cạn
		elif is_lake_flag:
			biome = "dirt" 
		elif cont < 0.45: 
			biome = "snow" if temp < -0.25 else "beach" 

	var final_is_water = (final_z <= wl)
	
	return {
		"z": clampi(roundi(final_z), 0, hub.max_elevation),
		"biome": biome,
		"is_water": final_is_water,
		"is_lake_zone": is_lake_flag, # Gắn cờ để mọc bèo cho đúng
		"ero": lake_val 
	}

# ============================================================
# 🎯 TÍNH TOÁN DỮ LIỆU THUẦN TÚY 
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

			var terrain_data = _get_terrain_data(global_x, global_y)
			var biome_name = terrain_data["biome"]
			var is_water = terrain_data["is_water"]
			var is_lake_zone = terrain_data.get("is_lake_zone", false) 
			var z = terrain_data["z"]
			var spawn_obj = "none"
			var ero = terrain_data.get("ero", 0.0)
			
			var active_biome: BiomeData = null
			for b in hub.config.available_biomes:
				if b.id == biome_name:
					active_biome = b
					break

			# =========================================================
			# 🎯 PHÂN BỔ THỰC VẬT THEO DATA-DRIVEN (BẢN MẢNG - ARRAY)
			# =========================================================
			if is_water:
				if is_lake_zone:
					var d_val = density_noise.get_noise_2d(global_x * 3.0, global_y * 3.0)
					if d_val > 0.25 and randf() < 0.7:
						spawn_obj = "duckweed"
			elif active_biome != null:
				
				# 🎯 1. LAI TẠO (HYBRID): Vừa gần biển, vừa cách ly lưới (CÂY DỪA)
				if active_biome.use_shore_logic and active_biome.use_desert_spacing:
					if z <= hub.water_level + 2 and _is_touching_water(global_x, global_y):
						var grid_step = 4 
						var cell_x = floor(global_x / float(grid_step))
						var cell_y = floor(global_y / float(grid_step))
						var cell_hash = abs(hash(Vector2(cell_x, cell_y))) 
						var target_x = 1 + (cell_hash % 2)
						var target_y = 1 + ((cell_hash / 2) % 2)
						
						if posmod(global_x, grid_step) == target_x and posmod(global_y, grid_step) == target_y:
							if randf() < 0.8 and active_biome.main_plants.size() > 0: 
								spawn_obj = active_biome.main_plants.pick_random()

				# 🎯 2. CHỈ VEN HỒ: Mọc dày đặc, thành từng cụm (CỎ ĐUÔI MÈO)
				elif active_biome.use_shore_logic:
					if z == hub.water_level + 1 and _is_touching_water(global_x, global_y):
						if randf() < 0.45 and active_biome.main_plants.size() > 0: 
							spawn_obj = active_biome.main_plants.pick_random()
					elif randf() < 0.02 and active_biome.main_rocks.size() > 0:
						spawn_obj = active_biome.main_rocks.pick_random()
							
				# 🎯 3. CHỈ TRÊN CẠN: Cách ly lưới (XƯƠNG RỒNG)
				elif active_biome.use_desert_spacing:
					# 🎯 ĐÃ THÊM: "and not _is_touching_water(...)"
					# Ép Sa mạc phải nhường toàn bộ các ô ven nước cho cây Dừa/Cỏ đuôi mèo
					if z >= hub.water_level + 1 and not _is_touching_water(global_x, global_y):
						var grid_step = 7
						var cell_x = floor(global_x / float(grid_step))
						var cell_y = floor(global_y / float(grid_step))
						var cell_hash = abs(hash(Vector2(cell_x, cell_y))) 
						var target_x = 1 + (cell_hash % 2)
						var target_y = 1 + ((cell_hash / 2) % 2)
						
						if posmod(global_x, grid_step) == target_x and posmod(global_y, grid_step) == target_y:
							if randf() < 0.4 and active_biome.main_plants.size() > 0: 
								spawn_obj = active_biome.main_plants.pick_random()
						elif randf() < 0.05 and active_biome.main_rocks.size() > 0:
							spawn_obj = active_biome.main_rocks.pick_random()
							
				# 🎯 4. THUẬT TOÁN RỪNG / NÚI MẶC ĐỊNH
				else:
					var d_val = density_noise.get_noise_2d(global_x, global_y)
					var rand = randf()

					if d_val > hub.config.dense_forest_threshold:
						if rand < hub.config.dense_forest_chance and active_biome.main_plants.size() > 0:
							spawn_obj = active_biome.main_plants.pick_random()
					elif d_val < -hub.config.dense_forest_threshold:
						if rand < hub.config.sparse_rock_chance and active_biome.main_rocks.size() > 0:
							spawn_obj = active_biome.main_rocks.pick_random()
					else:
						if rand < hub.config.plain_tree_chance and active_biome.main_plants.size() > 0:
							spawn_obj = active_biome.main_plants.pick_random()
						elif rand < hub.config.plain_tree_chance + hub.config.plain_rock_chance and active_biome.main_rocks.size() > 0:
							spawn_obj = active_biome.main_rocks.pick_random()

			chunk_data_result[pos_2d] = {
				"type": "ground",
				"biome": biome_name,
				"z": z,
				"object": spawn_obj,
				"is_water": is_water,
				"is_lake_zone": is_lake_zone
			}
			
	return chunk_data_result

func _is_tile_water(gx: int, gy: int) -> bool:
	var tile_data = _get_terrain_data(gx, gy)
	return tile_data["is_water"] or tile_data["z"] <= hub.water_level

func _is_touching_water(gx: int, gy: int) -> bool:
	if _is_tile_water(gx + 1, gy): return true
	if _is_tile_water(gx - 1, gy): return true
	if _is_tile_water(gx, gy + 1): return true
	if _is_tile_water(gx, gy - 1): return true
	return false
