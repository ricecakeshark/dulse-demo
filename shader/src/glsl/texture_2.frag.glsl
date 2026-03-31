#version 450
// in
layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec3 in_pos;
// out
layout(location = 0) out vec4 draw_color;
// combine
layout(set = 2, binding = 0) uniform sampler2D user_texture;
// uniform buffer
layout(set = 3, binding = 0) uniform CBuffer
{
	vec3 light_pos;
} cb;

void main()
{
	vec4 texel_color = texture(user_texture, in_uv);
	vec3 normal = normalize(in_normal);
	vec3 light_dir = normalize(cb.light_pos - in_pos);

	float diffuse = clamp(dot(normal, light_dir), 0.1, 1.0);
	draw_color = vec4(texel_color.rgb * diffuse, 1.0);
	return;
}
