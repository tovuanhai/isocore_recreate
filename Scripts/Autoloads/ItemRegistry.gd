# ItemRegistry.gd
# Autoload (Singleton). Đăng ký làm autoload trong Project Settings với tên "ItemRegistry".
# Là nơi duy nhất để tra cứu ItemData theo ID.
# Thêm item mới: tạo .tres file, kéo vào @export array dưới đây trong Editor.
extends Node

## Kéo tất cả .tres ItemData vào đây trong Inspector
#@export var item_list: Array[ItemData] = []

# Lookup table được build lúc _ready()
var _registry: Dictionary = {}

func _ready() -> void:
	#print("ItemRegistry: _ready() bắt đầu")
	var items_dir = "res://Resources/Items/"
	var dir = DirAccess.open(items_dir)
	if not dir:
		push_error("ItemRegistry: Không mở được folder " + items_dir)
		return
	#print("ItemRegistry: Mở folder thành công")
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		#print("ItemRegistry: Thấy file -> ", file)
		if file.ends_with(".tres"):
			var item = load(items_dir + file)
			#print("ItemRegistry: Load -> ", item, " | is ItemData: ", item is ItemData)
			if item is ItemData and item.id != "":
				_registry[item.id] = item
				#print("ItemRegistry: Đã đăng ký -> ", item.id)
		file = dir.get_next()
	#print("ItemRegistry: Tổng cộng %d items" % _registry.size())

# Lấy ItemData theo ID. Trả null nếu không tìm thấy.
func get_item(id: StringName) -> ItemData:
	if not _registry.has(id):
		push_warning("ItemRegistry: Không tìm thấy item id='%s'" % id)
		return null
	return _registry[id]

func has_item(id: StringName) -> bool:
	return _registry.has(id)

func get_all_ids() -> Array:
	return _registry.keys()
