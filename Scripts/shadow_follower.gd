extends Sprite2D

var target: Node2D

func _ready() -> void:
	# Lưu lại người cha gốc (Ví dụ: Cái rương)
	target = get_parent()
	
	# Tìm cái Lớp gom bóng trên Map
	var shadow_layer = get_tree().get_first_node_in_group("shadow_layer")
	
	if shadow_layer:
		# Bứt ra khỏi Rương và chuyển hộ khẩu vào CanvasGroup
		# Lệnh này cực an toàn vì nó giữ nguyên tọa độ và Shader đã set của hàm init()
		call_deferred("reparent", shadow_layer, true)

func _process(_delta: float) -> void:
	if is_instance_valid(target):
		# Cha đi đâu, bóng đi theo đó (Rất hữu ích nếu áp dụng cho Bóng của Player)
		global_position = target.global_position
	else:
		# Cha bị chặt/đập nát thì bóng cũng tan biến
		queue_free()
