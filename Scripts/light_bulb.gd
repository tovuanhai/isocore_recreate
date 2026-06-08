extends StaticBody2D

const SLICE_HEIGHT: int = 6

func init(z: int) -> void:
	var main = get_node_or_null("Sprite2D2")
	if not main or not main.texture:
		return
		
	var tex = main.texture
	var region = main.region_rect if main.region_enabled else Rect2(Vector2.ZERO, tex.get_size())
	var tex_w = region.size.x
	var tex_h = region.size.y
	
	var num_slices = int(ceil(tex_h / float(SLICE_HEIGHT)))
	var center_x = main.position.x + main.offset.x
	var top_y = main.position.y + main.offset.y - (tex_h * 0.5)
	
	for i in range(num_slices):
		var slice = Sprite2D.new()
		slice.name = "JohnSlice_" + str(i)
		slice.texture = tex
		slice.region_enabled = true
		
		var y_from = tex_h - (i + 1) * SLICE_HEIGHT
		var actual_h = float(SLICE_HEIGHT)
		if y_from < 0:
			actual_h += y_from
			y_from = 0
			
		slice.region_rect = Rect2(region.position.x, region.position.y + y_from, tex_w, actual_h)
		
		var slice_y = top_y + y_from + (actual_h * 0.5)
		
		# 🎯 ĐỊNH LUẬT BẤT BIẾN:
		# Position Y = 0 để Y-Sort của lát cắt giống hệt Y-Sort của cái đế đèn.
		# Offset Y = slice_y để hình ảnh hiện đúng vị trí gốc.
		slice.position = Vector2(center_x, 0)
		slice.offset = Vector2(0, slice_y)
		slice.y_sort_enabled = true
		
		add_child(slice)

func _ready() -> void:
	y_sort_enabled = true
	var main = get_node_or_null("Sprite2D2")
	if main:
		main.hide()
	var shadow = get_node_or_null("Sprite2D")
	if shadow:
		shadow.y_sort_enabled = true
