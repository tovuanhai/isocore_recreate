class_name Vessel
extends CharacterBody2D

@export var cliff_height: int = 6
var current_elevation: int = 0

# TẤT CẢ con cháu đều phải có một Node2D tên "VisualRoot" chứa Sprite
@onready var visual_root: Node2D = $VisualRoot

func _ready() -> void:
	y_sort_enabled = true
	if visual_root:
		visual_root.y_sort_enabled = false
		visual_root.position = Vector2.ZERO

# ====================================================
# ĐÂY LÀ HÀM PHÉP THUẬT: Gọi 1 phát là tự nâng hình lên!
# ====================================================
func set_elevation(target_z: int, animate: bool = false) -> void:
	if current_elevation == target_z: return
	current_elevation = target_z
	
	if not is_instance_valid(visual_root): return
	
	# Tính toán độ cao theo hệ quy chiếu Isometric
	var target_y = -(current_elevation * cliff_height)
	
	if animate:
		var tween = create_tween()
		tween.tween_property(visual_root, "position:y", float(target_y), 0.15)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		visual_root.position.y = target_y
