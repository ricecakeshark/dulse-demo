#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D input_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D output_image;

// Uniform
layout(std430, set = 2, binding = 0) uniform Color
{
	float fog_start;
	float fog_end;
	vec4 fog_color;
} config;

layout(std430, set = 2, binding = 1) uniform View
{
	layout(row_major) mat4 mat_view_proj;
	layout(row_major) mat4 mat_inv_view_proj;
	vec3 vec_pos;
} view;

vec3 reconstruct_world_pos(const in ivec2 pos, const in float depth);
float reconstruct_view_z(const in float depth);
float distance_of_pixel(const in ivec2 screen_pos, const in float depth);

void main()
{
	const ivec2 image_size = imageSize(output_image);
	const ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	// read texture
	const vec4 input_color = texelFetch(input_texture, screen_pos, 0);
	const float depth = texelFetch(depth_texture, screen_pos, 0)[0];

	const vec3 world_pos = reconstruct_world_pos(screen_pos, depth);
	const float fog_factor = smoothstep(config.fog_start, config.fog_end, length(world_pos - view.vec_pos));

	imageStore(output_image, screen_pos, mix(input_color, config.fog_color, fog_factor));
	return;
}

vec3 reconstruct_world_pos(const in ivec2 screen_pos, const in float depth)
{
	const vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(imageSize(output_image)));
	const vec4 clip_pos = vec4(
		uv.x * 2.0 - 1.0,
		uv.y * 2.0 - 1.0,
		depth,
		1.0
	);
	vec4 world_pos = clip_pos * view.mat_inv_view_proj;
	world_pos.xyz /= world_pos.w;
	return world_pos.xyz;
}
/*
// for optimize, but benefit <= 1 micro second (total dur is 78 micro second)
float reconstruct_view_z(const in float depth)
{
	const vec4 clip_pos = vec4(0.0, 0.0, depth, 1.0);
	const vec4 view_pos = clip_pos * view.mat_inv_proj;
	return view_pos.z / view_pos.w;
}

float distance_of_pixel(const in ivec2 screen_pos, const in float depth)
{
	const vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(imageSize(output_image)));
	const vec2 ndc = uv * 2.0 - 1.0;
	const vec3 ray = vec3(
		ndc.x * view.mat_inv_proj[0][0],
		ndc.y * view.mat_inv_proj[1][1],
		1.0
	);
	return abs(reconstruct_view_z(depth)) * length(ray);
}
*/