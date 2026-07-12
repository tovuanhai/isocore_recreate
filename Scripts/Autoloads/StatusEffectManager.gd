extends Node

var active_effects: Dictionary = {}
var base_speed: float = 0.0

func _ready() -> void:
	base_speed = get_parent().speed
	print("[SEM] Ready - parent is: ", get_parent().name)
	print("[SEM] GameEvents exists: ", GameEvents != null)
	GameEvents.player_exited_water.connect(_on_exited_water)
	print("[SEM] Connected. Signal connections: ", GameEvents.player_exited_water.get_connections())
	

func _process(delta: float) -> void:
	for effect in active_effects.keys():
		active_effects[effect]["timer"] += delta
		if active_effects[effect]["timer"] >= active_effects[effect]["duration"]:
			remove_effect(effect)

func apply_effect(effect_name: String, duration: float) -> void:
	if active_effects.has(effect_name):
		active_effects[effect_name]["timer"] = 0.0
		return

	active_effects[effect_name] = { "duration": duration, "timer": 0.0 }
	_recalculate_speed()  # ← gọi thẳng, không qua signal
	GameEvents.status_applied.emit(get_parent(), effect_name)
	print("[SEM] speed sau apply: ", get_parent().speed)


func remove_effect(effect_name: String) -> void:
	if not active_effects.has(effect_name):
		return
	active_effects.erase(effect_name)
	_recalculate_speed()  # ← gọi thẳng
	GameEvents.status_removed.emit(get_parent(), effect_name)


func has_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name)


# ============================================================
# TÍNH LẠI SPEED TỪ BASE (tránh drift khi stack nhiều effect)
# ============================================================

func _recalculate_speed() -> void:
	var player = get_parent()
	var final_speed = base_speed

	if active_effects.has("wet"):
		final_speed *= 0.75
	if active_effects.has("cold"):
		final_speed *= 0.85
	# Thêm effect mới vào đây sau này

	player.speed = final_speed
	print("[SEM] Recalculated speed: ", player.speed)


# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_exited_water(player) -> void:
	if player != get_parent():
		return
	print("[SEM] Exited water → applying wet")
	apply_effect("wet", 5.0)


func _on_effect_applied(player, effect_name: String) -> void:
	if player != get_parent():
		return
	_recalculate_speed()


func _on_effect_removed(player, effect_name: String) -> void:
	if player != get_parent():
		return
	_recalculate_speed()
