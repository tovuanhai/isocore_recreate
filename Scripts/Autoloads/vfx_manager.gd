extends Node

func _ready() -> void:
	# Lắng nghe tile_hit_vfx — chỉ dành cho visual, không liên quan game logic
	GameEvents.tile_hit_vfx.connect(_on_tile_hit_vfx)

func _on_tile_hit_vfx(global_pos: Vector2, action_type: String, hit_node: Node2D) -> void:
	# Lấy Sprite để hệ thống ở dưới tự cắt ảnh vụn gỗ/đá
	var sprite = _get_sprite_from_node(hit_node)

	# 🎯 ĐÃ SỬA: Bỏ vụ cộng offset.y đi vì global_pos vốn đã chuẩn rồi!
	if action_type == "mine_ground":
		_spawn_particles(global_pos, sprite, Color("#593d2b"))
	elif action_type == "mine_object":
		_spawn_particles(global_pos, sprite, Color("#8a8a8a"))
		if is_instance_valid(hit_node):
			_isocore_shake_node(hit_node)

func _get_sprite_from_node(node: Node2D) -> Sprite2D:
	if not is_instance_valid(node): return null
	if node is Sprite2D: return node
	for child in node.get_children():
		if child is Sprite2D: return child
	return null

func _spawn_particles(spawn_pos: Vector2, source_sprite: Sprite2D, fallback_color: Color) -> void:
	var emitter = CPUParticles2D.new()
	emitter.emitting = false
	emitter.one_shot = true
	emitter.explosiveness = 0.9
	emitter.lifetime = 0.35
	emitter.direction = Vector2(0, -1)
	emitter.spread = 120.0
	emitter.initial_velocity_min = 60.0
	emitter.initial_velocity_max = 130.0
	emitter.gravity = Vector2(0, 400)
	emitter.amount = 5
	emitter.z_index = 100

	# 🎯 FIX LỖI TÀNG HÌNH: Tính toán cắt đúng mảng ảnh (Region) của Cây/Đá
	if source_sprite and source_sprite.texture:
		var atlas = AtlasTexture.new()
		atlas.atlas = source_sprite.texture
		var cut_size = 6.0
		var cx = 0.0
		var cy = 0.0
		
		# NẾU LÀ SPRITESHEET: Phải lấy tâm của cái Region (Khung cắt)
		if source_sprite.region_enabled:
			var rect = source_sprite.region_rect
			cx = rect.position.x + (rect.size.x / 2.0) - (cut_size / 2.0)
			cy = rect.position.y + (rect.size.y / 2.0) - (cut_size / 2.0)
		# NẾU LÀ ẢNH ĐƠN (Như cỏ đuôi mèo): Lấy tâm bình thường
		else:
			var size = source_sprite.texture.get_size()
			cx = (size.x / 2.0) - (cut_size / 2.0)
			cy = (size.y / 2.0) - (cut_size / 2.0)
			
		atlas.region = Rect2(cx, cy, cut_size, cut_size)
		emitter.texture = atlas
	else:
		# Fallback cho Đất (Do Mảnh đất ko truyền Node xuống)
		var rect_tex = GradientTexture2D.new()
		rect_tex.width = 6; rect_tex.height = 6
		emitter.texture = rect_tex
		emitter.color = fallback_color

	emitter.global_position = spawn_pos
	get_tree().current_scene.add_child(emitter)
	emitter.emitting = true
	get_tree().create_timer(emitter.lifetime + 0.1).timeout.connect(emitter.queue_free)

# ==============================================================================
# 🎯 HIỆU ỨNG RUNG ISOCORE + SOLID WHITE FLASH (BẢN TÁCH LUỒNG & KHÓA BẢO VỆ)
# ==============================================================================
func _isocore_shake_node(node: Node2D) -> void:
	if not is_instance_valid(node): return

	# 1. TÌM SPRITE ĐỂ RUNG
	var sprite_to_shake: Sprite2D = null
	for child in node.get_children():
		if child is Sprite2D:
			sprite_to_shake = child
			break
	
	if sprite_to_shake == null: return

	# 2. BẬT KHÓA BẢO VỆ: Đánh dấu là đang chớp trắng (Cấm Hover Manager can thiệp)
	sprite_to_shake.set_meta("is_flashing", true)

	# 3. CHUẨN BỊ VẬT LIỆU CHỚP TRẮNG
	var flash_mat = ShaderMaterial.new()
	flash_mat.shader = preload("res://Resources/Shaders/hit_flash.gdshader")
	
	var old_material = sprite_to_shake.material
	sprite_to_shake.material = flash_mat

	# 4. LƯU VÀ XỬ LÝ TRẠNG THÁI GỐC ĐỂ RUNG LẮC
	if not sprite_to_shake.has_meta("base_pos"):
		sprite_to_shake.set_meta("base_pos", sprite_to_shake.position)

	var base_pos = sprite_to_shake.get_meta("base_pos")

	# Dọn dẹp Tween cũ của vị trí
	if sprite_to_shake.has_meta("hit_tween"):
		var old_tween = sprite_to_shake.get_meta("hit_tween")
		if is_instance_valid(old_tween) and old_tween.is_running():
			old_tween.kill()

	sprite_to_shake.position = base_pos

	# ====================================================
	# ⚡ TÁCH LUỒNG 1: TWEEN CHỚP SÁNG (Chạy riêng biệt)
	# ====================================================
	var flash_tween = create_tween().bind_node(sprite_to_shake)
	flash_mat.set_shader_parameter("flash_modifier", 1.0)
	flash_tween.tween_property(flash_mat, "shader_parameter/flash_modifier", 0.0, 0.3) # Tăng lên 0.15s cho rõ ràng
	
	# Khi chớp xong thì gỡ khóa bảo vệ và trả lại vật liệu cũ
	flash_tween.tween_callback(func():
		if is_instance_valid(sprite_to_shake):
			sprite_to_shake.set_meta("is_flashing", false)
			if sprite_to_shake.material == flash_mat:
				sprite_to_shake.material = old_material
	)

	# ====================================================
	# 📦 TÁCH LUỒNG 2: TWEEN RUNG VẬT LÝ (Chuyển động)
	# ====================================================
	var shake_tween = create_tween().bind_node(sprite_to_shake)
	sprite_to_shake.set_meta("hit_tween", shake_tween)

	var dir_x = 1.0 if randf() > 0.5 else -1.0
	var duration = 0.04

	# Nhịp 1: Văng chéo lên trên
	shake_tween.tween_property(sprite_to_shake, "position", base_pos + Vector2(dir_x * 3.0, -3.0), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Nhịp 2: Đập xuống quá đà
	shake_tween.chain().tween_property(sprite_to_shake, "position", base_pos + Vector2(-dir_x * 2.0, 2.0), duration * 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Nhịp 3: Nảy đàn hồi về vị trí cũ
	shake_tween.chain().tween_property(sprite_to_shake, "position", base_pos, duration * 3.0)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
