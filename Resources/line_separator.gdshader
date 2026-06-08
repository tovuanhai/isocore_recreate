shader_type canvas_item;

// Sử dụng texture có sẵn của Screen/CanvasGroup để tránh bị lỗi trắng xóa màn hình
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform vec4 line_color : source_color = vec4(0.05, 0.18, 0.05, 1.0); // Màu xanh sẫm đậm phân chia layer
uniform float line_thickness : hint_range(0.0, 5.0) = 1.0;            // Độ dày viền (nên để 1.0 cho pixel art)

void fragment() {
    // 1. Lấy màu sắc thực tế tại vị trí pixel hiện tại từ màn hình
    vec4 current_color = texture(screen_texture, SCREEN_UV);

    // Nếu pixel hiện tại hoàn toàn trong suốt, bỏ qua không xử lý để tránh lỗi trắng nền
    if (current_color.a == 0.0) {
        discard;
    }

    // 2. Tính toán kích thước pixel dựa trên màn hình
    vec2 size = SCREEN_PIXEL_SIZE * line_thickness;

    // 3. Kiểm tra độ trong suốt (Alpha) của các ô xung quanh nhằm tìm ra điểm giao cắt địa hình
    float alpha_up    = texture(screen_texture, SCREEN_UV + vec2(0.0, -size.y)).a;
    float alpha_down  = texture(screen_texture, SCREEN_UV + vec2(0.0, size.y)).a;
    float alpha_left  = texture(screen_texture, SCREEN_UV + vec2(-size.x, 0.0)).a;
    float alpha_right = texture(screen_texture, SCREEN_UV + vec2(size.x, 0.0)).a;

    float border = alpha_up + alpha_down + alpha_left + alpha_right;

    // 4. Nếu là pixel rìa biên (tiếp giáp vùng trống hoặc lớp thấp hơn có alpha thay đổi)
    if (border < 4.0) {
        // Đè màu viền đậm lên biên phân cách
        COLOR = line_color;
    } else {
        // Giữ nguyên màu gốc của ô gạch cỏ
        COLOR = current_color;
    }
}