extends Sprite2D

func _ready():
	scale = Vector2(2, 2)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _physics_process(delta):
	global_position = lerp(global_position, get_global_mouse_position(), 30 * delta)
	
	var desired_rot: float = -12.5 if (Input.is_action_pressed("left_click") or Input.is_action_pressed("right_click")) else 0.0
	rotation_degrees = lerp(rotation_degrees, desired_rot, 16.5 * delta)
	
	var desired_scale: Vector2 = Vector2(2.35, 2.35) if (Input.is_action_pressed("left_click") or Input.is_action_pressed("right_click")) else Vector2(2, 2)
	scale = lerp(scale, desired_scale, 16.5 * delta)
