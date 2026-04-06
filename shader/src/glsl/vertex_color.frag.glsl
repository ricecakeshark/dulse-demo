#version 450

// input
layout(location = 0) in vec4 in_color;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec3 in_pos;
// out
layout(location = 0) out vec4 draw_color;
// uniform buffer
layout(set = 3, binding = 0) uniform CBuffer
{
	vec3 light_pos;
} cb;

void main()
{
	vec3 normal = normalize(in_normal);
	vec3 light_dir = normalize(cb.light_pos - in_pos);

	float diffuse = clamp(dot(normal, light_dir), 0.1, 1.0);
	draw_color = vec4(in_color.rgb * diffuse, in_color.a);
	return;
}
