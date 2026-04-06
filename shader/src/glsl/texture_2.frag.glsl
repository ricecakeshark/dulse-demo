#version 450

const float LIGHT_ATTENUATION = 0.9f;
const int MAX_LIGHT_POINT = 32;
// in
layout(location = 0) in vec2 in_uv;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec3 in_world_pos;
// out
layout(location = 0) out vec4 draw_color;
// sampled texture
layout(set = 2, binding = 0) uniform sampler2D user_texture;

struct LightPoint
{
	vec3 pos;
	vec3 color;
	float intensity;
};
// Scene (storage buffer)
layout(set = 2, binding = 1) readonly buffer Scene
{
	LightPoint[4] light_point;
	uint count_light_point;
} scene_ssbo;

// uniform buffer
layout(set = 3, binding = 0) uniform Scene
{
	//float light_attenuation;
	vec4 light_ambient;
} scene;
// View
layout(set = 3, binding = 1) uniform View
{
	//mat4 mat;
	vec3 vec;
} view;
// Model
layout(set = 3, binding = 2) uniform Model
{
	float none;
	//vec3 mat;
} model;
// Light
layout(set = 3, binding = 3) uniform Light
{
	//float light_attenuation;
	LightPoint[1] light_point_list;
	uint count_light_point;
} light;

void main()
{
	vec4 texel_color = texture(user_texture, in_uv);

	vec3 normal_world = normalize(in_normal);
	vec3 vec_light = normalize(light.light_point_list[0].pos - in_world_pos);
	vec3 vec_view = normalize(view.vec - in_world_pos);
	vec3 R = reflect(-vec_light, normal_world);

	// ambient
	vec3 ambient = texel_color.rgb * scene.light_ambient.rgb * scene.light_ambient.a;
	// diffuse
	vec3 diffuse = light.light_point_list[0].color * max(dot(normal_world, vec_light), 0.0);
	// specular is later

	draw_color = vec4((ambient + diffuse) * texel_color.rgb, texel_color.a);
	return;
}
