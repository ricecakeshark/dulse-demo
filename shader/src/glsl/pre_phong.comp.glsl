#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D albedo_texture;
layout(set = 0, binding = 2) uniform sampler2D normal_texture;
layout(set = 0, binding = 3) uniform sampler2D material_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D color_texture;
//layout(set = 1, binding = 1, rgba32f) uniform writeonly image2D specular_texture;

struct LightPoint
{
	vec4 pos;
	vec4 color;
	float intensity;
};

layout(std430, set = 2, binding = 0) uniform Scene
{
	vec4 light_ambient;
} scene;
// View
layout(std430, set = 2, binding = 1) uniform View
{
	layout(row_major) mat4 mat_view_proj;
	layout(row_major) mat4 mat_inv_view_proj;
	vec3 vec_pos;
} view;
// Light
layout(std430, set = 2, binding = 2) uniform Light
{
	//float light_attenuation;
	LightPoint[1] light_point_list;
	uint count_light_point;
} light;

//vec4 calc_light(const ivec2 screen_pos);
vec3 reconstruct_world_pos(const in vec2 uv, const in float depth);

void main()
{
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	ivec2 image_size = imageSize(color_texture);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos) + 0.5) / vec2(image_size));
	// prepare
	vec4 albedo_color = texelFetch(albedo_texture, screen_pos, 0);
	vec3 normal_world = normalize(texture(normal_texture, uv).rgb);
	//vec3 world_pos = normalize(texelFetch(pos_texture, screen_pos, 0).rgb);
	vec3 world_pos = reconstruct_world_pos(uv, texelFetch(depth_texture, screen_pos, 0).r);
	// render
	vec3 vec_light = normalize(light.light_point_list[0].pos.xyz - world_pos);
	vec3 vec_view = normalize(view.vec_pos - world_pos);
	vec3 vec_reflect = reflect(-vec_light, normal_world);

	// ambient
	vec3 ambient = scene.light_ambient.rgb * scene.light_ambient.a;
	// diffuse
	float diff = max(dot(normal_world, vec_light), 0.0);
	vec3 diffuse = light.light_point_list[0].color.xyz * light.light_point_list[0].intensity * diff;
	// specular
	float specular_strength = texelFetch(material_texture, screen_pos, 0).x;
	float shininess = texelFetch(material_texture, screen_pos, 0).y;
	float spec = 0.0;
	if(diff > 0.0)
	{
		spec = pow(max(dot(vec_view, vec_reflect), 0.0), shininess);
	}
	vec3 specular = light.light_point_list[0].color.xyz * light.light_point_list[0].intensity * specular_strength * spec;

	imageStore(color_texture, screen_pos, vec4((diffuse + ambient) * albedo_color.rgb + specular, albedo_color.a));
	return;
}

vec3 reconstruct_world_pos(const in vec2 uv, const in float depth)
{
	vec4 clip_pos;
	clip_pos = vec4(
		uv.x * 2.0 - 1.0,
		uv.y * 2.0 - 1.0,
		depth,
		1.0
	);
	vec4 world_pos = clip_pos * view.mat_inv_view_proj;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
