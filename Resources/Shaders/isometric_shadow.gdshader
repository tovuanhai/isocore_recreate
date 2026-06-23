shader_type canvas_item;

global uniform vec2 global_sun_offset;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float base_y = 0.0; 
uniform float obj_height = 32.0;

void vertex() {
    float h = (base_y - VERTEX.y) / obj_height;
    h = max(h, 0.0); 
    
    // Cứ cộng số thập phân thoải mái, SubViewport sẽ tự lo việc hiển thị răng cưa!
    VERTEX.x += global_sun_offset.x * h;
    VERTEX.y += global_sun_offset.y * h;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.1) discard;
    COLOR = vec4(shadow_color.rgb, shadow_color.a * tex.a);
}