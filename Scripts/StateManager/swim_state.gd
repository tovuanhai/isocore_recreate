extends State

@export var swim_speed_multiplier: float = 0.5
var original_sprite_y: float = 0.0

var player: Player

func initialize(p: Player) -> void:
	player = p

func enter(_msg := {}) -> void:
	var sprite = player.get_node("VisualRoot/Sprite2D")
	original_sprite_y = sprite.position.y
	sprite.position.y = original_sprite_y + 6.0
	sprite.self_modulate = Color(0.6, 0.8, 1.0)

	GameEvents.player_entered_water.emit(player)
	
func exit() -> void:
	
	print("SwimState exit - emitting player_exited_water")
	
	var sprite = player.get_node("VisualRoot/Sprite2D")
	sprite.position.y = original_sprite_y
	sprite.self_modulate = Color.WHITE
	
	GameEvents.player_exited_water.emit(player)
	
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
