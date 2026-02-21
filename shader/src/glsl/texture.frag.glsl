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
} cb;

void main()
{
	vec4 texel_color = texture(user_texture, uv);
	draw_color = vec4(texel_color.rgb * cb.color_1.rgb, texel_color.a * cb.color_1.a);
	return;
}
