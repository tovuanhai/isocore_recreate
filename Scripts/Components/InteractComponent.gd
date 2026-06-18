class_name InteractComponent
extends Node

@export var interact_distance: float = 30.0
signal interacted  # Phát tín hiệu ra ngoài khi bị bấm E

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		var parent_obj = get_parent()
		var players = get_tree().get_nodes_in_group("player")
		
		if players.size() > 0:
			var dist = parent_obj.global_position.distance_to(players[0].global_position)
			if dist <= interact_distance:
				interacted.emit()
				get_viewport().set_input_as_handled()
