extends Node

var hub: Node2D

# 4 Octaves theo John's algorithm
var octave1: FastNoiseLite  # Continental (hình dạng lục địa lớn)
var octave2: FastNoiseLite  # Regional (đồi núi vùng)
var octave3: FastNoiseLite  # Local (chi tiết địa hình nhỏ)
var octave4: FastNoiseLite  # Micro (texture bề mặt)

var biome_noise: FastNoiseLite
var density_noise: FastNoiseLite


func initialize(p_hub: Node2D) -> void:
	hub = p_hub


func setup_noises() -> void:
	var cfg = hub.config

	# ============================================================
	# OCTAVE 1 — CONTINENTAL SHAPE
	# Tần số rất thấp → tạo ra các "lục địa" và "đại dương" lớn
	# Đây là DefaultHeight(x) trong công thức của John
	# ============================================================
	octave1 = FastNoiseLite.new()
	octave1.seed = randi()
	octave1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	octave1.frequency = 0.006
	octave1.fractal_type = FastNoiseLite.FRACTAL_FBM
	octave1.fractal_octaves = 2

	# ============================================================
	# OCTAVE 2 — REGIONAL TERRAIN
	# Tạo ra các vùng đồi núi và thung lũng
	# Amplitude thấp hơn octave1 → không lấn át hình dạng lục địa
	# ============================================================
	octave2 = FastNoiseLite.new()
	octave2.seed = randi() + 111
	octave2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	octave2.frequency = 0.018
	octave2.fractal_type = FastNoiseLite.FRACTAL_FBM
	octave2.fractal_octaves = 3

	# ============================================================
	# OCTAVE 3 — LOCAL DETAIL (CLIFF MAKER)
	# Tần số trung bình + CELLULAR → tạo ra vách đá sắc nét
	# Đây là thứ tạo ra "cliff lớn hẳn" theo John
	# ============================================================
	octave3 = FastNoiseLite.new()
	octave3.seed = randi() + 333
	octave3.noise_type = FastNoiseLite.TYPE_CELLULAR
	octave3.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	octave3.frequency = 0.022
	octave3.fractal_type = FastNoiseLite.FRACTAL_PING_PONG
	octave3.fractal_octaves = 10

	# ============================================================
	# OCTAVE 4 — MICRO TEXTURE
	# Tần số cao, amplitude rất nhỏ → texture bề mặt nhỏ
	# Làm cho đồng bằng trông "sống" hơn thay vì phẳng tuyệt đối
	# ============================================================
	octave4 = FastNoiseLite.new()
	octave4.seed = randi() + 555
	octave4.noise_type = FastNoiseLite.TYPE_PERLIN
	octave4.frequency = 0.055
	octave4.fractal_type = FastNoiseLite.FRACTAL_FBM
	octave4.fractal_octaves = 2

	# --- BIOME & DENSITY (giữ nguyên) ---
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = randi()
	biome_noise.frequency = cfg.biome_noise_frequency

	density_noise = FastNoiseLite.new()
	density_noise.seed = randi() + 999
	density_noise.frequency = cfg.density_noise_frequency
	density_noise.fractal_type = FastNoiseLite.FRACTAL_FBM


