extends Node2D

@onready var canvas_modulate = $CanvasModulate

@export var time_of_day: float = 8.0 
@export var day_length_in_minutes: float = 10.0 
@export var max_shadow_length: float = 20.0 

var time_scale: float 

func _ready() -> void:
	time_scale = 24.0 / (day_length_in_minutes * 60.0)
	# Khóa cứng màu trắng sáng lúc mới vào game
	if canvas_modulate:
		canvas_modulate.color = Color(1.0, 1.0, 1.0, 1.0)

func _process(delta: float) -> void:
	time_of_day += delta * time_scale
	if time_of_day >= 24.0: 
		time_of_day -= 24.0
	
	# Liên tục ép màu trắng để không bao giờ bị tối đi
	if canvas_modulate:
		canvas_modulate.color = Color(1.0, 1.0, 1.0, 1.0)
		
	# ==========================================
	# BẬT LẠI ĐỘNG CƠ KÉO BÓNG BẰNG SHADER
	# ==========================================
	var sun_offset_x: float = 0.0
	var sun_offset_y: float = 0.0
	
	# Từ 6h sáng đến 6h tối: Bóng ngả nghiêng
	if time_of_day >= 6.0 and time_of_day <= 18.0:
		sun_offset_x = cos((time_of_day - 6.0) * PI / 12.0) * -max_shadow_length
		sun_offset_y = sin((time_of_day - 6.0) * PI / 12.0) * -(max_shadow_length * 0.25)
	
	# Bơm thông số xuống Card đồ họa để Shader bẻ đỉnh
	var shadow_vec = Vector2(sun_offset_x, sun_offset_y)
	RenderingServer.global_shader_parameter_set("global_sun_offset", shadow_vec)
