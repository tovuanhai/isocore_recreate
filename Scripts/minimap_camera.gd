extends Camera2D

@onready var player: CharacterBody2D = $"/root/Root/Player"

func _ready() -> void:
	var viewport = get_parent() as SubViewport
	await get_tree().process_frame # Chờ một frame để map load xong
	
	if viewport:
		# 1. Ép Camera phụ dùng chung bản đồ với game chính
		viewport.world_2d = get_tree().root.get_viewport().world_2d
		
		# 2. THẦN CHÚ ĐÂY RỒI: Bảo cái Viewport này CẤM HIỂN THỊ những gì thuộc Layer 2!
		# Số 1 có nghĩa là nó CHỈ vẽ những node thuộc Visibility Layer 1 (Đất, đá) và bỏ qua Layer 2 (Mèo)
		RenderingServer.viewport_set_canvas_cull_mask(viewport.get_viewport_rid(), 1)

func _process(_delta: float) -> void:
	if player:
		global_position = player.global_position
