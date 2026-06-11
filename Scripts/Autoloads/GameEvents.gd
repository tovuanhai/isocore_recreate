# game_events.gd
extends Node

# --- MOVEMENT ---
signal player_entered_water(player)
signal player_exited_water(player)
signal player_moved_to_cell(player, cell: Vector2i, elevation: int)

# --- COMBAT ---
signal player_took_damage(player, amount: int)
signal player_died(player)

# --- TOOL ---
signal player_started_action(player, action_name: String)   # "fish", "scoop"
signal player_finished_action(player, action_name: String)

# --- STATUS EFFECT ---
signal status_effect_applied(player, effect_name: String)   # "wet", "cold"
signal status_effect_removed(player, effect_name: String)
