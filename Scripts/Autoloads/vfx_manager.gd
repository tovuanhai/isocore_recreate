extends Node

func _ready() -> void:
	# Lắng nghe tile_hit_vfx — chỉ dành cho visual, không liên quan game logic
	GameEvents.tile_hit_vfx.connect(_on_tile_hit_vfx)

func _on_tile_hit_vfx(global_pos: Vector2, action_type: String, hit_node: Node2D) -> void:
	var base_tex = _get_texture_from_node(hit_node)

	if action_type == "mine_ground":
		_spawn_particles(global_pos, base_tex, Color("#593d2b"))
	elif action_type == "mine_object":
		_spawn_particles(global_pos, base_tex, Color("#8a8a8a"))
		if is_instance_valid(hit_node):
			_shake_and_squash_node(hit_node)

func _get_texture_from_node(node: Node2D) -> Texture2D:
	if not is_instance_valid(node): return null
	if node is Sprite2D: return node.texture
	for child in node.get_children():
		if child is Sprite2D: return child.texture
	return null

func _spawn_particles(spawn_pos: Vector2, tex: Texture2D, fallback_color: Color) -> void:
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

	if tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		var cut_size = 6.0
		var cx = (tex.get_width() / 2.0) - (cut_size / 2.0)
		var cy = (tex.get_height() / 2.0) - (cut_size / 2.0)
		atlas.region = Rect2(cx, cy, cut_size, cut_size)
		emitter.texture = atlas
	else:
		var rect_tex = GradientTexture2D.new()
		rect_tex.width = 6; rect_tex.height = 6
		emitter.texture = rect_tex
		emitter.color = fallback_color

	emitter.global_position = spawn_pos
	get_tree().current_scene.add_child(emitter)
	emitter.emitting = true
	get_tree().create_timer(emitter.lifetime + 0.1).timeout.connect(emitter.queue_free)

func _shake_and_squash_node(node: Node2D) -> void:
	if not is_instance_valid(node): return

	if not node.has_meta("base_scale"):
		node.set_meta("base_scale", node.scale)
	if not node.has_meta("base_pos"):
		node.set_meta("base_pos", node.position)

	var base_scale = node.get_meta("base_scale")
	var base_pos = node.get_meta("base_pos")

	if node.has_meta("hit_tween"):
		var old_tween = node.get_meta("hit_tween")
		if is_instance_valid(old_tween) and old_tween.is_running():
			old_tween.kill()

	var tween = create_tween().bind_node(node)
	node.set_meta("hit_tween", tween)

	var duration = 0.05
	tween.set_parallel(true)

	tween.tween_property(node, "position:x", base_pos.x - 3.0, duration)
	tween.tween_property(node, "scale", base_scale * Vector2(1.15, 0.85), duration)

	tween.chain().tween_property(node, "position:x", base_pos.x + 3.0, duration * 2)
	tween.tween_property(node, "scale", base_scale * Vector2(0.9, 1.1), duration * 2)

	tween.chain().tween_property(node, "position:x", base_pos.x, duration)
	tween.tween_property(node, "scale", base_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
