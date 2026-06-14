extends PanelContainer

@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var tier_label: Label = $MarginContainer/VBoxContainer/TierLabel
@onready var stats_label: RichTextLabel = $MarginContainer/VBoxContainer/StatsLabel
@onready var divider: TextureRect = $MarginContainer/VBoxContainer/Divider
@onready var desc_label: RichTextLabel = $MarginContainer/VBoxContainer/DescLabel

func _ready() -> void:
	stats_label.bbcode_enabled = true
	stats_label.fit_content = true
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	hide()

func display_info(item: ItemData, durability: int = -1) -> void:
	name_label.text = item.display_name
	
	# 1. XỬ LÝ ITEM LEVEL (TIER)
	var has_tier = false
	if "tier" in item and item.tier != null and item.tier > 0:
		# Tự động nạp chữ, còn màu sắc chữ sẽ ăn theo thiết lập Inspector của ông!
		tier_label.text = "Item level " + str(item.tier)
		tier_label.show()
		has_tier = true
	else:
		tier_label.hide()
	
	# 2. XỬ LÝ CHỈ SỐ (DAMAGE & DURABILITY - CHUẨN TIẾNG ANH THEO ẢNH MỚI)
	var stats_text = ""
	if item is ToolData:
		var tool = item as ToolData
		var current_durability = durability if durability >= 0 else tool.max_durability
		
		# Giữ nguyên màu chữ mặc định (màu trắng có outline) chuẩn như ảnh d0f3aa của ông
		stats_text += "♦ Damage: " + str(tool.base_damage) + "\n"
		stats_text += "♦ Durability: " + str(current_durability) + " / " + str(tool.max_durability)
	
	var has_stats = (stats_text != "")
	if has_stats:
		stats_label.text = stats_text
		stats_label.show()
	else:
		stats_label.hide()

	# 3. XỬ LÝ MÔ TẢ (DESCRIPTION)
	var has_desc = ("description" in item and item.description != "")
	if has_desc:
		desc_label.text = item.description
		desc_label.show()
	else:
		desc_label.hide()
		
	# 4. ĐƯỜNG KẺ NGANG (Hiện khi có mô tả VÀ có ít nhất một thông tin chỉ số/tier ở trên)
	if has_desc and (has_stats or has_tier):
		divider.show()
	else:
		divider.hide()
		
	show()
