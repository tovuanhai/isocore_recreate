shader_type canvas_item;

// Biến này chạy từ 0 (Màu gốc) đến 1 (Trắng bóc)
uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// Pha trộn giữa màu gốc và màu trắng dựa trên flash_modifier
	color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
	COLOR = color;
}