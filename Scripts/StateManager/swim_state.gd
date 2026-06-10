extends State

@onready var player: Player = get_parent().get_parent() as Player
@export var swim_speed_multiplier: float = 0.5
var original_sprite_y: float = 0.0

func enter(_msg := {}) -> void:
	var sprite = player.get_node("VisualRoot/Sprite2D")
	original_sprite_y = sprite.position.y
	sprite.position.y = original_sprite_y + 6.0
	sprite.self_modulate = Color(0.6, 0.8, 1.0)

func exit() -> void:
	var sprite = player.get_node("VisualRoot/Sprite2D")
	sprite.position.y = original_sprite_y
	sprite.self_modulate = Color.WHITE

func physics_update(delta: float) -> void:
	var next_state = MovementUtils.move_along_path(
		player,
		player.tile_map_node,
		delta,
		player.speed * swim_speed_multiplier,
		true
	)
	if next_state != "":
		transition_requested.emit(next_state)
