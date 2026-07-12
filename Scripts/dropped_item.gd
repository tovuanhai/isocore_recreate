extends Area2D
class_name DroppedItem

@onready var sprite = $Sprite2D

var item_id: String = ""
var sprite_data: Dictionary = {}
var target_player: Node2D = null

var velocity: Vector2 = Vector2.ZERO
var ground_y: float = 0.0
var bounce_factor: float = 0.4
var state: String = "popping" # Có 3 trạng thái: popping, resting, magnet

func _ready() -> void:
	# 1. Bơm ảnh và cắt Region chuẩn xác từ cục đá/cây bị đập
	if sprite_data.has("texture") and sprite_data["texture"] != null:
		sprite.texture = sprite_data["texture"]
		if sprite_data.has("use_region") and sprite_data["use_region"]:
			sprite.region_enabled = true
			sprite.region_rect = sprite_data["region_rect"]
		sprite.scale = Vector2(0.4, 0.4)
	else:
		var tex = GradientTexture2D.new()
		tex.width = 8; tex.height = 8
		sprite.texture = tex
		sprite.modulate = Color("#7a5230")
		
	# 2. Vật lý nảy tung lên lúc vừa đập vỡ
	ground_y = global_position.y + randf_range(5.0, 15.0)
	velocity = Vector2(randf_range(-60, 60), randf_range(-250, -150))

# 🎯 ĐÂY CHÍNH LÀ SIGNAL GODOT CHUẨN ÔNG YÊU CẦU ĐÂY
func _on_body_entered(body: Node2D) -> void:
	# Bắt được ai đó có tên là "Player" bước vào cái vòng tròn Collision 50px
	if body.name == "Player":
		target_player = body
		state = "magnet" # Khóa mục tiêu và đổi trạng thái sang hút ngay lập tức!

func _process(delta: float) -> void:
	# Trạng thái nảy tưng tưng trên đất
	if state == "popping":
		velocity.y += gravity * delta
		global_position += velocity * delta
		
		if global_position.y >= ground_y:
			global_position.y = ground_y
			velocity.y = -velocity.y * bounce_factor
			velocity.x = move_toward(velocity.x, 0.0, 100 * delta)
			
			if abs(velocity.y) < 30.0:
				state = "resting" # Nằm im chờ Player đi qua
				
	# Trạng thái bị hút vào người
	elif state == "magnet":
		if is_instance_valid(target_player):
			# Bay thẳng vào người Mèo
			var dir = global_position.direction_to(target_player.global_position)
			global_position += dir * 400.0 * delta
			
			# Chạm cự ly gần thì báo ăn Item và xóa cái xác
			var dist = global_position.distance_to(target_player.global_position)
			if dist < 15.0:
				GameEvents.item_collected.emit(item_id, 1)
				queue_free()
