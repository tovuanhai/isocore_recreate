extends StaticBody2D

# 🎯 ĐỊNH NGHĨA CẤP ĐỘ CỦA CÁI BÀN NÀY (1 = Basic Bench, 2 = Copper Anvil...)
@export var station_type: int = 1 

@export var max_health: int = 3
var current_health: int


func _ready() -> void:
	y_sort_enabled = true
	current_health = max_health
	
	# Tìm mắt thần bấm E và nối dây
	var interact_comp = get_node_or_null("InteractComponent")
	if interact_comp:
		interact_comp.interacted.connect(_on_bench_interacted)

# Hàm nâng độ cao (Dùng chung cho mọi Object trên bản đồ)
func init(z: int, cliff_h: int) -> void:
	var elev_shift = z * cliff_h
	for child in get_children():
		if child is Sprite2D:
			child.offset.y -= elev_shift
			child.show()
			
			if child.is_in_group("isometric_shadows") and child.material is ShaderMaterial:
				child.material = child.material.duplicate()
				var tex_h = child.region_rect.size.y if child.region_enabled else child.texture.get_size().y
				var bottom_y = child.offset.y + (tex_h / 2.0) if child.centered else child.offset.y + tex_h
				
				# 🎯 CHỈNH SỐ NÀY ĐỂ KÉO CHÂN BÓNG KHỚP VỚI VẬT THỂ
				# Số càng lớn, điểm neo càng trượt lên cao, bóng sẽ càng dính sâu vào trong gầm bàn/rương
				var pivot_offset = 6.0 
				
				child.material.set_shader_parameter("base_y", bottom_y - pivot_offset)
				child.material.set_shader_parameter("obj_height", tex_h)
		
# ==============================================================================
# KHI NGƯỜI CHƠI BẤM E VÀO BÀN
# ==============================================================================
func _on_bench_interacted() -> void:
	# Bắn loa thông báo: "Ê UI, mở bảng Crafting lên, nạp công thức cấp độ của tao vào!"
	GameEvents.crafting_station_opened.emit(station_type)

# ==============================================================================
# HỆ THỐNG PHÁ HỦY (BỊ ĐẬP VỠ)
# =============================================================================
func take_damage(amount: int) -> void:
	current_health -= amount
	if current_health <= 0:
		break_object()

func break_object() -> void:
	# Bàn chế tạo không chứa đồ bên trong, nên khi vỡ chỉ cần rớt lại chính nó
	var health_drop_comp = get_node_or_null("HealthDropComponent")
	if health_drop_comp and health_drop_comp.has_method("break_object"):
		health_drop_comp.break_object()
	else:
		queue_free() # Fallback nếu ông quên gắn HealthDropComponent
