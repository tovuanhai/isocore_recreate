shader_type canvas_item;

global uniform vec2 global_sun_offset;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.45);
uniform float base_y = 0.0; 
uniform float obj_height = 32.0;

varying vec2 unskewed_pos;
varying vec2 skewed_pos;

void vertex() {
    // 1. LƯU LẠI TỌA ĐỘ GỐC CHƯA BỊ BÓP MÉO
    unskewed_pos = VERTEX;
    
    // 2. KÉO NGHIÊNG MƯỢT MÀ (CHỐNG GIẬT)
    // TUYỆT ĐỐI KHÔNG làm tròn ở đây để bóng có thể trượt mượt mà theo Player
    float h = (base_y - VERTEX.y) / obj_height;
    h = max(h, 0.0);
    
    vec2 offset = global_sun_offset * h;
    VERTEX += offset;
    
    // 3. LƯU LẠI TỌA ĐỘ SAU KHI KÉO XIÊN
    skewed_pos = VERTEX;
}

void fragment() {
    // 4. MA THUẬT ÉP LƯỚI VUÔNG (PIXEL-PERFECT)
    // Giống hệt cách ông làm với Mây: Ép tọa độ hiển thị thành các ô vuông 1x1.
    // Cộng thêm 0.5 để bắt chính xác TÂM của pixel, triệt tiêu viền rác.
    vec2 snapped_skewed = floor(skewed_pos) + vec2(0.5);
    
    // 5. TÌNH NGƯỢC LẠI VỊ TRÍ GỐC
    // Từ khối vuông 1x1 này, ta tính lùi lại xem nó thuộc điểm nào trên bức ảnh chưa nghiêng
    float h = (base_y - snapped_skewed.y) / obj_height;
    h = max(h, 0.0);
    vec2 snapped_unskewed = snapped_skewed - (global_sun_offset * h);
    
    // 6. BÙ TRỪ VÀO LƯỚI TIA QUÉT UV
    vec2 diff = snapped_unskewed - unskewed_pos;
    vec2 final_uv = UV + (diff * TEXTURE_PIXEL_SIZE);
    
    // 7. VẼ MÀU THEO LƯỚI ĐÃ LÀM TRÒN
    vec4 tex = texture(TEXTURE, final_uv);
    if (tex.a < 0.1) discard;
    
    COLOR = vec4(shadow_color.rgb, shadow_color.a * tex.a);
}