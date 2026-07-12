shader_type canvas_item;

// Nhận phần dư thập phân từ Camera (VD: 0.3 pixel)
uniform vec2 cam_offset = vec2(0.0, 0.0);

void vertex() {
	// Dịch chuyển trực tiếp các đỉnh (Vertex) của khung hình.
	// Dấu trừ (-) ở đây chính là chìa khóa để "bù trừ" lại độ giật của Camera.
	VERTEX -= cam_offset;
}