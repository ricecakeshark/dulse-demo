#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D albedo_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
layout(set = 0, binding = 2) uniform sampler2D pos_texture;
layout(set = 0, binding = 3) uniform sampler2D model_texture;
layout(set = 0, binding = 4) uniform sampler2D depth_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

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
	layout(row_major) mat4 mat_view;
	layout(row_major) mat4 mat_proj;
	vec3 vec;
} view;
// Model
layout(std430, set = 2, binding = 2) uniform Model
{
	float specular_strength;
	float shininess;
	int entity_id;
} model;
// Light
layout(std430, set = 2, binding = 3) uniform Light
{
	//float light_attenuation;
	LightPoint[1] light_point_list;
	uint count_light_point;
} light;

vec4 calc_light(vec4 albedo_color, vec3 world_pos, vec3 normal_world);
vec3 reconstruct_world_pos(vec2 uv, float depth);

void main()
{
	vec4 albedo_color;
	vec3 normal_world;
	vec3 world_pos;
	vec2 image_size = imageSize(output_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(image_size));
	// read texture (g-buffer)
	albedo_color = texture(albedo_texture, uv);
	normal_world = texture(normal_texture, uv).rgb;
	//world_pos = texelFetch(pos_texture, screen_pos,0).rgb;
	world_pos = reconstruct_world_pos(uv, texelFetch(depth_texture, screen_pos, 0).r);
	float specular_strength = texelFetch(model_texture, screen_pos, 0).r;
	float shininess = texelFetch(model_texture, screen_pos, 0).g;
	int entity_id = int(texelFetch(model_texture, screen_pos, 0).b);

	//vec4 draw_color = albedo_color;
	// write
	// imageStore(output_image, screen_pos, draw_color);
	imageStore(output_image, screen_pos, calc_light(albedo_color, world_pos, normal_world));
	return;
}

vec4 calc_light(vec4 albedo_color, vec3 world_pos, vec3 normal_world)
{
	// render
	vec3 vec_light = normalize(light.light_point_list[0].pos.xyz - world_pos);
	vec3 vec_view = normalize(view.vec - world_pos);
	vec3 vec_reflect = reflect(-vec_light, normal_world);

	// ambient
	vec3 ambient = scene.light_ambient.rgb * scene.light_ambient.a;
	// diffuse
	float diff = max(dot(normal_world, vec_light), 0.0);
	vec3 diffuse = light.light_point_list[0].color.xyz * light.light_point_list[0].intensity * diff;
	// specular
	float spec = 0.0;
	if(diff > 0.0){
		spec = pow(max(dot(vec_view, vec_reflect), 0.0), model.shininess);
	}
	vec3 specular = light.light_point_list[0].color.xyz 
		* light.light_point_list[0].intensity * model.specular_strength * spec;
	vec4 draw_color = vec4((ambient + diffuse) * albedo_color.rgb + specular, albedo_color.a);
	return draw_color;
}

vec3 reconstruct_world_pos(vec2 uv, float depth)
{
	vec4 clip_pos;
	clip_pos = vec4(
		uv.x * 2.0 - 1.0,
		uv.y * 2.0 - 1.0,
		depth,
		1.0
	);

	vec4 world_pos = inverse(view.mat_view * view.mat_proj) * clip_pos;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
