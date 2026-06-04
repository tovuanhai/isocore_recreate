extends Label

func _process(_delta: float) -> void:
	# Engine.get_frames_per_second() retrieves the active frame rate
	text = "FPS: %d" % Engine.get_frames_per_second()
