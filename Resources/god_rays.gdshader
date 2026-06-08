shader_type canvas_item;

uniform float angle = -0.3;
uniform float position = -0.2;
uniform float spread : hint_range(0.0, 1.0) = 0.5;
uniform float falloff : hint_range(0.0, 1.0) = 0.4; // Tăng falloff để tia sáng không bị cắt thô ở dưới
uniform float speed = 0.5;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.65, 0.8);
uniform vec2 player_pos; // TRUYỀN VỊ TRÍ PLAYER VÀO ĐÂY (Neo tia sáng theo Mèo)
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(random(i), random(i + vec2(1.0, 0.0)), u.x) +
           (random(i + vec2(0.0, 1.0)) - random(i)) * u.y * (1.0 - u.x) +
           (random(i + vec2(1.0, 1.0)) - random(i + vec2(1.0, 0.0))) * u.x * u.y;
}

void fragment() {
    // Neo UV theo vị trí người chơi để tia sáng không bị "đơ"
    vec2 uv = UV + (player_pos * 0.0005);

    // Tạo luồng sáng dọc
    vec2 ray_uv = (mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * (uv - position)) / (uv.y + spread);

    // Noise chuyển động
    float n = noise(vec2(ray_uv.x * 10.0 + TIME * speed, 1.0));

    // ẨN HIỆN: Dùng smoothstep để tia sáng mờ dần khi di chuyển xa tâm
    float fade = smoothstep(0.8, 0.2, length(player_pos - FRAGCOORD.xy) * 0.001);

    // KHÔNG CHẠM ĐÁY: Giới hạn độ dài tia sáng bằng falloff ở UV.y
    float ray_mask = smoothstep(1.0, falloff, uv.y);

    float rays = n * ray_mask * fade;

    vec4 scene_color = texture(screen_texture, SCREEN_UV);
    vec3 shine = mix(scene_color.rgb, color.rgb, rays * color.a);

    COLOR = vec4(shine, 1.0);
}