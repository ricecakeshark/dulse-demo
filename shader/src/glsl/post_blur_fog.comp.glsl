#version 460
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(set = 0, binding = 1) uniform sampler2D albedo_texture;

layout(set = 1, binding = 0, rgba16f) uniform writeonly image2D render_image;

// Uniform
layout(std430, set = 2, binding = 0) uniform Color
{
	float fog_start;
	float fog_end;
	float blur_start;
	float blur_end;
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
	ivec2 image_size = imageSize(render_image);
	ivec2 screen_pos = ivec2(gl_GlobalInvocationID.xy);
	if(screen_pos.x >= image_size.x || screen_pos.y >= image_size.y)
	{
		return;
	}
	// read texture
	float depth = texelFetch(depth_texture, screen_pos, 0)[0];
	vec4 albedo_color = texelFetch(albedo_texture, screen_pos, 0);
	
	vec3 world_pos = reconstruct_world_pos(screen_pos,depth);
	float blur_factor = smoothstep(config.blur_start, config.blur_end, world_pos.z);

	vec4 blur_color = vec4(0.0, 0.0, 0.0, 0.0);
	float weight_sum = 0.0;
	for(int y = -2; y <= +2; ++y)
	{
		for(int x = -2; x <= +2; ++x)
		{
			if(!is_in_texture(screen_pos + ivec2(x, y)))
			{
				continue;
			}
			weight_sum += 1.0;
			blur_color += texelFetch(albedo_texture, screen_pos + ivec2(x, y), 0);
		}
	}
	blur_color /= weight_sum;

	float fog_factor = smoothstep(config.fog_start, config.fog_end, length(world_pos - view.vec_pos));
	vec4 fog_color = mix(albedo_color, config.fog_color, fog_factor);

	imageStore(render_image, screen_pos, 
		mix(
			mix(albedo_color, blur_color, blur_factor),
		config.fog_color, fog_factor)
	);
	
	return;
}

vec3 reconstruct_world_pos(const in ivec2 screen_pos, const in float depth)
{
	vec4 clip_pos;
	vec2 uv = vec2((vec2(screen_pos)+0.5) / vec2(imageSize(render_image)));
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
		|| pos.x >= imageSize(render_image).x
		|| pos.y < 0
		|| pos.y >= imageSize(render_image).y
	){
		return false;
	}
	return true;
}
