

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
bool is_in_texture(const in ivec2 pos);

void main()
{
	ivec2 image_size = imageSize(output_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	// read texture
	vec4 input_color = texelFetch(input_texture, screen_pos, 0);
	float depth = texelFetch(depth_texture, screen_pos, 0)[0];
	vec3 world_pos = reconstruct_world_pos(screen_pos, depth);

	float fog_factor = smoothstep(config.fog_start, config.fog_end, length(world_pos - view.vec_pos));
	vec4 fog_color = mix(input_color, config.fog_color, fog_factor);

	imageStore(output_image, screen_pos, 
		mix(input_color, config.fog_color, fog_factor)
	);
	
	return;
}

vec3 reconstruct_world_pos(const in ivec2 screen_pos, const in float depth)
{
	vec4 clip_pos;
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(imageSize(output_image)));
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

bool is_in_texture(const in ivec2 pos)
{
	if(
		pos.x < 0
		|| pos.x >= imageSize(output_image).x
		|| pos.y < 0
		|| pos.y >= imageSize(output_image).y
	){
		return false;
	}
	return true;
}
