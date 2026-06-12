# LootSpawner.gd
# Autoload (Singleton). Đăng ký với tên "LootSpawner".
# Chịu trách nhiệm duy nhất: nhận lệnh "spawn loot" → tạo GroundItem nodes.
# Không quan tâm ai gọi (block, enemy, chest, quest...).
extends Node

const GROUND_ITEM_SCENE = preload("res://Scenes/GroundItem.tscn")

# ---------------------------------------------------------------------------
# API chính
# ---------------------------------------------------------------------------

# Spawn từ LootTable resource
func spawn_from_table(table: LootTable, world_pos: Vector2,
		guaranteed_rolls: int = 1, bonus_rolls: int = 0) -> void:
	if table == null:
		return
	var drops = table.roll(guaranteed_rolls, bonus_rolls)
	for drop in drops:
		_spawn_item(drop["id"], drop["amount"], world_pos)

# Spawn thẳng không qua LootTable (dùng khi biết chính xác item cần drop)
func spawn_item(item_id: StringName, amount: int, world_pos: Vector2) -> void:
	#print("LootSpawner: spawn_item gọi -> ", item_id, " x", amount)
	if item_id == "" or amount <= 0:
		return
	_spawn_item(item_id, amount, world_pos)

func _spawn_item(item_id: StringName, amount: int, world_pos: Vector2) -> void:
	#print("LootSpawner: _spawn_item -> ", item_id)
	if not ItemRegistry.has_item(item_id):
		push_warning("LootSpawner: item_id '%s' không tồn tại" % item_id)
		return
	var ground_item: GroundItem = GROUND_ITEM_SCENE.instantiate()
	ground_item.global_position = world_pos
	ground_item.z_index = 1
	get_tree().current_scene.add_child.call_deferred(ground_item)
	#print("LootSpawner: đã add_child GroundItem tại ", world_pos)
	
	ground_item.tree_entered.connect(
		func(): ground_item.setup(item_id, amount),
		CONNECT_ONE_SHOT
	)
