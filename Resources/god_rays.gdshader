shader_type canvas_item;
render_mode blend_add;

uniform vec4 ray_color : source_color = vec4(1.0, 0.85, 0.5, 0.15);
uniform vec2 player_pos; // Nhận vị trí Mèo từ code
uniform float angle = -0.6;
uniform float speed = 0.05;
uniform float ray_spacing = 0.003;

void fragment() {
    // 1. TỐI ƯU HÓA: Chuyển đổi UV của UI thành Tọa độ Thế Giới ảo
    // SCREEN_PIXEL_SIZE là biến có sẵn của Godot, nghịch đảo nó ra kích thước màn hình
    vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 virtual_world_pos = player_pos + (UV - 0.5) * screen_size;

    // 2. Tính toán tia sáng dựa trên tọa độ thế giới ảo (Đứng im như cắm cọc)
    float projected_x = virtual_world_pos.x + virtual_world_pos.y * angle;
    projected_x *= ray_spacing;

    float time_shift = TIME * speed;

    float wave1 = sin(projected_x + time_shift);
    float wave2 = sin(projected_x * 0.6 - time_shift * 0.7);
    float wave3 = cos(projected_x * 1.5 + time_shift * 1.2);

    float combined_ray = (wave1 + wave2 * 1.2 + wave3 * 0.6) / 2.8;
    combined_ray = smoothstep(0.4, 0.7, combined_ray);

    // 3. FIX LỖI SỌC NGOÀI VOID: Tạo mặt nạ Vignette
    // Tia sáng chỉ chói ở ngay tâm màn hình (chỗ con Mèo), và đen xì ở các mép viền
    float dist_to_center = distance(UV, vec2(0.5));
    float mask = smoothstep(0.5, 0.15, dist_to_center);

    COLOR = ray_color * combined_ray * mask;
}