#version 450
// in
layout(location = 0) in vec2 uv;
// out
layout(location = 0) out vec4 draw_color;
// combine
layout(set = 2, binding = 0) uniform sampler2D user_texture;
// uniform buffer
layout(set = 3, binding = 0) uniform CBuffer
{
	vec4 color_fill;
	vec4 color_outline;
} cb;

void main()
{
	const float edge = 0.5;
	const float outline_width = 0.3;
	const float softness = 1.0;
	float distance = texture(user_texture, uv).a;
	float width = fwidth(distance) * max(softness, 1.0e-6);
	float fill = smoothstep(edge - width, edge + width, distance);

	float ow = max(outline_width, 0.0);
	float outer = smoothstep(edge - (ow + width), edge + (ow + width), distance);

	float outline = clamp(outer - fill, 0.0, 1.0);
	
	draw_color = (cb.color_fill * fill) + (cb.color_outline * outline);
	draw_color.a = max(fill, outline) * max(cb.color_fill.a, cb.color_outline.a);
	return;
}
