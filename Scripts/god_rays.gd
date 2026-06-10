extends ColorRect
var player: Player

func _process(_delta: float) -> void:
	if player and material:
		material.set_shader_parameter("player_pos", player.global_position)
