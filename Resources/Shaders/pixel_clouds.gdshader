shader_type canvas_item;
render_mode world_vertex_coords;

uniform sampler2D noise_texture : repeat_enable, filter_linear;

uniform float pixel_size : hint_range(0.01, 64.0) = 1.0; 

// ====================================================================
// ☁️ LỚP 1: MÂY THẤP (Bay nhanh nhất, to nhất, ĐẬM RÕ NHẤT)
// ====================================================================
uniform vec2 speed_1 = vec2(0.5, 0.5);
uniform float scale_1 = 1000.0;
uniform float cover_1 = 0.65;
uniform float dark_1 : hint_range(0.0, 1.0) = 0.35; // Bóng đậm

// ====================================================================
// ☁️ LỚP 2: MÂY TẦM TRUNG (Bay vừa, NHẠT HƠN)
// ====================================================================
uniform vec2 speed_2 = vec2(0.25, 0.25);
uniform float scale_2 = 600.0;
uniform float cover_2 = 0.85;
uniform float dark_2 : hint_range(0.0, 1.0) = 0.2; // Bóng nhạt vừa

// ====================================================================
// ☁️ LỚP 3: MÂY CAO NHẤT (Bay chậm nhất, NHẠT NHẤT)
// ====================================================================
uniform vec2 speed_3 = vec2(0.1, 0.1); 
uniform float scale_3 = 300.0;
uniform float cover_3 = 0.9;
uniform float dark_3 : hint_range(0.0, 1.0) = 0.08; // Bóng mờ ảo gần như trong suốt

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

// 🎯 HÀM XỬ LÝ: Viền cứng 100% (step) nhưng nhân với độ Nhạt của từng lớp
float get_cloud_layer(vec2 base_world, vec2 layer_speed, float layer_scale, float layer_cover, float layer_darkness) {
	vec2 snapped_offset = floor((TIME * layer_speed) / pixel_size) * pixel_size;
	vec2 final_pos = base_world + snapped_offset;
	
	float noise_val = texture(noise_texture, final_pos / layer_scale).r;
	
	// Dùng lại step() để viền gạch pixel sắc lẹm, nhưng trả về độ Alpha (darkness)
	return step(layer_cover, noise_val) * layer_darkness;
}

void fragment() {
	vec2 snapped_world = floor(world_pos / pixel_size) * pixel_size;
	
	float layer1 = get_cloud_layer(snapped_world, speed_1, scale_1, cover_1, dark_1);
	float layer2 = get_cloud_layer(snapped_world, speed_2, scale_2, cover_2, dark_2);
	float layer3 = get_cloud_layer(snapped_world, speed_3, scale_3, cover_3, dark_3);
	
	// Gộp 3 lớp lại. Lớp nào có bóng đậm hơn thì ưu tiên hiển thị (tránh bị đen xì khi đè lên nhau)
	float total_shadow = max(max(layer1, layer2), layer3);
	
	// Ép thẳng total_shadow vào kênh Alpha
	COLOR = vec4(0.0, 0.0, 0.0, total_shadow);
}