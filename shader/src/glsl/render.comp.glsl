#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D albedo_texture;
layout(set = 0, binding = 1) uniform sampler2D normal_texture;
//layout(set = 0, binding = 0) uniform sampler2D input_texture;

layout(set = 1, binding = 0, rgba32f) uniform writeonly image2D output_image;

struct LightPoint
{
	vec3 pos;
	vec3 color;
	float intensity;
};

layout(std430, set = 3, binding = 0) uniform Scene
{
	//float light_attenuation;
	vec4 light_ambient;
} scene;
// View
layout(std430, set = 3, binding = 1) uniform View
{
	//mat4 mat;
	vec3 vec;
} view;
// Model
layout(std430, set = 3, binding = 2) uniform Model
{
	mat4 matrix_model;
	float specular_strength;
	float shininess;
} model;
// Light
layout(std430, set = 2, binding = 3) uniform Light
{
	//float light_attenuation;
	LightPoint[1] light_point_list;
	uint count_light_point;
} light;



void main()
{
	vec4 albedo_color;
	vec3 normal_world;
	vec2 image_size = imageSize(output_image);
	uvec2 pos = gl_GlobalInvocationID.xy;
	if(pos.x >= image_size.x || pos.y >= image_size.y)
	{
		return;
	}
	vec2 uv = vec2((vec2(pos)+0.5) / vec2(image_size));

	albedo_color = texture(albedo_texture, uv);
	normal_world = vec3(texture(normal_texture, uv));

	vec4 draw_color = albedo_color;

	imageStore(output_image, ivec2(pos), draw_color);
}