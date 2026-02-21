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
	vec4 color_1;
	vec4 color_2;
} cb;

void main()
{
	float distance = texture(user_texture, uv).a;
	const float smoothing = 1.0 / 16.0;
	float alpha = smoothstep(0.0, 1.0, distance);
	draw_color = vec4(cb.color_1.rgb, cb.color_1.a * alpha);
	return;
}