# ============================================================
# JOHN'S ALGORITHM: y = DefaultHeight(x) + perlin(x)
#
# DefaultHeight(x) = step function dựa trên octave1:
#   - Noise thấp (< 0.0) → đại dương sâu (elevation thấp)
#   - Noise trung bình (0.0 ~ 0.4) → đồng bằng thoai thoải
#   - Noise cao (> 0.4) → núi cao với cliff sắc nét
#
# perlin(x) = blend của octave2, 3, 4 tùy vùng địa hình
# ============================================================
func _sample_elevation(gx: int, gy: int) -> int:
	var max_e = hub.max_elevation

	# --- 4 OCTAVES ---
	var v1 = octave1.get_noise_2d(gx, gy)  # Continental base
	var v2 = octave2.get_noise_2d(gx, gy)  # Regional hills
	var v3 = octave3.get_noise_2d(gx, gy)  # Cellular: dùng làm CLIFF BOUNDARY
	var v4 = octave4.get_noise_2d(gx, gy)  # Micro texture

	# Normalize về [0,1]
	var n1 = (v1 + 1.0) / 2.0
	var n2 = (v2 + 1.0) / 2.0
	var n3 = (v3 + 1.0) / 2.0  # cellular value của cell hiện tại
	var n4 = (v4 + 1.0) / 2.0

	# ============================================================
	# BƯỚC 1: BASE HEIGHT từ octave1 + octave2
	# Đây là "nền" địa hình trước khi có cliff
	# ============================================================
	# Blend: octave1 quyết định hình lục địa lớn
	#        octave2 thêm đồi nhỏ lên trên
	var base = n1 * 0.7 + n2 * 0.3

	# ============================================================
	# BƯỚC 2: QUANTIZE BASE về các plateau (John's step function)
	# Snap mạnh 95% → vùng phẳng gần tuyệt đối
	# ============================================================
	# 5 bậc cố định: 0.0 / 0.25 / 0.50 / 0.75 / 1.0
	var steps = 10.0
	var quantized = floor(base * steps) / (steps - 1.0)
	# Blend 95% snap, 5% noise gốc → viền plateau không đều tự nhiên
	var plateau_height = lerp(base, quantized, 0.25)

	# ============================================================
	# BƯỚC 3: CLIFF INJECTION từ octave3 (CELLULAR) + EROSION
	# Sample cellular ở 4 điểm xung quanh rồi average
	# → Biên cellular bị mòn tự nhiên, player leo được
	# ============================================================
	var spread = 1
	var n3_n = (octave3.get_noise_2d(gx, gy - spread) + 1.0) / 2.0
	var n3_s = (octave3.get_noise_2d(gx, gy + spread) + 1.0) / 2.0
	var n3_e = (octave3.get_noise_2d(gx + spread, gy) + 1.0) / 2.0
	var n3_w = (octave3.get_noise_2d(gx - spread, gy) + 1.0) / 2.0
	var n3_eroded = (n3 + n3_n + n3_s + n3_e + n3_w) / 5.0

	var cliff_steps = 4.0
	var cliff_level = floor(n3_eroded * cliff_steps) / (cliff_steps - 1.0)

	var cliff_weight: float
	if plateau_height > 0.25:
		cliff_weight = 0.38  # Đất liền: cliff rõ nhưng leo được
	else:
		cliff_weight = 0.18  # Dưới nước: dốc thoai thoải

	var final_height = plateau_height * (1.0 - cliff_weight) + cliff_level * cliff_weight

	# ============================================================
	# BƯỚC 4: MICRO TEXTURE từ octave4
	# Chỉ thêm rất nhỏ để mặt phẳng không bị "dead flat"
	# ============================================================
	final_height += (n4 - 0.5) * 0.04

	# ============================================================
	# BƯỚC 5: MAP về int elevation
	# ============================================================
	final_height = clampf(final_height, 0.0, 1.0)
	return clampi(int(final_height * float(max_e + 1)), 0, max_e)


func generate_chunk_data_and_render(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * hub.chunk_size
	var start_y = chunk_pos.y * hub.chunk_size

	for x in range(hub.chunk_size):
		for y in range(hub.chunk_size):
			var global_x = start_x + x
			var global_y = start_y + y
			var pos_2d = Vector2i(global_x, global_y)

			if not hub.world_data.has(pos_2d):
				var elevation = _sample_elevation(global_x, global_y)

				var biome_name = "grass"
				var spawn_obj = "none"
				var is_water = false

				# 🌊 ĐÁY BIỂN
				if elevation <= hub.water_level:
					is_water = true
					biome_name = "dirt"

				# 🏔️ ĐẤT LIỀN
				else:
					var b_val = biome_noise.get_noise_2d(global_x, global_y)
					if b_val < 0.0:
						biome_name = "snow"
					else:
						biome_name = "grass"

					# 🌲 LOGIC MỌC CỤM
					if biome_name == "grass" or biome_name == "snow":
						var tree_type = "Grass_Tree"
						if biome_name == "snow":
							tree_type = "Snow_Tree"

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

				hub.world_data[pos_2d] = {
					"type": "ground",
					"biome": biome_name,
					"z": elevation,
					"object": spawn_obj,
					"is_water": is_water
				}

			hub.spawner.render_voxel_column(pos_2d)
