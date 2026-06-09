extends StaticBody2D

func init(z: int, cliff_h: int) -> void:
	
	var elev_shift = z * cliff_h
	
	var main_sprite = get_node_or_null("Sprite2D2")
	if main_sprite:
		main_sprite.offset.y -= elev_shift
		main_sprite.show()
		
	var shadow_sprite = get_node_or_null("Sprite2D")
	if shadow_sprite:
		shadow_sprite.offset.y -= elev_shift

func _ready() -> void:
	y_sort_enabled = true
