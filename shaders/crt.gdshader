shader_type canvas_item;
// CRT 覆盖层：扫描线 + 暗角 + 轻微闪烁（纯叠加，不读后缓冲）

uniform float strength : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	float scan = 0.5 + 0.5 * sin(UV.y * 720.0 * 3.14159);
	float flick = 0.02 * sin(TIME * 73.0);
	float d = distance(UV, vec2(0.5));
	float vig = smoothstep(0.85, 0.35, d);
	float a = strength * (1.0 - scan) + (1.0 - vig) * 0.45 + flick;
	COLOR = vec4(0.0, 0.0, 0.02, clamp(a, 0.0, 0.85));
}
