shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
    // Lấy kích thước 1 pixel nhân với độ rộng viền mong muốn
    vec2 size = TEXTURE_PIXEL_SIZE * width;
    float outline = 0.0;
    
    // 🎯 ÉP 8 HƯỚNG THAY VÌ 4 HƯỚNG NHƯ TRONG VIDEO ĐỂ BO GÓC MƯỢT HƠN
    outline += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a; // Trái
    outline += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;  // Phải
    outline += texture(TEXTURE, UV + vec2(0.0, -size.y)).a; // Lên
    outline += texture(TEXTURE, UV + vec2(0.0, size.y)).a;  // Xuống
    
    // Thêm đường chéo
    outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
    outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;

    // Giới hạn giá trị Alpha tối đa là 1.0
    outline = min(outline, 1.0);

    vec4 original_color = texture(TEXTURE, UV);
    
    // Gộp màu (Node if trong video): Nơi nào có hình gốc thì giữ nguyên, nơi nào rìa rỗng thì vẽ viền
    if (original_color.a > 0.0) {
        COLOR = original_color;
    } else {
        COLOR = vec4(outline_color.rgb, outline * outline_color.a);
    }
}